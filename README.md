This is a berrry script for esp32/Tamota which can parse the victron protocol. It renders it friendly on the console and also sends the untampered raw values over MQTT.

To use, customize which pins will receive the VE-Direct protocol inside of victron.be.

This script only reads data from the victron and does not send any data: the TX pin does not need to be connected.  However, it's not a bad idea to wire it up in case this script evolves. 

Note that many victron modules use 5volt ttl serial - - which, best I can tell, can be directly plumbed into the esp32 chip I am using. Not all chips will enjoy (not die) 5 volts on their GPIO pins, you may need or want a level shifter chip: I didn't, and I'm still here to write bad code.  

Upload the victron.be script, and then manually start it from the scripting console via 

load("victron.be")

if it operates correctly -- upload the autoexec.be script to start it on boot and reboot the esp32.  
