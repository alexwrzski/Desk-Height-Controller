#include <WiFi.h>
#include <Adafruit_VL53L0X.h>

#define UP_PIN 16    // GPIO 16 - Connected to relay for UP
#define DOWN_PIN 17  // GPIO 17 - Connected to relay for DOWN
#define STATUS_LED 4  // Status LED pin (use GPIO 4, or change to your board's built-in LED pin)

// Wi-Fi credentials
// NOTE: ESP32 only supports 2.4GHz WiFi, NOT 5GHz!
const char* ssid = "Free WiFi";  // 2.4GHz network
const char* password = "nashaxata";

WiFiServer server(80);
Adafruit_VL53L0X lox = Adafruit_VL53L0X();

int presetHeights[3] = {300, 600, 900};  // Preset heights in mm
int minHeight = 575;  // Minimum desk height in mm (configurable)
int maxHeight = 1185; // Maximum desk height in mm (configurable)
int currentHeight = 0;
bool sensor_available = false;  // Track if sensor is working
bool server_started = false;  // Track if server has been started

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
  if (sensor_available) {
    VL53L0X_RangingMeasurementData_t measure;
    lox.rangingTest(&measure, false);
    if (measure.RangeStatus != 4) {
      currentHeight = measure.RangeMilliMeter;
    }
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
      moveDesk("up");
      client.println("Moving up");

    // Command: Move desk down
    } else if (command == "down") {
      moveDesk("down");
      client.println("Moving down");

    // Command: Stop the desk
    } else if (command == "stop") {
      moveDesk("stop");
      client.println("Stopped");

    // Command: Move desk to a preset height
    } else if (command.startsWith("goto")) {
      int preset = command.substring(4).toInt();
      if (preset >= 0 && preset < 3) {
        client.println("Moving to preset " + String(preset) + ": " + String(presetHeights[preset]) + " mm");
        client.flush(); // Send response immediately before starting movement
        moveToHeight(presetHeights[preset], client);
        client.println("Reached preset " + String(preset) + ": " + String(presetHeights[preset]) + " mm");
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
      int targetHeight = command.substring(6).toInt();
      if (targetHeight >= minHeight && targetHeight <= maxHeight) {
        client.println("Moving to height: " + String(targetHeight) + " mm");
        client.flush(); // Send response immediately before starting movement
        moveToHeight(targetHeight, client);
        client.println("Reached height: " + String(targetHeight) + " mm");
      } else {
        client.println("Invalid height: " + String(targetHeight) + " mm");
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

void moveToHeight(int targetHeight, WiFiClient &client) {
  if (!sensor_available) {
    client.println("ERROR: Height sensor not available. Cannot move to specific height.");
    return;
  }
  
  unsigned long startTime = millis();
  unsigned long timeout = 30000; // 30 second timeout for safety
  
  while (millis() - startTime < timeout) {
    // Read current height
    VL53L0X_RangingMeasurementData_t measure;
    lox.rangingTest(&measure, false);
    if (measure.RangeStatus != 4) {
      currentHeight = measure.RangeMilliMeter;
    }
    
    // Check if we're within tolerance (10mm)
    int difference = abs(currentHeight - targetHeight);
    if (difference <= 10) {
      moveDesk("stop");
      break;
    }
    
    // Move in the correct direction
    if (currentHeight < targetHeight - 10) {
      moveDesk("up");
    } else if (currentHeight > targetHeight + 10) {
      moveDesk("down");
    }
    
    delay(100);
  }
  
  // Always stop at the end
  moveDesk("stop");
}

