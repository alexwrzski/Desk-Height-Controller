#include <WiFi.h>
#include <Adafruit_VL53L0X.h>

#define UP_PIN 16    // GPIO 16 - Connected to relay for UP
#define DOWN_PIN 17  // GPIO 17 - Connected to relay for DOWN
#define STATUS_LED 4  // Status LED pin (use GPIO 4, or change to your board's built-in LED pin)

// Wi-Fi credentials
// NOTE: ESP32 only supports 2.4GHz WiFi!
const char* ssid = "YOUR_WIFI";  // 2.4GHz network
const char* password = "YOU_PASSWORD";

WiFiServer server(80);
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

int presetHeights[3] = {300, 600, 900};  // Preset heights in mm
int minHeight = 575;  // Minimum desk height in mm (configurable)
int maxHeight = 1185; // Maximum desk height in mm (configurable)
int currentHeight = 0;
bool sensor_available = false;  // Track if sensor is working
bool server_started = false;  // Track if server has been started
volatile bool stopMovement = false;  // Flag to stop movement when stop command is received
int targetHeight = -1;  // Target height for movement (-1 means no active movement)
unsigned long lastMovementCheck = 0;  // Last time we checked movement status
unsigned long movementStartTime = 0;  // When movement started (for timeout)
int consecutiveValidReadings = 0;  // Count consecutive readings within target tolerance
int lastValidHeight = 0;  // Last valid height reading (for filtering)
int lastMovementHeight = 0;  // Height when last movement check occurred (for detecting stalled movement)
unsigned long lastHeightChangeTime = 0;  // When height last changed significantly
int stableHeightCount = 0;  // Count of times height has been stable

void setup() {
  Serial.begin(115200);
  pinMode(UP_PIN, OUTPUT);
  pinMode(DOWN_PIN, OUTPUT);
  pinMode(STATUS_LED, OUTPUT);
  // Relay modules are typically active LOW (LOW = ON, HIGH = OFF)
  // Set both to HIGH to keep relays OFF (desk stopped)
  digitalWrite(UP_PIN, HIGH);
  digitalWrite(DOWN_PIN, HIGH);
  digitalWrite(STATUS_LED, LOW);
  
  // Blink LED to show we're starting up
  for(int i = 0; i < 3; i++) {
    digitalWrite(STATUS_LED, HIGH);
    delay(100);
    digitalWrite(STATUS_LED, LOW);
    delay(100);
  }

  // Initialize VL53L0X sensor (non-blocking - continue even if sensor fails)
  sensor_available = lox.begin();
  if (!sensor_available) {
    Serial.println("WARNING: Failed to boot VL53L0X sensor! Continuing without sensor...");
    Serial.println("Server will still work, but height measurements will be unavailable.");
  } else {
    Serial.println("VL53L0X sensor initialized successfully!");
  }

  // Connect to Wi-Fi with timeout
  WiFi.begin(ssid, password);
  Serial.print("Connecting to Wi-Fi");
  int wifi_timeout = 30; // 30 second timeout
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < wifi_timeout) {
    delay(1000);
    Serial.print(".");
    // Fast blink LED while connecting
    digitalWrite(STATUS_LED, HIGH);
    delay(50);
    digitalWrite(STATUS_LED, LOW);
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n✓ Connected to Wi-Fi!");
    Serial.print("IP address: ");
    Serial.println(WiFi.localIP());
    Serial.print("Signal strength (RSSI): ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
    
    // Start server immediately when WiFi is connected
    server.begin();
    server_started = true;
    Serial.println("✓ HTTP server started on port 80");
    Serial.println("✓ Ready to receive commands!");
    Serial.print("Try: http://");
    Serial.print(WiFi.localIP());
    Serial.println("/stop");
    
    // Solid LED = Ready
    digitalWrite(STATUS_LED, HIGH);
  } else {
    Serial.println("\n✗ ERROR: Failed to connect to Wi-Fi!");
    Serial.println("Possible reasons:");
    Serial.println("  1. Wrong WiFi password");
    Serial.println("  2. Network is 5GHz only (ESP32 only supports 2.4GHz!)");
    Serial.println("  3. Network not in range");
    Serial.println("  4. Router not allowing new connections");
    Serial.println("\nIMPORTANT: ESP32 only supports 2.4GHz WiFi networks!");
    Serial.println("Current network: 'Free WiFi' (should be 2.4GHz)");
    Serial.println("\nThe ESP32 will continue to retry...");
    Serial.println("Server will start automatically when WiFi connects.");
    // LED off = Error
    digitalWrite(STATUS_LED, LOW);
  }
}

void loop() {
  // Only process if WiFi is connected
  if (WiFi.status() != WL_CONNECTED) {
    // LED off when disconnected
    digitalWrite(STATUS_LED, LOW);
    
    // Try to reconnect
    static unsigned long lastReconnectAttempt = 0;
    if (millis() - lastReconnectAttempt > 10000) {  // Try every 10 seconds
      lastReconnectAttempt = millis();
      Serial.println("WiFi disconnected. Attempting to reconnect...");
      WiFi.disconnect();
      delay(100);
      WiFi.begin(ssid, password);
      server_started = false;  // Reset server flag
    }
    
    // Fast blink while trying to reconnect
    static unsigned long lastBlink = 0;
    if (millis() - lastBlink > 200) {
      lastBlink = millis();
      digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
    }
    
    delay(100);
    return;
  }
  
  // If WiFi is connected but server hasn't started, start it now
  if (WiFi.status() == WL_CONNECTED && !server_started) {
    Serial.println("WiFi connected! Starting HTTP server...");
    server.begin();
    server_started = true;
    Serial.println("✓ HTTP server started on port 80");
    Serial.println("✓ Ready to receive commands!");
    Serial.print("Try: http://");
    Serial.print(WiFi.localIP());
    Serial.println("/stop");
    
    // Solid LED = Ready
    digitalWrite(STATUS_LED, HIGH);
  }
  
  // Update current height periodically (only if sensor is available)
  // Sensor is mounted on bottom of desktop, so it measures distance from desktop bottom to floor
  // This distance IS the desk height, so use reading directly
  if (sensor_available) {
    VL53L0X_RangingMeasurementData_t measure;
    lox.rangingTest(&measure, false);
    if (measure.RangeStatus != 4) {
      currentHeight = measure.RangeMilliMeter;
      // Clamp to reasonable bounds to prevent invalid readings
      if (currentHeight < 0) currentHeight = 0;
      if (currentHeight > 2000) currentHeight = 2000;
      
      // Safety check for manual up/down movements (when no targetHeight is set)
      // Automatically stop if limits are reached during manual movement
      if (targetHeight < 0) {  // Only check for manual movements (no preset/target active)
        static unsigned long lastManualCheck = 0;
        if (millis() - lastManualCheck >= 100) {  // Check every 100ms
          lastManualCheck = millis();
          
          // Check if desk is moving up and hit max limit
          if (digitalRead(UP_PIN) == LOW && currentHeight >= maxHeight - 10) {
            // Relay is ON (moving up) and hit maximum limit
            moveDesk("stop");
            Serial.println("AUTO-STOP: Manual up movement reached maximum height limit");
          }
          // Check if desk is moving down and hit min limit
          else if (digitalRead(DOWN_PIN) == LOW && currentHeight <= minHeight + 10) {
            // Relay is ON (moving down) and hit minimum limit
            moveDesk("stop");
            Serial.println("AUTO-STOP: Manual down movement reached minimum height limit");
          }
        }
      }
    }
  }
  
  // Handle ongoing movement (non-blocking, state-driven)
  if (targetHeight >= 0 && !stopMovement && sensor_available) {
    // Check for timeout (30 seconds safety limit)
    if (movementStartTime > 0 && millis() - movementStartTime > 30000) {
      moveDesk("stop");
      targetHeight = -1;
      movementStartTime = 0;
      consecutiveValidReadings = 0;
      stableHeightCount = 0;
    } else if (millis() - lastMovementCheck >= 100) {  // Check every 100ms
      lastMovementCheck = millis();
      
      // Use current height reading directly (sensor is mounted on desk bottom, readings should be accurate)
      int filteredHeight = currentHeight;
      // Update last valid height for comparison (but don't filter - trust sensor readings)
      lastValidHeight = currentHeight;
      
      // Safety check: Stop immediately if we've exceeded limits (with buffer to prevent overshoot)
      if (filteredHeight <= minHeight + 10) {
        // At or below minimum + buffer - emergency stop (prevents overshoot going down)
        Serial.println("EMERGENCY STOP: Below minimum height limit!");
        moveDesk("stop");
        targetHeight = -1;
        movementStartTime = 0;
        consecutiveValidReadings = 0;
        stableHeightCount = 0;
        lastMovementHeight = filteredHeight;
      } else if (filteredHeight >= maxHeight - 10) {
        // At or above maximum - buffer - emergency stop (prevents overshoot going up)
        Serial.println("EMERGENCY STOP: Above maximum height limit!");
        moveDesk("stop");
        targetHeight = -1;
        movementStartTime = 0;
        consecutiveValidReadings = 0;
        stableHeightCount = 0;
        lastMovementHeight = filteredHeight;
      } else {
        // Detect if height has stopped changing (desk hit physical limit)
        // Check if height changed by more than 5mm (larger threshold to account for sensor noise)
        if (abs(filteredHeight - lastMovementHeight) <= 5) {
          // Height hasn't changed significantly (within 5mm)
          stableHeightCount++;
          Serial.print("Height stable: ");
          Serial.print(filteredHeight);
          Serial.print("mm, count: ");
          Serial.println(stableHeightCount);
          
          if (stableHeightCount >= 8) {  // Height stable for 0.8 seconds (8 * 100ms)
            // Desk appears to have hit a physical limit, stop movement
            Serial.println("STOPPED: Height stable (desk hit physical limit)");
            moveDesk("stop");
            targetHeight = -1;
            movementStartTime = 0;
            consecutiveValidReadings = 0;
            stableHeightCount = 0;
            lastMovementHeight = filteredHeight;
          } else {
            // Still waiting for confirmation, but continue checking movement direction
            // Don't reset stableHeightCount here - let it accumulate
          }
        } else {
          // Height is changing, reset stable counter
          if (stableHeightCount > 0) {
            Serial.print("Height changing: ");
            Serial.print(lastMovementHeight);
            Serial.print(" -> ");
            Serial.println(filteredHeight);
          }
          stableHeightCount = 0;
          lastMovementHeight = filteredHeight;
          lastHeightChangeTime = millis();
        }
        int difference = abs(filteredHeight - targetHeight);
        
        // Only proceed with movement logic if height is not stable (still moving)
        if (stableHeightCount < 8) {
          // Require 3 consecutive readings within tolerance to actually stop
          // This prevents premature stopping due to sensor noise
          if (difference <= 15) {
            consecutiveValidReadings++;
            Serial.print("Close to target: ");
            Serial.print(filteredHeight);
            Serial.print("mm, target: ");
            Serial.print(targetHeight);
            Serial.print("mm, readings: ");
            Serial.println(consecutiveValidReadings);
            
            if (consecutiveValidReadings >= 3) {
              // Reached target - confirmed by multiple readings
              Serial.println("STOPPED: Reached target height");
              moveDesk("stop");
              targetHeight = -1;
              movementStartTime = 0;
              consecutiveValidReadings = 0;
              stableHeightCount = 0;
              lastMovementHeight = filteredHeight;
            } else {
              // Keep moving but we're getting close - respect limits
              if (filteredHeight < targetHeight - 5 && filteredHeight < maxHeight - 20) {
                moveDesk("up");
              } else if (filteredHeight > targetHeight + 5 && filteredHeight > minHeight + 20) {
                moveDesk("down");
              } else {
                // At limit or very close to target, stop
                Serial.println("STOPPED: At limit or very close to target");
                moveDesk("stop");
                targetHeight = -1;
                movementStartTime = 0;
                consecutiveValidReadings = 0;
                stableHeightCount = 0;
                lastMovementHeight = filteredHeight;
              }
            }
          } else {
            // Not at target yet, reset counter and continue moving - but respect limits
            consecutiveValidReadings = 0;
            if (filteredHeight < targetHeight - 15 && filteredHeight < maxHeight - 20) {
              moveDesk("up");
            } else if (filteredHeight > targetHeight + 15 && filteredHeight > minHeight + 20) {
              moveDesk("down");
            } else {
              // At limit, stop
              Serial.println("STOPPED: Would exceed limits");
              moveDesk("stop");
              targetHeight = -1;
              movementStartTime = 0;
              consecutiveValidReadings = 0;
              stableHeightCount = 0;
              lastMovementHeight = filteredHeight;
            }
          }
        }
        // If stableHeightCount >= 8, we've already stopped in the stability check above
      }
    }
  } else if (stopMovement && targetHeight >= 0) {
    // Stop was requested during movement
    moveDesk("stop");
    targetHeight = -1;
    movementStartTime = 0;
    consecutiveValidReadings = 0;
    stableHeightCount = 0;
    stopMovement = false;
  }
  
  WiFiClient client = server.available();
  if (client) {
    // Set a longer timeout for client connection
    client.setTimeout(1000); // 1 second timeout for reading
    
    // Wait for client data
    unsigned long timeout = millis() + 5000;
    while (!client.available() && millis() < timeout) {
      delay(1);
    }
    
    if (!client.available()) {
      client.stop();
      return;
    }
    
    // Read the HTTP request line
    String request = client.readStringUntil('\n');
    request.trim();
    Serial.println("Received: " + request);
    
    // Read and discard remaining headers (until blank line)
    while (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      if (line.length() == 0) {
        break; // End of headers
      }
    }
    
    // Handle CORS preflight requests (OPTIONS)
    if (request.startsWith("OPTIONS")) {
      client.println("HTTP/1.1 200 OK");
      client.println("Access-Control-Allow-Origin: *");
      client.println("Access-Control-Allow-Methods: GET, POST, OPTIONS");
      client.println("Access-Control-Allow-Headers: Content-Type");
      client.println("Connection: close");
      client.println();
      client.stop();
      return;
    }
    
    // Parse HTTP request: "GET /command HTTP/1.1" -> extract "/command"
    String command = "";
    int firstSpace = request.indexOf(' ');
    int secondSpace = request.indexOf(' ', firstSpace + 1);
    
    if (firstSpace > 0 && secondSpace > firstSpace) {
      command = request.substring(firstSpace + 1, secondSpace);
      // Remove leading slash if present
      if (command.startsWith("/")) {
        command = command.substring(1);
      }
    } else {
      // Fallback: try to parse as direct command (for compatibility)
      command = request;
    }
    
    // URL decode the command (replace %20 with space, %2B with +, etc.)
    command.replace("%20", " ");
    command.replace("%2B", "+");
    command.replace("%2F", "/");
    command.replace("%3D", "=");
    command.replace("%3F", "?");
    command.replace("%26", "&");
    
    Serial.println("Parsed command: " + command);
    
    // Send HTTP response headers with CORS support for web app
    client.println("HTTP/1.1 200 OK");
    client.println("Content-Type: text/plain");
    client.println("Access-Control-Allow-Origin: *");
    client.println("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    client.println("Access-Control-Allow-Headers: Content-Type");
    client.println("Connection: close");
    client.println();

    // Command: Move desk up
    if (command == "up") {
      // Check safety limits before moving up
      if (currentHeight >= maxHeight - 10) {
        moveDesk("stop");
        client.println("Cannot move up: At maximum height limit (" + String(maxHeight) + " mm)");
        client.println("Current height: " + String(currentHeight) + " mm");
      } else {
        moveDesk("up");
        client.println("Moving up");
        client.println("Current height: " + String(currentHeight) + " mm, Max: " + String(maxHeight) + " mm");
      }

    // Command: Move desk down
    } else if (command == "down") {
      // Check safety limits before moving down
      if (currentHeight <= minHeight + 10) {
        moveDesk("stop");
        client.println("Cannot move down: At minimum height limit (" + String(minHeight) + " mm)");
        client.println("Current height: " + String(currentHeight) + " mm");
      } else {
        moveDesk("down");
        client.println("Moving down");
        client.println("Current height: " + String(currentHeight) + " mm, Min: " + String(minHeight) + " mm");
      }

    // Command: Stop the desk
    } else if (command == "stop") {
      stopMovement = true;  // Set flag to stop any ongoing movement
      targetHeight = -1;  // Cancel any target movement
      movementStartTime = 0;  // Reset movement start time
      moveDesk("stop");
      stopMovement = false;  // Reset flag after stopping
      client.println("Stopped");

    // Command: Move desk to a preset height
    } else if (command.startsWith("goto")) {
      int preset = command.substring(4).toInt();
      if (preset >= 0 && preset < 3) {
        if (!sensor_available) {
          client.println("ERROR: Height sensor not available. Cannot move to preset.");
        } else {
          stopMovement = false;  // Reset stop flag before starting movement
          targetHeight = presetHeights[preset];  // Set target for non-blocking movement
          movementStartTime = millis();  // Record when movement started
          lastMovementCheck = 0;  // Reset check timer
          consecutiveValidReadings = 0;  // Reset consecutive readings counter
          stableHeightCount = 0;  // Reset stable height counter
          lastValidHeight = currentHeight;  // Initialize filtered height
          lastMovementHeight = currentHeight;  // Initialize movement tracking
          client.println("Moving to preset " + String(preset) + ": " + String(presetHeights[preset]) + " mm");
          client.println("Current: " + String(currentHeight) + " mm, Target: " + String(targetHeight) + " mm");
          client.println("Use /stop to cancel movement");
        }
      } else {
        client.println("Invalid preset number");
      }

    // Command: Update a preset height
    } else if (command.startsWith("set") && !command.startsWith("setmin") && !command.startsWith("setmax")) {
      // Parse "set0 500" or "set1 600" etc.
      int spaceIndex = command.indexOf(' ');
      if (spaceIndex > 0) {
        int preset = command.substring(3, spaceIndex).toInt();
        int newHeight = command.substring(spaceIndex + 1).toInt();
        if (preset >= 0 && preset < 3 && newHeight >= minHeight && newHeight <= maxHeight) {
          presetHeights[preset] = newHeight;
          client.println("Preset " + String(preset) + " updated to " + String(newHeight) + " mm");
        } else {
          client.println("Invalid preset or height");
          client.println("Height must be between " + String(minHeight) + " and " + String(maxHeight) + " mm");
        }
      } else {
        client.println("Invalid set command format");
      }
    
    // Command: Set minimum height limit
    } else if (command.startsWith("setmin")) {
      int newMin = command.substring(6).toInt();
      if (newMin > 0 && newMin < maxHeight) {
        minHeight = newMin;
        client.println("Minimum height set to " + String(minHeight) + " mm");
      } else {
        client.println("Invalid minimum height. Must be > 0 and < " + String(maxHeight));
      }
    
    // Command: Set maximum height limit
    } else if (command.startsWith("setmax")) {
      int newMax = command.substring(6).toInt();
      if (newMax > minHeight && newMax < 2000) {
        maxHeight = newMax;
        client.println("Maximum height set to " + String(maxHeight) + " mm");
      } else {
        client.println("Invalid maximum height. Must be > " + String(minHeight) + " and < 2000");
      }
    
    // Command: Get height limits
    } else if (command == "limits") {
      client.println("Height Limits:");
      client.println("Minimum: " + String(minHeight) + " mm");
      client.println("Maximum: " + String(maxHeight) + " mm");

    // Command: Move desk to a specific height manually
    } else if (command.startsWith("height")) {
      int height = command.substring(6).toInt();
      if (height >= minHeight && height <= maxHeight) {
        if (!sensor_available) {
          client.println("ERROR: Height sensor not available. Cannot move to specific height.");
        } else {
          stopMovement = false;  // Reset stop flag before starting movement
          targetHeight = height;  // Set target for non-blocking movement
          movementStartTime = millis();  // Record when movement started
          lastMovementCheck = 0;  // Reset check timer
          consecutiveValidReadings = 0;  // Reset consecutive readings counter
          stableHeightCount = 0;  // Reset stable height counter
          lastValidHeight = currentHeight;  // Initialize filtered height
          lastMovementHeight = currentHeight;  // Initialize movement tracking
          client.println("Moving to height: " + String(height) + " mm");
          client.println("Current: " + String(currentHeight) + " mm, Target: " + String(targetHeight) + " mm");
          client.println("Use /stop to cancel movement");
        }
      } else {
        client.println("Invalid height: " + String(height) + " mm");
        client.println("Height must be between " + String(minHeight) + " and " + String(maxHeight) + " mm");
      }

    // Command: Get status
    } else if (command == "status" || command == "") {
      client.println("ESP32 Desk Controller Status");
      client.println("WiFi: " + String(WiFi.status() == WL_CONNECTED ? "Connected" : "Disconnected"));
      if (WiFi.status() == WL_CONNECTED) {
        client.println("IP: " + WiFi.localIP().toString());
        client.println("RSSI: " + String(WiFi.RSSI()) + " dBm");
      }
      client.println("Server: " + String(server_started ? "Running" : "Not Started"));
      client.println("Sensor: " + String(sensor_available ? "Available" : "Not Available"));
      client.println("Current Height: " + String(currentHeight) + " mm");
      client.println("Height Limits: " + String(minHeight) + " - " + String(maxHeight) + " mm");

    } else {
      client.println("Unknown command: " + command);
      client.println("Available commands: up, down, stop, status, goto0-2, height<mm>");
    }

    // Always respond with current height
    client.println("Current height: " + String(currentHeight) + " mm");
    client.stop();
  }
}

void moveDesk(String command) {
  // Relay modules are typically active LOW (LOW = ON, HIGH = OFF)
  if (command == "up") {
    digitalWrite(UP_PIN, LOW);    // LOW = relay ON (move up)
    digitalWrite(DOWN_PIN, HIGH); // HIGH = relay OFF
  } else if (command == "down") {
    digitalWrite(UP_PIN, HIGH);   // HIGH = relay OFF
    digitalWrite(DOWN_PIN, LOW);  // LOW = relay ON (move down)
  } else if (command == "stop") {
    digitalWrite(UP_PIN, HIGH);   // HIGH = relay OFF (stop)
    digitalWrite(DOWN_PIN, HIGH); // HIGH = relay OFF (stop)
  }
}

// Note: moveToHeight function removed - movement is now handled non-blockingly in the main loop

