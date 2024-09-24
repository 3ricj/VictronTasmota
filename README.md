To use, customize which pins will receive the VE-Direct protocol.  

This script only reads data from the victron, and does not send any data.  So the TX pin does not need to be wired up.  However, it's not a bad idea to wire it up in case this script evolves. 

Note that many victron modules use 5volt ttl serial - - which, best I can tell, can be directly plumbed into the esp32 chip I am using. Not all chips will enjoy (not die) 5 volts on their GPIO pins, you may need or want a level shifter chip, I didn't. 

Upload the victron.be script, and then manually start it from the scripting console via 

load("victron.be")

if it operates correctly -- upload the autoexec.be script to start it on boot and reboot the esp32.  
