# RemoteESwitch
Based on the original RemoteESwitch HW of carloscrespog/RemoteESwitch.
The Hardware consists maily of two Waspmote PRO v12 & two SX1272 LoRa modules.

## Changes
The original version of the code was just sending packets when enabled and stopped transmission when disabled.
This version now exchanges switch state and relay state such that connection loss can be detected independently.
When connection loss occurs the relay will only switch on again if the user switches off and on again.
Furthermore, the additional RELAY circuit and the RX Waspmote will always be in a safe state in case of power outage/low battery.
