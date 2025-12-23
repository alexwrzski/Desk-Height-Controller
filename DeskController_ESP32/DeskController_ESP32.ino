#include <WiFi.h>
#include <Adafruit_VL53L0X.h>
#include <Preferences.h>
#include <DNSServer.h>

#define UP_PIN 16    // GPIO 16 - Connected to relay for UP
#define DOWN_PIN 17  // GPIO 17 - Connected to relay for DOWN
#define STATUS_LED 4  // Status LED pin (use GPIO 4, or change to your board's built-in LED pin)

// WiFi Manager - Access Point credentials for setup
const char* ap_ssid = "DeskController-Setup";
const char* ap_password = "setup12345";  // Password for setup AP (8+ chars required)

Preferences preferences;
String saved_ssid = "";
String saved_password = "";
bool wifi_configured = false;
bool ap_mode = false;

WiFiServer server(80);
DNSServer dnsServer;
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

// Function to connect to WiFi
bool connectToWiFi(String ssid, String password) {
  Serial.print("Connecting to Wi-Fi: ");
  Serial.println(ssid);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), password.c_str());
  
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
    Serial.println("\n✓ Connected!");
    return true;
  } else {
    Serial.println("\n✗ Connection failed!");
    return false;
  }
}

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

  // Initialize Preferences for storing WiFi credentials
  preferences.begin("wifi", false);
  saved_ssid = preferences.getString("ssid", "");
  saved_password = preferences.getString("password", "");
  preferences.end();

  // Try to connect to saved WiFi credentials
  if (saved_ssid.length() > 0) {
    Serial.println("Found saved WiFi credentials, attempting to connect...");
    Serial.println("SSID: " + saved_ssid);
    wifi_configured = connectToWiFi(saved_ssid, saved_password);
  }

  // If connection failed, start Access Point mode for setup
  if (!wifi_configured) {
    Serial.println("\n=== WiFi Setup Mode ===");
    Serial.println("Starting Access Point for WiFi configuration...");
    Serial.print("AP SSID: ");
    Serial.println(ap_ssid);
    Serial.print("AP Password: ");
    Serial.println(ap_password);
    Serial.println("\nConnect to this network and open: http://192.168.4.1");
    
    WiFi.mode(WIFI_AP);
    WiFi.softAP(ap_ssid, ap_password);
    
    // Configure AP IP address
    IPAddress local_IP(192, 168, 4, 1);
    IPAddress gateway(192, 168, 4, 1);
    IPAddress subnet(255, 255, 255, 0);
    WiFi.softAPConfig(local_IP, gateway, subnet);
    
    IPAddress IP = WiFi.softAPIP();
    Serial.print("AP IP address: ");
    Serial.println(IP);
    
    // Start DNS server for captive portal (redirects all domains to our IP)
    dnsServer.start(53, "*", local_IP);  // Port 53, redirect all domains (*) to our IP
    Serial.println("✓ DNS server started (captive portal active)");
    Serial.println("✓ Connecting devices will automatically open setup page in browser");
    
    ap_mode = true;
    server.begin();
    server_started = true;
    
    Serial.println("✓ Captive portal ready! Connecting devices will automatically open setup page.");
    
    // Slow blink LED in AP mode
    digitalWrite(STATUS_LED, HIGH);
    delay(500);
    digitalWrite(STATUS_LED, LOW);
  } else {
    // WiFi connected successfully
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
  }
}

void loop() {
  // If in AP mode, handle setup requests (don't try to reconnect)
  if (ap_mode) {
    // Process DNS requests for captive portal (throttled to avoid lag)
    static unsigned long lastDNSProcess = 0;
    if (millis() - lastDNSProcess > 50) {  // Process DNS every 50ms max
      dnsServer.processNextRequest();
      lastDNSProcess = millis();
    }
    
    // Slow blink LED in AP mode
    static unsigned long lastBlink = 0;
    if (millis() - lastBlink > 1000) {
      lastBlink = millis();
      digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
    }
  } else {
    // Normal mode: Only process if WiFi is connected
    if (WiFi.status() != WL_CONNECTED) {
      // LED off when disconnected
      digitalWrite(STATUS_LED, LOW);
      
      // Try to reconnect using saved credentials
      static unsigned long lastReconnectAttempt = 0;
      if (millis() - lastReconnectAttempt > 10000) {  // Try every 10 seconds
        lastReconnectAttempt = millis();
        Serial.println("WiFi disconnected. Attempting to reconnect...");
        if (saved_ssid.length() > 0) {
          WiFi.disconnect();
          delay(100);
          connectToWiFi(saved_ssid, saved_password);
        }
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
      
      // Safety check: Only stop if we're at limit AND trying to go further in wrong direction
      // Allow movement back into safe zone even if currently outside limits
      bool shouldStopAtLimit = false;
      
      if (filteredHeight <= minHeight + 10) {
        // At or below minimum + buffer
        // Only stop if trying to go down (further below limit)
        if (targetHeight >= 0 && filteredHeight > targetHeight) {
          // Trying to go down when already at/below minimum - stop
          Serial.println("EMERGENCY STOP: At minimum limit, cannot go down further!");
          shouldStopAtLimit = true;
        } else {
          // At minimum but target is up or we're moving up - allow movement
          Serial.println("At minimum limit, but moving toward safe zone - allowing movement");
        }
      } else if (filteredHeight >= maxHeight - 10) {
        // At or above maximum - buffer
        // Only stop if trying to go up (further above limit)
        if (targetHeight >= 0 && filteredHeight < targetHeight) {
          // Trying to go up when already at/above maximum - stop
          Serial.println("EMERGENCY STOP: At maximum limit, cannot go up further!");
          shouldStopAtLimit = true;
        } else {
          // At maximum but target is down or we're moving down - allow movement
          Serial.println("At maximum limit, but moving toward safe zone - allowing movement");
        }
      }
      
      if (shouldStopAtLimit) {
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
              // Keep moving but we're getting close
              // Allow movement toward target even if outside limits (moving back into safe zone)
              bool canMoveUp = filteredHeight < targetHeight - 5;
              bool canMoveDown = filteredHeight > targetHeight + 5;
              
              // Only block movement if we're at limit AND trying to go further in wrong direction
              if (filteredHeight >= maxHeight - 10 && canMoveUp) {
                // At max limit and trying to go up - block
                Serial.println("STOPPED: At maximum limit, cannot go up");
                moveDesk("stop");
                targetHeight = -1;
                movementStartTime = 0;
                consecutiveValidReadings = 0;
                stableHeightCount = 0;
                lastMovementHeight = filteredHeight;
              } else if (filteredHeight <= minHeight + 10 && canMoveDown) {
                // At min limit and trying to go down - block
                Serial.println("STOPPED: At minimum limit, cannot go down");
                moveDesk("stop");
                targetHeight = -1;
                movementStartTime = 0;
                consecutiveValidReadings = 0;
                stableHeightCount = 0;
                lastMovementHeight = filteredHeight;
              } else if (canMoveUp) {
                // Safe to move up (either not at limit, or moving toward safe zone)
                moveDesk("up");
              } else if (canMoveDown) {
                // Safe to move down (either not at limit, or moving toward safe zone)
                moveDesk("down");
              } else {
                // Very close to target, stop
                Serial.println("STOPPED: Very close to target");
                moveDesk("stop");
                targetHeight = -1;
                movementStartTime = 0;
                consecutiveValidReadings = 0;
                stableHeightCount = 0;
                lastMovementHeight = filteredHeight;
              }
            }
          } else {
            // Not at target yet, reset counter and continue moving
            consecutiveValidReadings = 0;
            
            bool canMoveUp = filteredHeight < targetHeight - 15;
            bool canMoveDown = filteredHeight > targetHeight + 15;
            
            // Only block movement if we're at limit AND trying to go further in wrong direction
            if (filteredHeight >= maxHeight - 10 && canMoveUp) {
              // At max limit and trying to go up - block
              Serial.println("STOPPED: At maximum limit, cannot go up");
              moveDesk("stop");
              targetHeight = -1;
              movementStartTime = 0;
              consecutiveValidReadings = 0;
              stableHeightCount = 0;
              lastMovementHeight = filteredHeight;
            } else if (filteredHeight <= minHeight + 10 && canMoveDown) {
              // At min limit and trying to go down - block
              Serial.println("STOPPED: At minimum limit, cannot go down");
              moveDesk("stop");
              targetHeight = -1;
              movementStartTime = 0;
              consecutiveValidReadings = 0;
              stableHeightCount = 0;
              lastMovementHeight = filteredHeight;
            } else if (canMoveUp) {
              // Safe to move up (either not at limit, or moving toward safe zone)
              moveDesk("up");
            } else if (canMoveDown) {
              // Safe to move down (either not at limit, or moving toward safe zone)
              moveDesk("down");
            } else {
              // Shouldn't happen, but stop just in case
              Serial.println("STOPPED: Unexpected condition");
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
    
    // Read headers and find Content-Length for POST requests
    int contentLength = 0;
    while (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      if (line.length() == 0) {
        break; // End of headers
      }
      // Check for Content-Length header
      if (line.startsWith("Content-Length:")) {
        contentLength = line.substring(15).toInt();
      }
    }
    
    // Handle captive portal detection requests (iOS, Android, Windows)
    // These devices check specific URLs to detect captive portals
    if (ap_mode && (
        command == "generate_204" ||  // Android captive portal check
        command == "gen_204" ||        // Alternative Android check
        command == "hotspot-detect.html" ||  // iOS captive portal check
        command == "library/test/success.html" ||  // Windows captive portal check
        command == "kindle-wifi/wifiredirect.html" ||  // Kindle check
        command == "success.txt" ||  // Some Android variants
        command == "ncsi.txt" ||  // Windows Network Connectivity Status Indicator
        command == "connecttest.txt" ||  // Windows 10
        command == "redirect" ||  // Generic redirect
        command == "canonical.html" ||  // iOS
        command == "success.html"  // Generic success page
      )) {
      // Redirect to setup page
      client.println("HTTP/1.1 302 Found");
      client.println("Location: http://192.168.4.1/setup");
      client.println("Connection: close");
      client.println();
      client.stop();
      return;
    }
    
    // Handle WiFi setup page (only in AP mode or when requested)
    // In AP mode, redirect root (/) to setup page for captive portal
    if (command == "setup" || (ap_mode && command == "")) {
      // If in AP mode and accessing root, redirect to /setup (use relative URL to avoid loops)
      if (ap_mode && command == "") {
        client.println("HTTP/1.1 302 Found");
        client.println("Location: /setup");
        client.println("Connection: close");
        client.println();
        client.stop();
        return;
      }
      
      client.println("HTTP/1.1 200 OK");
      client.println("Content-Type: text/html");
      client.println("Cache-Control: no-cache, no-store, must-revalidate");
      client.println("Pragma: no-cache");
      client.println("Expires: 0");
      client.println("Connection: close");
      client.println();
      client.println("<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'>");
      client.println("<title>Desk Controller WiFi Setup</title>");
      client.println("<style>body{font-family:Arial,sans-serif;background:#1a1a1a;color:#fff;padding:20px;max-width:400px;margin:0 auto;}");
      client.println("h1{color:#3b82f6;}input{width:100%;padding:10px;margin:10px 0;border:1px solid #444;border-radius:6px;background:#111;color:#fff;box-sizing:border-box;}");
      client.println("button{width:100%;padding:12px;background:#3b82f6;color:#fff;border:none;border-radius:6px;font-size:16px;cursor:pointer;margin-top:10px;}");
      client.println("button:hover{background:#2563eb;}.status{background:#262626;padding:15px;border-radius:6px;margin:10px 0;}</style></head><body>");
      client.println("<h1>Desk Controller WiFi Setup</h1>");
      client.println("<p>Enter your WiFi network credentials:</p>");
      client.println("<form method='POST' action='/savewifi'>");
      client.println("<label>WiFi Network (SSID):</label>");
      client.println("<input type='text' name='ssid' required placeholder='Your WiFi Network Name'>");
      client.println("<label>Password:</label>");
      client.println("<input type='password' name='password' required placeholder='WiFi Password'>");
      client.println("<p style='font-size:12px;color:#888;'>Note: ESP32 only supports 2.4GHz WiFi networks</p>");
      client.println("<button type='submit'>Connect to WiFi</button>");
      client.println("</form></body></html>");
      client.stop();
      return;
    }
    
    // Handle save WiFi credentials
    if (command == "savewifi" && request.startsWith("POST")) {
      // Read POST data
      String postData = "";
      if (contentLength > 0) {
        for (int i = 0; i < contentLength && client.available(); i++) {
          postData += (char)client.read();
        }
      }
      
      // Parse SSID and password from POST data
      String new_ssid = "";
      String new_password = "";
      
      int ssidIndex = postData.indexOf("ssid=");
      int passIndex = postData.indexOf("password=");
      
      if (ssidIndex >= 0) {
        int ssidEnd = postData.indexOf("&", ssidIndex);
        if (ssidEnd < 0) ssidEnd = postData.length();
        new_ssid = postData.substring(ssidIndex + 5, ssidEnd);
        new_ssid.replace("+", " ");
        // URL decode
        new_ssid.replace("%20", " ");
        new_ssid.replace("%2B", "+");
      }
      
      if (passIndex >= 0) {
        int passEnd = postData.indexOf("&", passIndex);
        if (passEnd < 0) passEnd = postData.length();
        new_password = postData.substring(passIndex + 9, passEnd);
        new_password.replace("+", " ");
        // URL decode
        new_password.replace("%20", " ");
        new_password.replace("%2B", "+");
      }
      
      if (new_ssid.length() > 0) {
        // Save to Preferences
        preferences.begin("wifi", false);
        preferences.putString("ssid", new_ssid);
        preferences.putString("password", new_password);
        preferences.end();
        
        Serial.println("WiFi credentials saved. Attempting to connect...");
        
        // Try to connect
        if (connectToWiFi(new_ssid, new_password)) {
          ap_mode = false;
          saved_ssid = new_ssid;
          saved_password = new_password;
          
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println("Connection: close");
          client.println();
          client.println("<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'>");
          client.println("<title>WiFi Connected</title>");
          client.println("<style>body{font-family:Arial,sans-serif;background:#1a1a1a;color:#fff;padding:20px;max-width:400px;margin:0 auto;text-align:center;}");
          client.println("h1{color:#4ade80;}.status{background:#262626;padding:20px;border-radius:6px;margin:20px 0;}</style></head><body>");
          client.println("<h1>✓ WiFi Connected!</h1>");
          client.println("<div class='status'>");
          client.println("<p><strong>IP Address:</strong><br>" + WiFi.localIP().toString() + "</p>");
          client.println("<p>Your desk controller is now connected to your network.</p>");
          client.println("<p>You can close this page and use the desk controller app.</p>");
          client.println("</div></body></html>");
        } else {
          client.println("HTTP/1.1 200 OK");
          client.println("Content-Type: text/html");
          client.println("Connection: close");
          client.println();
          client.println("<!DOCTYPE html><html><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width, initial-scale=1.0'>");
          client.println("<title>Connection Failed</title>");
          client.println("<style>body{font-family:Arial,sans-serif;background:#1a1a1a;color:#fff;padding:20px;max-width:400px;margin:0 auto;text-align:center;}");
          client.println("h1{color:#f87171;}.status{background:#422;padding:20px;border-radius:6px;margin:20px 0;}</style></head><body>");
          client.println("<h1>✗ Connection Failed</h1>");
          client.println("<div class='status'>");
          client.println("<p>Could not connect to WiFi. Please check:</p>");
          client.println("<ul style='text-align:left;'>");
          client.println("<li>WiFi password is correct</li>");
          client.println("<li>Network is 2.4GHz (ESP32 doesn't support 5GHz)</li>");
          client.println("<li>Network is in range</li>");
          client.println("</ul>");
          client.println("<p><a href='/setup' style='color:#3b82f6;'>Try Again</a></p>");
          client.println("</div></body></html>");
        }
      } else {
        client.println("HTTP/1.1 400 Bad Request");
        client.println("Content-Type: text/plain");
        client.println("Connection: close");
        client.println();
        client.println("Invalid request");
      }
      client.stop();
      return;
    }
    
    // Handle reset WiFi (clears saved credentials and restarts in AP mode)
    if (command == "resetwifi") {
      preferences.begin("wifi", false);
      preferences.clear();
      preferences.end();
      
      client.println("HTTP/1.1 200 OK");
      client.println("Content-Type: text/plain");
      client.println("Access-Control-Allow-Origin: *");
      client.println("Connection: close");
      client.println();
      client.println("WiFi credentials cleared. ESP32 will restart in setup mode.");
      client.stop();
      
      delay(1000);
      ESP.restart();
      return;
    }
    
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
          Serial.println("=== PRESET MOVEMENT START ===");
          Serial.println("Preset: " + String(preset));
          Serial.println("Target Height: " + String(presetHeights[preset]) + " mm");
          Serial.println("Current Height: " + String(currentHeight) + " mm");
          Serial.println("Min Limit: " + String(minHeight) + " mm, Max Limit: " + String(maxHeight) + " mm");
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
        if (preset >= 0 && preset < 3) {
          // Allow presets slightly outside limits (with tolerance) for flexibility
          // This allows recovery if desk is outside limits
          if (newHeight >= (minHeight - 50) && newHeight <= (maxHeight + 50)) {
            presetHeights[preset] = newHeight;
            client.println("Preset " + String(preset) + " updated to " + String(newHeight) + " mm");
            Serial.println("Preset " + String(preset) + " saved: " + String(newHeight) + " mm");
          } else {
            client.println("Invalid preset height");
            client.println("Height should be between " + String(minHeight - 50) + " and " + String(maxHeight + 50) + " mm");
            Serial.println("Preset save rejected: " + String(newHeight) + " mm (outside acceptable range)");
          }
        } else {
          client.println("Invalid preset number (must be 0, 1, or 2)");
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
      client.println("Presets: 0=" + String(presetHeights[0]) + "mm, 1=" + String(presetHeights[1]) + "mm, 2=" + String(presetHeights[2]) + "mm");

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

