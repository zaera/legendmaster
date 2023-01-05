#include <SPI.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <elapsedMillis.h>
#include "bitmaps.h"

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 64 // OLED display height, in pixels

// Declaration for SSD1306 display connected using software SPI (default case):

#define OLED_RESET     13 // Reset pin # (or -1 if sharing Arduino reset pin)
#define SCREEN_ADDRESS 0x3D ///< See datasheet for Address; 0x3D for 128x64, 0x3C for 128x32
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

String inData;
// Replace with your network credentials

char* host = "Punishman_LM011";
char ssid[32]     = "zaera";
char password[32] = "13579135791";
bool status_wifi = false;
String ip = "";

#define BUTTON_LEFT 17 // GIOP21 pin connected to button
int currentState_left;     // the current reading from the input pin
int lastState_left = HIGH; // the previous state from the input pin

#define BUTTON_RIGHT 27 // GIOP21 pin connected to button
int currentState_right;     // the current reading from the input pin
int lastState_right = HIGH; // the previous state from the input pin
long long_press_sleep = 0;

bool sleepingFlag = false;

elapsedMillis timeElapsed;//Create an Instance
bool boot1_ = true;
bool boot2_ = false;
bool bt_ = false;

void setup() {
    // SSD1306_SWITCHCAPVCC = generate display voltage from 3.3V internally
if(!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println(F("SSD1306 allocation failed"));
    for(;;); // Don't proceed, loop forever
  }

  display.drawPixel(10, 10, SSD1306_WHITE);
  display.display();
  display.clearDisplay();
  show_boot1();
}

void loop() {
  boot_and_main();
//    display.clearDisplay(); //for Clearing the display
//  display.drawBitmap(0, 0, d1_1, 128, 64, WHITE); // display.drawBitmap(x position, y position, bitmap data, bitmap width, bitmap height, color)
//  display.display();
//  delay(1000);
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

  display.setTextSize(1); // Draw 2X-scale text
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(33, 14);

  String ip_con = "0.0.0.0";
  display.println(String(host) + '\n' + '\n'+ '\n' + "      " + String(ssid) + '\n' + '\n' + "      " + ip_con);

  display.display();
  

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
