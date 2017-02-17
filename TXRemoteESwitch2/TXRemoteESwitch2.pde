#include <WaspSX1272.h>

// Switch stuff
int eSwitch = DIGITAL8;
enum States {
  UNKNOWN = 0,
  CLOSED = 1,
  OPENED = 2
};
States relayState = UNKNOWN;
States switchState = UNKNOWN;

// REMOTE and MASTER ADDRESSES
#define ESTOP_MASTER_ADDR 7
#define ESTOP_REMOTE_ADDR 8

// status value from sx1272
int8_t e;

// power good variable
bool canExecute = false;

void setup() {
  // LoRa Stuff
  USB.ON();
  USB.println(F("Setting up E-STOP TX device"));
  USB.println(F("Uses Semtech SX1272 module TX in LoRa"));

  // Init sx1272 module
  sx1272.ON();

  // Select frequency channel
  e = sx1272.setChannel(CH_14_868);  
  USB.print(F("Setting Channel CH_14_868.\t state ")); 
  USB.println(e);

  // Select implicit (off) or explicit (on) header mode
  e = sx1272.setHeaderON();
  USB.print(F("Setting Header ON.\t\t state ")); 
  USB.println(e);

  // Select mode: from 1 to 10
  // Roughly: Mode 1 - max range, slow, high power, Mode 10 - min range, fast, low power
  e = sx1272.setMode(7);
  USB.print(F("Setting Mode '7'.\t\t state "));
  USB.println(e);  

  // Select CRC on or off
  e = sx1272.setCRC_OFF();
  USB.print(F("Setting CRC OFF.\t\t\t state ")); 
  USB.println(e);  

  // Select output power (Max, High or Low)
  e = sx1272.setPower('M');
  USB.print(F("Setting Power to 'M' (Max).\t\t state ")); 
  USB.println(e);  

  // Select the node address value: from 2 to 255
  e = sx1272.setNodeAddress(ESTOP_MASTER_ADDR);
  USB.print(F("Setting Node Address to '7'.\t state "));
  USB.println(e); 

  // Wait one second
  delay(1000);  
  // SETUP MICROVIEW
  //pinMode(MSB,OUTPUT);
  //digitalWrite(MSB,LOW);
  //pinMode(ESB,OUTPUT);
  //digitalWrite(ESB,LOW);
  //pinMode(LSB,OUTPUT);
  //digitalWrite(LSB,LOW);
  //drawESA();
  //delay(timeDelay);
  //drawOK();
  //delay(timeDelay);
  //drawLowBatt();
  //delay(timeDelay);
  //drawBrokenConn();
  //delay(timeDelay);
  //drawTimeout();
  //delay(timeDelay);
  //drawPressed();
  //delay(timeDelay);
  //drawESA();

  // E-STOP:
  //pull-up resistance
  pinMode(eSwitch,INPUT);
  digitalWrite(eSwitch,HIGH);
  Utils.setLED(LED0, LED_OFF);
  Utils.setLED(LED1, LED_OFF);
  USB.println(F("Setup complete."));
}

void switchFSM() {
  // Read switch
  switch (digitalRead(eSwitch))
  {
    default:
    case LOW:
      switchState = CLOSED;
      break;
    case HIGH:
      switchState = OPENED;
      break;
  }
  
  // Transmit switch state to remote
  uint8_t payload = (uint8_t)switchState;
  e = sx1272.sendPacketTimeout(ESTOP_REMOTE_ADDR, &payload, 1, 1000);
  USB.println(F("TX SS"));
  if (e != 0)
  {
    // handle transmission timeout
  }
  
  // Wait for request response
  e = sx1272.receivePacketTimeout(3000); // minumum RTT: 2s ... to be safe, we use 4s
  if (e != 0)
  {
    // handle receive timeout
    // lost 10 Packets, so we should consider relaystate as uunknown
    relayState = UNKNOWN;
    USB.println(F("RX TO"));
  }
  else
  {
    // store current relay state
    relayState = (States)(sx1272.packet_received.data[0]);
    USB.println(F("RX RS"));
  }
  
  // Show if states match
  if (relayState == switchState)
  {
    Utils.setLED(LED0, LED_OFF);
    Utils.setLED(LED1, LED_ON);
  }
  else
  {
    Utils.setLED(LED0, LED_ON);
    Utils.setLED(LED1, LED_OFF);
  }
  
  // Minimum loop latency
  delay(1000);
}
void pwrFSM()
{
  uint8_t lvl = PWR.getBatteryLevel();
  
  USB.print(F("Battery Level [%]: "));
  USB.print(lvl, DEC);
  USB.print(F("\n"));
  
  if (canExecute && (lvl < 30))
  {
    canExecute = false;
  }
  else if (!canExecute && (lvl > 40))
  {
    canExecute = true;
  }
 
  if (canExecute)
  {
    // Execute normally
    switchFSM();
  } else {
    // Execute but blink
    Utils.blinkLEDs(300);
    Utils.blinkLEDs(300);
    Utils.blinkLEDs(300);
    switchFSM();
  }
}

void loop()
{
  pwrFSM(); 
}

//void drawESA(){
//  //000
//  digitalWrite(MSB,LOW);
//  digitalWrite(ESB,LOW);
//  digitalWrite(LSB,LOW); 
//}
//void drawOK(){
//  //001
//  digitalWrite(MSB,LOW);
//  digitalWrite(ESB,LOW);
//  digitalWrite(LSB,HIGH);
//
//}
//
//void drawLowBatt(){
//  //010
//  digitalWrite(MSB,LOW);
//  digitalWrite(ESB,HIGH);
//  digitalWrite(LSB,LOW);
//
//}
//
//void drawBrokenConn(){
//  //011
//  digitalWrite(MSB,LOW);
//  digitalWrite(ESB,HIGH);
//  digitalWrite(LSB,HIGH);
//
//}
//void drawTimeout(){
//  //100
//  digitalWrite(MSB,HIGH);
//  digitalWrite(ESB,LOW);
//  digitalWrite(LSB,LOW);
//
//}
//void drawPressed(){
//  //101
//  digitalWrite(MSB,HIGH);
//  digitalWrite(ESB,LOW);
//  digitalWrite(LSB,HIGH);
//}

