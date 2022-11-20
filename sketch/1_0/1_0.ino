//MINIMAL SPIFFS
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

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

// Declaration for an SSD1306 display connected to I2C (SDA, SCL pins)
#define OLED_RESET     -1 // Reset pin # (or -1 if sharing Arduino reset pin)
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);


#if !defined(CONFIG_BT_SPP_ENABLED)
#error Serial Bluetooth not available or not enabled. It is only available for the ESP32 chip.
#endif


String inData;
// Replace with your network credentials
char host[] = "LegendMaster";
char ssid[32]     = "zaera";
char password[32] = "13579135791";
bool status_wifi = false;
String ip = "";
WebServer server(80);



volatile byte indx;
String httpRequestData = "";

char serverName[64];
char* link_begin = "http://";


const char index_html[] PROGMEM = R"rawliteral(
<!DOCTYPE HTML><html><head>
  <title>ESP Input Form</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  </head><body>
  <form action="/get">
    input1: <input type="text" name="input1">
    <input type="submit" value="Submit">
  </form><br>
  <form action="/get">
    input2: <input type="text" name="input2">
    <input type="submit" value="Submit">
  </form><br>
  <form action="/get">
    input3: <input type="text" name="input3">
    <input type="submit" value="Submit">
  </form>
</body></html>)rawliteral";

/* Style */
String style =
  "<style>#file-input,input{width:100%;height:44px;border-radius:4px;margin:10px auto;font-size:15px}"
  "input{background:#f1f1f1;border:0;padding:0 15px}body{background:#3498db;font-family:sans-serif;font-size:14px;color:#777}"
  "#file-input{padding:0;border:1px solid #ddd;line-height:44px;text-align:left;display:block;cursor:pointer}"
  "#bar,#prgbar{background-color:#f1f1f1;border-radius:10px}#bar{background-color:#3498db;width:0%;height:10px}"
  "form{background:#fff;max-width:258px;margin:75px auto;padding:30px;border-radius:5px;text-align:center}"
  ".btn{background:#3498db;color:#fff;cursor:pointer}</style>";

/* Login page */
String loginIndex =
  "<form name=loginForm>"
  "<h1>Legend Master</h1>"
  "<input name=userid placeholder='User ID'> "
  "<input name=pwd placeholder=Password type=Password> "
  "<input type=submit onclick=check(this.form) class=btn value=Login></form>"
  "<script>"
  "function check(form) {"
  "if(form.userid.value=='admin' && form.pwd.value=='admin')"
  "{window.open('/serverIndex')}"
  "else"
  "{alert('Error Password or Username')}"
  "}"
  "</script>" + style;

/* Server Index Page */
String serverIndex =
  "<script src='https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>"
  "<form method='POST' action='#' enctype='multipart/form-data' id='upload_form'>"
  "<input type='file' name='update' id='file' onchange='sub(this)' style=display:none>"
  "<label id='file-input' for='file'>   Choose file...</label>"
  "<input type='submit' class=btn value='Update'>"
  "<br><br>"
  "<div id='prg'></div>"
  "<br><div id='prgbar'><div id='bar'></div></div><br></form>"
  "<script>"
  "function sub(obj){"
  "var fileName = obj.value.split('\\\\');"
  "document.getElementById('file-input').innerHTML = '   '+ fileName[fileName.length-1];"
  "};"
  "$('form').submit(function(e){"
  "e.preventDefault();"
  "var form = $('#upload_form')[0];"
  "var data = new FormData(form);"
  "$.ajax({"
  "url: '/update',"
  "type: 'POST',"
  "data: data,"
  "contentType: false,"
  "processData:false,"
  "xhr: function() {"
  "var xhr = new window.XMLHttpRequest();"
  "xhr.upload.addEventListener('progress', function(evt) {"
  "if (evt.lengthComputable) {"
  "var per = evt.loaded / evt.total;"
  "$('#prg').html('progress: ' + Math.round(per*100) + '%');"
  "$('#bar').css('width',Math.round(per*100) + '%');"
  "}"
  "}, false);"
  "return xhr;"
  "},"
  "success:function(d, s) {"
  "console.log('success!') "
  "},"
  "error: function (a, b, c) {"
  "}"
  "});"
  "});"
  "</script>" + style;

void setup() {

  // put your setup code here, to run once:
  Serial.begin(115200);                 // Serial setup


    // SSD1306_SWITCHCAPVCC = generate display voltage from 3.3V internally
  if(!display.begin(SSD1306_SWITCHCAPVCC, 0x3C)) { 
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }

  show_boot1();
  show_boot2();
  show_bt();
  test_show();




  
  ESP_BT.begin("LegendMaster");
  //saveCredentials();
  loadCredentials();

  strcpy(serverName, link_begin);

  WiFi.disconnect();
  WiFi.config(INADDR_NONE, INADDR_NONE, INADDR_NONE);  // This is a MUST!
  if (!WiFi.setHostname("Legend Master")) {
    Serial.println("Hostname failed to configure");
  }


  WiFi.begin(ssid, password);
  Serial.println("Connecting");

  while (WiFi.status() != WL_CONNECTED) {
    readBT();
    }



  Serial.println("");
  Serial.print("Connected to WiFi network with IP Address: ");
  Serial.println(WiFi.localIP());
  ip = WiFi.localIP().toString();
  status_wifi = true;



  /*use mdns for host name resolution*/
  if (!MDNS.begin(host)) { //http://esp32.local
    Serial.println("Error setting up MDNS responder!");
    while (1) {
      delay(1000);
    }
  }
  Serial.println("mDNS responder started");
  /*return index page which is stored in serverIndex */
  server.on("/", HTTP_GET, []() {
    server.sendHeader("Connection", "close");
    server.send(200, "text/html", loginIndex);
  });
  server.on("/serverIndex", HTTP_GET, []() {
    server.sendHeader("Connection", "close");
    server.send(200, "text/html", serverIndex);
    //server.send(200, "text/html", index_html);
  });
  /*handling uploading firmware file */
  server.on("/update", HTTP_POST, []() {
    server.sendHeader("Connection", "close");
    server.send(200, "text/plain", (Update.hasError()) ? "FAIL" : "OK");
    ESP.restart();
  }, []() {
    HTTPUpload& upload = server.upload();
    if (upload.status == UPLOAD_FILE_START) {
      Serial.printf("Update: %s\n", upload.filename.c_str());
      if (!Update.begin(UPDATE_SIZE_UNKNOWN)) { //start with max available size
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_WRITE) {
      /* flashing firmware to ESP*/
      if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
        Update.printError(Serial);
      }
    } else if (upload.status == UPLOAD_FILE_END) {
      if (Update.end(true)) { //true to set the size to the current progress
        Serial.printf("Update Success: %u\nRebooting...\n", upload.totalSize);
      } else {
        Update.printError(Serial);
      }
    }
  });
  server.begin();
}

void loop() {
    readBT();

  // put your main code here, to run repeatedly:

  server.handleClient();
  delay(1);
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
  delay(3000);
  }
void show_boot2(void) {
    display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, boot2, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(2000);
  }
void show_bt(void) {
    display.clearDisplay(); //for Clearing the display
  display.drawBitmap(0, 0, bt, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
  display.display();
  delay(5000);
  }
void test_show(void){
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
