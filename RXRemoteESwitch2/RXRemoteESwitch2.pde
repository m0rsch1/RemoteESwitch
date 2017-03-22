/*  
 *  ------ [SX_02b] - RX LoRa -------- 
 *  
 *  Explanation: This example shows how to configure the semtech 
 *  module in LoRa mode and then receive packets with plain-text payloads
 *  
 *  Copyright (C) 2014 Libelium Comunicaciones Distribuidas S.L. 
 *  http://www.libelium.com 
 *  
 *  This program is free software: you can redistribute it and/or modify  
 *  it under the terms of the GNU General Public License as published by  
 *  the Free Software Foundation, either version 3 of the License, or  
 *  (at your option) any later version.  
 *   
 *  This program is distributed in the hope that it will be useful,  
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of  
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the  
 *  GNU General Public License for more details.  
 *   
 *  You should have received a copy of the GNU General Public License  
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.  
 *  
 *  Version:           0.1
 *  Design:            David Gascón 
 *  Implementation:    Covadonga Albiñana, Yuri Carmona
 */

// Include this library for transmit with sx1272
#include <WaspSX1272.h>

// sensor I/0: Use to switch external 5V relay
int relayPin=DIGITAL7;

// Switch stuff
enum States {
  UNKNOWN = 0,
  CLOSED = 1,
  OPENED = 2
};
States relayState = UNKNOWN;
States switchState = UNKNOWN;
States internalState = UNKNOWN;

// REMOTE and MASTER ADDRESSES
#define ESTOP_MASTER_ADDR 7
#define ESTOP_REMOTE_ADDR 8

// status variable
int8_t e;

// power good variable
bool canExecute = false;

void setup() 
{
  // Init USB port
  USB.ON();
  USB.println(F("Setting up E-STOP RX device"));
  USB.println(F("Uses Semtech SX1272 module RX in LoRa"));

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
  e = sx1272.setNodeAddress(ESTOP_REMOTE_ADDR);
  USB.print(F("Setting Node Address to '8'.\t state "));
  USB.println(e); 

  // Wait one second
  delay(1000);  

  // Setting up relay pin and LEDs
  // NOTE: Switch POWER OFF per default (safety issues)
  // LOW: RELAY CLOSED = KILL SWITCH CLOSED (POWER OFF)
  // HIGH: RELAY OPENED = KILL SWITCH OPENED (POWER ON)
  pinMode(relayPin,OUTPUT);
  digitalWrite(relayPin,LOW);
  Utils.setLED(LED0, LED_ON);
  Utils.setLED(LED1, LED_OFF);
  
  // Setup 5V power line for relay
  PWR.setSensorPower(SENS_5V, SENS_ON);
  
  USB.println(F("Setup complete."));
}

void relayFSM()
{
  USB.println(F("PRE RX"));
  // receive packet
  e = sx1272.receivePacketTimeout(20000); // minimum: TX TO + 1s + TX + TX TO + 1s = 4 + N * (TX + TX TO + 1s) = 9s@N=1, 14s@N=2, 19s@N=3
  USB.println(F("POST RX"));
  if (e != 0)
  {
    // handle timeout
    // This means, that at least 3 consecutive packets of TX have been lost
    switchState = UNKNOWN;
    USB.println(F("RX TO"));
  }
  else
  {
    // Try to handle request of master device
    switchState = (States)(sx1272.packet_received.data[0]);
    uint8_t payload = (uint8_t)relayState;
    USB.println(F("PRE TX"));
    e = sx1272.sendPacketTimeout(ESTOP_MASTER_ADDR, &payload, 1, 1000);
    USB.println(F("POST TX"));
    if (e != 0)
    {
       // handle transmission timeout
    }
    USB.println(F("RX SS/TX RS"));
  }
  
  // Internal state machine transitions
  // UNKNOWN ---SW CLOSED?---> CLOSED ---SW OPEN?---> OPEN ---SW CLOSED?---> CLOSED
  // * ---TIMEOUT?---> UNKNOWN
  switch(internalState)
  {
    default:
    case UNKNOWN:
      if (switchState == CLOSED)
        internalState =  CLOSED;
      break;
    case OPENED:
      if (switchState == CLOSED)
        internalState = CLOSED;
      else if (switchState == UNKNOWN)
        internalState = UNKNOWN;
      break;
    case CLOSED:
      if (switchState == OPENED)
        internalState = OPENED;
      else if (switchState == UNKNOWN)
        internalState = UNKNOWN;
      break;
  }
  
  // Set relay according to internal state (which might have changed)
  switch(internalState)
  {
    default:
    case UNKNOWN:
      //USB.println(F("> SWITCH ? CLOSING RELAY"));
      digitalWrite(relayPin, LOW);
      break;
    case OPENED:
      //USB.println(F("> SWITCH OPENED. OPENING RELAY"));
      digitalWrite(relayPin, HIGH);
      break;
    case CLOSED:
      //USB.println(F("> SWITCH CLOSED. CLOSING RELAY"));
      digitalWrite(relayPin, LOW);
      break;
  }
  
  // show relay state
  switch(digitalRead(relayPin))
  {
    case HIGH:
      Utils.setLED(LED0, LED_OFF);
      Utils.setLED(LED1, LED_ON);
      relayState = OPENED;
      break;
    case LOW:
      Utils.setLED(LED0, LED_ON);
      Utils.setLED(LED1, LED_OFF);
      relayState = CLOSED;
      break;
  }
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
    relayFSM();
  } else {
    // Reset and wait for power
    internalState = UNKNOWN;
    digitalWrite(relayPin,LOW);
    Utils.setLED(LED0, LED_ON);
    Utils.setLED(LED1, LED_OFF);
    Utils.blinkLEDs(300);
  }
}

void loop()
{
  pwrFSM(); 
}





