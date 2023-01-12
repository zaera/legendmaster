//MINIMAL SPIFFS
#include <Pangodream_18650_CL.h>
#include <elapsedMillis.h>
#include "bitmaps.h"

#include "BluetoothSerial.h"
BluetoothSerial ESP_BT;
#include <WiFi.h>
#include <WiFiClient.h>
#include <WebServer.h>
#include <ESPmDNS.h>
#include <Update.h>
#include "EEPROM.h"
#include <SPI.h>
#include <Wire.h>
#include <ESP2SOTA.h>


Pangodream_18650_CL BL;

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

// Declaration for an SSD1306 display connected to I2C (SDA, SCL pins)
//#define OLED_RESET     -1 // Reset pin # (or -1 if sharing Arduino reset pin)
//Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

#define OLED_RESET     18 // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3D ///< See datasheet for Address; 0x3D for 128x64, 0x3C for 128x32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


#if !defined(CONFIG_BT_SPP_ENABLED)
#error Serial Bluetooth not available or not enabled. It is only available for the ESP32 chip.
#endif


String inData;
// Replace with your network credentials

char* host = "Punishman_LM011";
char ssid[32] = "Punishman_LM011";
char password[32] = "13579135791";
bool status_wifi = false;
String ip = "";
WebServer server(80);


#define BUTTON_LEFT 17 // GIOP21 pin connected to button
int currentState_left;     // the current reading from the input pin
int lastState_left = HIGH; // the previous state from the input pin

#define BUTTON_RIGHT 27 // GIOP21 pin connected to button
int currentState_right;     // the current reading from the input pin
int lastState_right = HIGH; // the previous state from the input pin
long long_press_sleep = 0;

bool sleepingFlag = false;


#define BUTTON_PIN_BITMASK 0x200000000 // 2^33 in hex

RTC_DATA_ATTR int bootCount = 0;



volatile byte indx;
String httpRequestData = "";

char serverName[64];
char* link_begin = "http://";

elapsedMillis timeElapsed;//Create an Instance
bool boot1_ = true;
bool boot2_ = false;
bool bt_ = false;



#include "webserver.h"




void setup() {
  pinMode(BUTTON_LEFT, INPUT_PULLUP);
  pinMode(BUTTON_RIGHT, INPUT_PULLUP);

  

  // put your setup code here, to run once:
  Serial.begin(115200);                 // Serial setup

  delay(500);


  // SSD1306_SWITCHCAPVCC = generate display voltage from 3.3V internally
  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for (;;); // Don't proceed, loop forever
  }

  display.drawPixel(10, 10, SSD1306_WHITE);
  display.display();
  display.clearDisplay();
  show_boot1();


  ESP_BT.begin(host);
  //saveCredentials();
  
//!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  loadCredentials();

  strcpy(serverName, link_begin);

//  WiFi.disconnect();
//  WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE);  // This is a MUST!
//  if (!WiFi.setHostname(host)) {
//    Serial.println("Hostname failed to configure");
//  }
//
//  WiFi.begin(ssid, password);
//  Serial.println("Connecting");

// WIFI retries goes here

//  while (WiFi.status() != WL_CONNECTED) {
//    readBT();
//  }



//  Serial.println("");
//  Serial.print("Connected to WiFi network with IP Address: ");
//  Serial.println(WiFi.localIP());
//  ip = WiFi.localIP().toString();
//  status_wifi = true;



  /*use mdns for host name resolution*/
//  if (!MDNS.begin(host)) { //http://esp32.local
//    Serial.println("Error setting up MDNS responder!");
//    while (1) {
//      delay(1000);
//    }
//  }
//  Serial.println("mDNS responder started");
//  /*return index page which is stored in serverIndex */
//  server.on("/", HTTP_GET, []() {
//    server.sendHeader("Connection", "close");
//    server.send(200, "text/html", loginIndex);
//  });
//  server.on("/serverIndex", HTTP_GET, []() {
//    server.sendHeader("Connection", "close");
//    server.send(200, "text/html", serverIndex);
//    //server.send(200, "text/html", index_html);
//  });
//  /*handling uploading firmware file */
//  server.on("/update", HTTP_POST, []() {
//    server.sendHeader("Connection", "close");
//    server.send(200, "text/plain", (Update.hasError()) ? "FAIL" : "OK");
//    ESP.restart();
//  }, []() {
//    HTTPUpload& upload = server.upload();
//    if (upload.status == UPLOAD_FILE_START) {
//      Serial.printf("Update: %s\n", upload.filename.c_str());
//      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) { //start with max available size
//        Update.printError(Serial);
//      }
//    } else if (upload.status == UPLOAD_FILE_WRITE) {
//      /* flashing firmware to ESP*/
//      if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
//        Update.printError(Serial);
//      }
//    } else if (upload.status == UPLOAD_FILE_END) {
//      if (Update.end(true)) { //true to set the size to the current progress
//        Serial.printf("Update Success: %u\nRebooting...\n", upload.totalSize);
//      } else {
//        Update.printError(Serial);
//      }
//    }
//  });
//  server.begin();

WiFi.mode(WIFI_AP);  
  WiFi.softAP(ssid, password);
  delay(1000);
  IPAddress IP = IPAddress (10, 10, 10, 1);
  IPAddress NMask = IPAddress (255, 255, 255, 0);
  WiFi.softAPConfig(IP, IP, NMask);
  IPAddress myIP = WiFi.softAPIP();
  Serial.print("AP IP address: ");
  Serial.println(myIP);

  /* SETUP YOR WEB OWN ENTRY POINTS */
  server.on("/myurl", HTTP_GET, []() {
    server.sendHeader("Connection", "close");
    server.send(200, "text/plain", "Hello there!");
  });

  /* INITIALIZE ESP2SOTA LIBRARY */
  ESP2SOTA.begin(&server);
  server.begin();

}

void loop() {
  server.handleClient();
  battery();

  currentState_left = digitalRead(BUTTON_LEFT);
  currentState_right = digitalRead(BUTTON_RIGHT);

  if (lastState_left == LOW && currentState_left == HIGH) {
    Serial.println("LEFT");
  }

  if (lastState_right == LOW && currentState_right == HIGH) {
    Serial.println("RIGHT");
    long_press_sleep = 0;
  }

  else if (currentState_right == LOW) {
    long_press_sleep = long_press_sleep + 1;
  }
  if (long_press_sleep > 800) {
    long_press_sleep = 0;
    delay(1000);
    esp_sleep_enable_ext0_wakeup(GPIO_NUM_27,0);
    Serial.println("Going to sleep now");
    show_bye();
    display.clearDisplay();
    display.display();
    display.ssd1306_command(SSD1306_DISPLAYOFF);  // put the OLED display in sleep mode
    display.ssd1306_command(0x8D);          // disable charge pump

    
    delay(1000);
    sleepingFlag = true;
    esp_deep_sleep_start();
    Serial.println("This will never be printed");
  }
  lastState_left = currentState_left;
  lastState_right = currentState_right;

  readBT();

  // put your main code here, to run repeatedly:

  server.handleClient();
  delay(1);

  boot_and_main();

  print_wakeup_reason();
  delay(5);
}

void boot_and_main() {

  if (boot1_ == true) {
    show_boot1();
    if (timeElapsed > 4000)
    {
      boot1_ = false;
      boot2_ = true;
      bt_ = false;
      timeElapsed = 0;              // reset the counter to 0 so the counting starts over...
    }
  }
  if (boot2_ == true) {
    show_boot2();
    if (timeElapsed > 3000)
    {
      boot1_ = false;
      boot2_ = false;
      bt_ = true;
      timeElapsed = 0;              // reset the counter to 0 so the counting starts over...
    }
  }
  if (bt_ == true) {
    show_bt();
    if (timeElapsed > 2000)
    {
      boot1_ = false;
      boot2_ = false;
      bt_ = false;
      timeElapsed = 0;              // reset the counter to 0 so the counting starts over...
    }
  }
}

/** Load WLAN credentials from EEPROM */
void loadCredentials() {
  EEPROM.begin(512);
  EEPROM.get(0, ssid);
  EEPROM.get(0 + sizeof(ssid), password);
  char ok[2 + 1];
  EEPROM.get(0 + sizeof(ssid) + sizeof(password), ok);
  EEPROM.end();
  if (String(ok) != String("OK")) {
    ssid[0] = 0;
    password[0] = 0;
  }
  Serial.println("Recovered credentials:");
  Serial.println(ssid);
  Serial.println(strlen(password) > 0 ? "********" : "<no password>");
  //Serial.println(password);

  Serial2.println("Recovered credentials:");
  Serial2.println(ssid);
  Serial2.println(strlen(password) > 0 ? "********" : "<no password>");
  //Serial2.println(password);
}
/** Store WLAN credentials to EEPROM */
void saveCredentials() {
  EEPROM.begin(512);
  EEPROM.put(0, ssid);
  EEPROM.put(0 + sizeof(ssid), password);
  char ok[2 + 1] = "OK";
  EEPROM.put(0 + sizeof(ssid) + sizeof(password), ok);
  EEPROM.commit();
  EEPROM.end();
}
void readBT() {
  if (ESP_BT.available())
  {
    char recieved = ESP_BT.read();
    if (recieved == '!') {
      ESP_BT.println("_Status: " + status_wifi); delay(10);
      ESP_BT.println("SSID: " + String(ssid)); delay(10);
      ESP_BT.println("IP: " + ip); delay(10);
      ESP_BT.println("ACCESS RECEIVER ON: " + ip + "/"); delay(10);
      ESP_BT.println("ACCESS FIRMW UPDATE: " + ip + "/"); delay(10);
      ESP_BT.println("--------MENU--------"); delay(10);
      ESP_BT.println("*To set new SSID type <new_ssid>#"); delay(10);
      ESP_BT.println("*To set new PASS type <new_pass>%"); delay(10);
      ESP_BT.println("*To set new serverName type <address>*"); delay(10);
      ESP_BT.println("*To set wrists sleep type <on/off>)"); delay(10);
      ESP_BT.println("*To RESTART type &"); delay(10);
      ESP_BT.println("*To Backup SSID/PASS type }"); delay(10);
      inData = ""; // Clear recieved buffer
    }
    else if (recieved == '}')
    {
      Serial.print("Restored!");
      Serial.println();
      ESP_BT.print("Restored!");
      ESP_BT.println();
      String ssd = "zaera";
      String pas = "13579135791";
      ssd.toCharArray(ssid, 32);
      pas.toCharArray(password, 32);
      saveCredentials();
      delay(100);
      ESP.restart();
    }
    else if (recieved == ')')
    {
      inData.trim();
      Serial.print("New wrists sleep state:"); Serial.print(inData);
      Serial.println();
      ESP_BT.print("New wrists sleep state:"); ESP_BT.print(inData);
      ESP_BT.println();
      //  ssid=inData;
      saveCredentials();
      delay(10);
      inData = ""; // Clear recieved buffer
      ESP_BT.println("Reboot...");
      Serial.println("Reboot...");
      delay(100);
      ESP.restart();
    }
    else if (recieved == '*')
    {
      inData.trim();
      Serial.print("New serverName address: http://"); Serial.print(inData);
      Serial.println();
      ESP_BT.print("New serverName address: http://"); ESP_BT.print(inData);
      ESP_BT.println();
      //  ssid=inData;
      saveCredentials();
      delay(10);
      inData = ""; // Clear recieved buffer
      ESP_BT.println("Reboot...");
      Serial.println("Reboot...");
      delay(100);
      ESP.restart();
    }
    else if (recieved == '#')
    {
      inData.trim();
      Serial.print("New SSID:"); Serial.print(inData);
      Serial.println();
      ESP_BT.print("New SSID:"); ESP_BT.print(inData);
      ESP_BT.println();
      //  ssid=inData;
      memset(ssid, 0, sizeof ssid);
      delay(10);
      inData.toCharArray(ssid, 32);
      delay(10);
      saveCredentials();
      delay(10);
      inData = ""; // Clear recieved buffer
    }
    else if (recieved == '%')
    {
      inData.trim();
      Serial.print("New password:"); Serial.print(inData);
      Serial.println();
      ESP_BT.print("New password:"); ESP_BT.print(inData);
      ESP_BT.println();
      memset(password, 0, sizeof password);
      delay(10);
      inData.toCharArray(password, 32);
      delay(10);
      saveCredentials();
      delay(10);
      inData = ""; // Clear recieved buffer
    }
    else if (recieved == '&')
    {
      ESP_BT.println("Reboot...");
      Serial.println("Reboot...");
      delay(100);
      ESP.restart();
    }
    else {
      inData += recieved;
    }
  }
}


void show_boot1(void) {
  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, boot1, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
}


void show_boot2(void) {
  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, boot2, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
}


void show_bt(void) {
  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, bt, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)

//  display.drawBitmap(-32, 0, d1_8, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
//  display.drawBitmap(32, 0, d1_9, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  

  display.setTextSize(1); // Draw 2X-scale text
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(33, 14);
  String ip_con = WiFi.localIP().toString();
  if (ip_con == "0.0.0.0"){
    ip_con = "can't connect..";
    }
  display.println(String(host) + '\n' + '\n'+ '\n' + "      " + String(ssid) + '\n' + '\n' + "      " + ip_con);



//  display.setTextSize(1); // Draw 2X-scale text
//  display.setTextColor(SSD1306_WHITE);
//  display.setCursor(0, 0);
//  display.println("13213");

  display.display();
//  delay(1000);
  

}

void show_bye(){
    display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, bye, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)

  display.display();
  delay(1000);
  }


void test_show(void) {
  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_1, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_2, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_3, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_4, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_5, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_6, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_7, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_8, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_9, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_10, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_11, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_12, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_13, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_14, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_15, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);

  display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, d1_16, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(1000);
}

void print_wakeup_reason() {
  esp_sleep_wakeup_cause_t wakeup_reason;

  wakeup_reason = esp_sleep_get_wakeup_cause();
  if(sleepingFlag==true){
    Serial.println("Wake Up");
    wakeup();
    }

//  switch (wakeup_reason) {
//    case ESP_SLEEP_WAKEUP_EXT0 : Serial.println("Wakeup caused by external signal using RTC_IO"); break;
//    case ESP_SLEEP_WAKEUP_EXT1 : Serial.println("Wakeup caused by external signal using RTC_CNTL"); break;
//    case ESP_SLEEP_WAKEUP_TIMER : Serial.println("Wakeup caused by timer"); break;
//    case ESP_SLEEP_WAKEUP_TOUCHPAD : Serial.println("Wakeup caused by touchpad"); break;
//    case ESP_SLEEP_WAKEUP_ULP : Serial.println("Wakeup caused by ULP program"); break;
//    default : Serial.printf("Wakeup was not caused by deep sleep: %d\n", wakeup_reason); break;
//  }
}
void wakeup(){
  delay(100);
  Serial.println("Wake Up");
  delay(100);
  sleepingFlag = false;
  }

void battery(){
   Serial.print("Value from pin: ");
  Serial.println(analogRead(34));
  Serial.print("Average value from pin: ");
  Serial.println(BL.pinRead());
  Serial.print("Volts: ");
  Serial.println(BL.getBatteryVolts());
  Serial.print("Charge level: ");
  Serial.println(BL.getBatteryChargeLevel());
  Serial.println("");
  delay(1000);
  }
