# victron.be
# Copyright 3ric Johanson, 2024
# License: GNU General Public License v3.0
# Description:   This is a berrry script for esp32/Tamota which can parse the ascii victron protocol.  It renders it friendly on the console and also sends the untampered raw values over MQTT.  
# Note that many victron modules use 5volt ttl serial - - which, best I can tell, can be directly plumbed into the esp32 chip I am using. Not all chips will like 5 volts on their GPIO pins, you may need or want a level shifter chip, I didn't. 


import string
import mqtt
import json


class VICTRON : Driver

  static sensorname = "victron" 

  static serial_gpio_rx = 2
  static serial_gpio_tx = 1
  static buffer = {}
  static linefeed = bytes("0D0A")
  
  
  var last_msg
  var initialized
  var serial
  var webstring
  var jsonstring 
  
  
  
  static LABEL = {
 	"V": { "Units": "V", "Description": "Main or channel 1 (battery) voltage", "Multiplyer": 0.001 },
	"V2": { "Units": "mV", "Description": "Channel 2 (battery) voltage" },
	"V3": { "Units": "mV", "Description": "Channel 3 (battery) voltage" },
	"VS": { "Units": "mV", "Description": "Auxiliary (starter) voltage" },
	"VM": { "Units": "mV", "Description": "Mid-point voltage of the battery bank" },
	"DM": { "Units": "‰", "Description": "Mid-point deviation of the battery bank" },
	"VPV": { "Units": "V", "Description": "Panel voltage", "Multiplyer": 0.001  },
	"PPV": { "Units": "W", "Description": "Panel power" },
	"I": { "Units": "mA", "Description": "Main or channel 1 battery current" },
	"I2": { "Units": "mA", "Description": "Channel 2 battery current" },
	"I3": { "Units": "mA", "Description": "Channel 3 battery current" },
	"IL": { "Units": "mA", "Description": "Load current" },
	"LOAD": { "Units": "", "Description": "Load output state (ON/OFF)" },
	"T": { "Units": "°C", "Description": "Battery temperature" },
	"P": { "Units": "W", "Description": "Instantaneous power" },
	"CE": { "Units": "mAh", "Description": "Consumed Amp Hours" },
	"SOC": { "Units": "‰", "Description": "State-of-charge" },
	"TTG": { "Units": "Minutes", "Description": "Time-to-go" },
	"Alarm": { "Units": "", "Description": "Alarm condition active" },
	"Relay": { "Units": "", "Description": "Relay state" },
	"AR": { "Units": "", "Description": "Alarm reason" },
	"OR": { "Units": "", "Description": "Off reason" },
	"H1": { "Units": "mAh", "Description": "Depth of the deepest discharge" },
	"H2": { "Units": "mAh", "Description": "Depth of the last discharge" },
	"H3": { "Units": "mAh", "Description": "Depth of the average discharge" },
	"H4": { "Units": "", "Description": "Number of charge cycles" },
	"H5": { "Units": "", "Description": "Number of full discharges" },
	"H6": { "Units": "mAh", "Description": "Cumulative Amp Hours drawn" },
	"H7": { "Units": "V", "Description": "Minimum main (battery) voltage", "Multiplyer": 0.001  },
	"H8": { "Units": "V", "Description": "Maximum main (battery) voltage", "Multiplyer": 0.001  },
	"H9": { "Units": "Seconds", "Description": "Number of seconds since last full charge" },
	"H10": { "Units": "", "Description": "Number of automatic synchronizations" },
	"H11": { "Units": "", "Description": "Number of low main voltage alarms" },
	"H12": { "Units": "", "Description": "Number of high main voltage alarms" },
	"H13": { "Units": "", "Description": "Number of low auxiliary voltage alarms" },
	"H14": { "Units": "", "Description": "Number of high auxiliary voltage alarms" },
	"H15": { "Units": "mV", "Description": "Minimum auxiliary (battery) voltage" },
	"H16": { "Units": "mV", "Description": "Maximum auxiliary (battery) voltage" },
	"H17": { "Units": "Wh", "Description": "Amount of discharged energy (BMV) /Amount of produced energy (DC monitor)", "Multiplyer": 0.01  },
	"H18": { "Units": "kWh", "Description": "Amount of charged energy (BMV) /Amount of consumed energy (DC monitor)", "Multiplyer": 0.01  },
	"H19": { "Units": "kWh", "Description": "Yield total (user resettable counter)", "Multiplyer": 0.01  },
	"H20": { "Units": "kWh", "Description": "Yield today", "Multiplyer": 0.01  },
	"H21": { "Units": "W", "Description": "Maximum power today" },
	"H22": { "Units": "kWh", "Description": "Yield yesterday", "Multiplyer": 0.01  },
	"H23": { "Units": "W", "Description": "Maximum power yesterday" },
	"ERR": { "Units": "", "Description": "Error code" },
	"CS": { "Units": "", "Description": "State of operation" },
	"BMV": { "Units": "", "Description": "Model description (deprecated)" },
	"FW": { "Units": "", "Description": "Firmware version (16 bit)" },
	"FWE": { "Units": "", "Description": "Firmware version (24 bit)" },
	"PID": { "Units": "", "Description": "Product ID" },
	"SER#": { "Units": "", "Description": "Serial number" },
	"HSDS": { "Units": "", "Description": "Day sequence number (0..364)" },
	"MODE": { "Units": "", "Description": "Device mode" },
	"AC_OUT_V": { "Units": "V", "Description": "AC output voltage", "Multiplyer": 0.01 },
	"AC_OUT_I": { "Units": "A", "Description": "AC output current", "Multiplyer": 0.1},
	"AC_OUT_S": { "Units": "VA", "Description": "AC output apparent power" },
	"WARN": { "Units": "", "Description": "Warning reason" },
	"MPPT": { "Units": "", "Description": "Tracker operation mode" },
	"MON": { "Units": "", "Description": "DC monitor mode" },
	"DC_IN_V": { "Units": "V", "Description": "DC input voltage", "Multiplyer": 0.01 },
	"DC_IN_I": { "Units": "A", "Description": "DC input current", "Multiplyer": 0.1 },
	"DC_IN_P": { "Units": "W", "Description": "DC input power" }
  }
		
		
  static ERR = {
	0: "No error",
	2: "Battery voltage too high",
	17: "Charger temperature too high",
	18: "Charger over current",
	19: "Charger current reversed",
	20: "Bulk time limit exceeded",
	21: "Current sensor issue (sensor bias/sensor broken)",
	26: "Terminals overheated",
	28: "Converter issue (dual converter models only)",
	33: "Input voltage too high (solar panel)",
	34: "Input current too high (solar panel)",
	38: "Input shutdown (due to excessive battery voltage)",
	39: "Input shutdown (due to current flow during off mode)",
	65: "Lost communication with one of devices",
	66: "Synchronised charging device configuration issue",
	67: "BMS connection lost",
	68: "Network misconfigured",
	116: "Factory calibration data lost",
	117: "Invalid/incompatible firmware",
	119: "User settings invalid"

	}
	static MPPT = {
	0: "Off",
	1: "Voltage or current limited",
	2: "MPP Tracker active"
	}
	
	static CS = {
	0: "Off",
	1: "Low power",
	2: "Fault",
	3: "Bulk",
	4: "Absorption",
	5: "Float",
	6: "Storage",
	7: "Equalize (manual)",
	9: "Inverting",
	11: "Power supply",
	245: "Starting-up",
	246: "Repeated absorption",
	247: "Auto equalize / Recondition",
	248: "BatterySafe",
	252: "External Control"
	}

	
	static PID = {
	0x2030: "BMV-700",
	0x2040: "BMV-702",
	0x2050: "BMV-700H",
	0x0300: "BlueSolar MPPT 70|15",
	0xA040: "BlueSolar MPPT 75|50",
	0xA041: "BlueSolar MPPT 150|35",
	0xA042: "BlueSolar MPPT 75|15",
	0xA043: "BlueSolar MPPT 100|15",
	0xA044: "BlueSolar MPPT 100|30",
	0xA045: "BlueSolar MPPT 100|50",
	0xA046: "BlueSolar MPPT 150|70",
	0xA047: "BlueSolar MPPT 150|100",
	0xA049: "BlueSolar MPPT 100|50 rev2",
	0xA04A: "BlueSolar MPPT 100|30 rev2",
	0xA04B: "BlueSolar MPPT 150|35 rev2",
	0xA04C: "BlueSolar MPPT 75|10",
	0xA04D: "BlueSolar MPPT 150|45",
	0xA04E: "BlueSolar MPPT 150|60",
	0xA04F: "BlueSolar MPPT 150|85",
	0xA050: "SmartSolar MPPT 250|100",
	0xA051: "SmartSolar MPPT 150|100",
	0xA052: "SmartSolar MPPT 150|85",
	0xA053: "SmartSolar MPPT 75|15",
	0xA054: "SmartSolar MPPT 75|10",
	0xA055: "SmartSolar MPPT 100|15",
	0xA056: "SmartSolar MPPT 100|30",
	0xA057: "SmartSolar MPPT 100|50",
	0xA058: "SmartSolar MPPT 150|35",
	0xA059: "SmartSolar MPPT 150|100 rev2",
	0xA05A: "SmartSolar MPPT 150|85 rev2",
	0xA05B: "SmartSolar MPPT 250|70",
	0xA05C: "SmartSolar MPPT 250|85",
	0xA05D: "SmartSolar MPPT 250|60",
	0xA05E: "SmartSolar MPPT 250|45",
	0xA05F: "SmartSolar MPPT 100|20",
	0xA060: "SmartSolar MPPT 100|20 48V",
	0xA061: "SmartSolar MPPT 150|45",
	0xA062: "SmartSolar MPPT 150|60",
	0xA063: "SmartSolar MPPT 150|70",
	0xA064: "SmartSolar MPPT 250|85 rev2",
	0xA065: "SmartSolar MPPT 250|100 rev2",
	0xA066: "BlueSolar MPPT 100|20",
	0xA067: "BlueSolar MPPT 100|20 48V",
	0xA068: "SmartSolar MPPT 250|60 rev2",
	0xA069: "SmartSolar MPPT 250|70 rev2",
	0xA06A: "SmartSolar MPPT 150|45 rev2",
	0xA06B: "SmartSolar MPPT 150|60 rev2",
	0xA06C: "SmartSolar MPPT 150|70 rev2",
	0xA06D: "SmartSolar MPPT 150|85 rev3",
	0xA06E: "SmartSolar MPPT 150|100 rev3",
	0xA06F: "BlueSolar MPPT 150|45 rev2",
	0xA070: "BlueSolar MPPT 150|60 rev2",
	0xA071: "BlueSolar MPPT 150|70 rev2",
	0xA072: "BlueSolar MPPT 150/45 rev3",
	0xA073: "SmartSolar MPPT 150/45 rev3",
	0xA074: "SmartSolar MPPT 75/10 rev2",
	0xA075: "SmartSolar MPPT 75/15 rev2",
	0xA076: "BlueSolar MPPT 100/30 rev3",
	0xA077: "BlueSolar MPPT 100/50 rev3",
	0xA078: "BlueSolar MPPT 150/35 rev3",
	0xA079: "BlueSolar MPPT 75/10 rev2",
	0xA07A: "BlueSolar MPPT 75/15 rev2",
	0xA07B: "BlueSolar MPPT 100/15 rev2",
	0xA07C: "BlueSolar MPPT 75/10 rev3",
	0xA07D: "BlueSolar MPPT 75/15 rev3",
	0xA07E: "SmartSolar MPPT 100/30 12V",
	0xA07F: "All-In-1 SmartSolar MPPT 75/15 12V",
	0xA102: "SmartSolar MPPT VE.Can 150/70",
	0xA103: "SmartSolar MPPT VE.Can 150/45",
	0xA104: "SmartSolar MPPT VE.Can 150/60",
	0xA105: "SmartSolar MPPT VE.Can 150/85",
	0xA106: "SmartSolar MPPT VE.Can 150/100",
	0xA107: "SmartSolar MPPT VE.Can 250/45",
	0xA108: "SmartSolar MPPT VE.Can 250/60",
	0xA109: "SmartSolar MPPT VE.Can 250/70",
	0xA10A: "SmartSolar MPPT VE.Can 250/85",
	0xA10B: "SmartSolar MPPT VE.Can 250/100",
	0xA10C: "SmartSolar MPPT VE.Can 150/70 rev2",
	0xA10D: "SmartSolar MPPT VE.Can 150/85 rev2",
	0xA10E: "SmartSolar MPPT VE.Can 150/100 rev2",
	0xA10F: "BlueSolar MPPT VE.Can 150/100",
	0xA112: "BlueSolar MPPT VE.Can 250/70",
	0xA113: "BlueSolar MPPT VE.Can 250/100",
	0xA114: "SmartSolar MPPT VE.Can 250/70 rev2",
	0xA115: "SmartSolar MPPT VE.Can 250/100 rev2",
	0xA116: "SmartSolar MPPT VE.Can 250/85 rev2",
	0xA117: "BlueSolar MPPT VE.Can 150/100 rev2",
	0xA201: "Phoenix Inverter 12V 250VA 230V",
	0xA202: "Phoenix Inverter 24V 250VA 230V",
	0xA204: "Phoenix Inverter 48V 250VA 230V",
	0xA211: "Phoenix Inverter 12V 375VA 230V",
	0xA212: "Phoenix Inverter 24V 375VA 230V",
	0xA214: "Phoenix Inverter 48V 375VA 230V",
	0xA221: "Phoenix Inverter 12V 500VA 230V",
	0xA222: "Phoenix Inverter 24V 500VA 230V",
	0xA224: "Phoenix Inverter 48V 500VA 230V",
	0xA231: "Phoenix Inverter 12V 250VA 230V",
	0xA232: "Phoenix Inverter 24V 250VA 230V",
	0xA234: "Phoenix Inverter 48V 250VA 230V",
	0xA239: "Phoenix Inverter 12V 250VA 120V",
	0xA23A: "Phoenix Inverter 24V 250VA 120V",
	0xA23C: "Phoenix Inverter 48V 250VA 120V",
	0xA241: "Phoenix Inverter 12V 375VA 230V",
	0xA242: "Phoenix Inverter 24V 375VA 230V",
	0xA244: "Phoenix Inverter 48V 375VA 230V",
	0xA249: "Phoenix Inverter 12V 375VA 120V",
	0xA24A: "Phoenix Inverter 24V 375VA 120V",
	0xA24C: "Phoenix Inverter 48V 375VA 120V",
	0xA251: "Phoenix Inverter 12V 500VA 230V",
	0xA252: "Phoenix Inverter 24V 500VA 230V",
	0xA254: "Phoenix Inverter 48V 500VA 230V",
	0xA259: "Phoenix Inverter 12V 500VA 120V",
	0xA25A: "Phoenix Inverter 24V 500VA 120V",
	0xA25C: "Phoenix Inverter 48V 500VA 120V",
	0xA261: "Phoenix Inverter 12V 800VA 230V",
	0xA262: "Phoenix Inverter 24V 800VA 230V",
	0xA264: "Phoenix Inverter 48V 800VA 230V",
	0xA269: "Phoenix Inverter 12V 800VA 120V",
	0xA26A: "Phoenix Inverter 24V 800VA 120V",
	0xA26C: "Phoenix Inverter 48V 800VA 120V",
	0xA271: "Phoenix Inverter 12V 1200VA 230V",
	0xA272: "Phoenix Inverter 24V 1200VA 230V",
	0xA274: "Phoenix Inverter 48V 1200VA 230V",
	0xA279: "Phoenix Inverter 12V 1200VA 120V",
	0xA27A: "Phoenix Inverter 24V 1200VA 120V",
	0xA27C: "Phoenix Inverter 48V 1200VA 120V",
	0xA281: "Phoenix Inverter 12V 1600VA 230V",
	0xA282: "Phoenix Inverter 24V 1600VA 230V",
	0xA284: "Phoenix Inverter 48V 1600VA 230V",
	0xA291: "Phoenix Inverter 12V 2000VA 230V",
	0xA292: "Phoenix Inverter 24V 2000VA 230V",
	0xA294: "Phoenix Inverter 48V 2000VA 230V",
	0xA2A1: "Phoenix Inverter 12V 3000VA 230V",
	0xA2A2: "Phoenix Inverter 24V 3000VA 230V",
	0xA2A4: "Phoenix Inverter 48V 3000VA 230V",
	0xA340: "Phoenix Smart IP43 Charger 12|50 (1+1)",
	0xA341: "Phoenix Smart IP43 Charger 12|50 (3)",
	0xA342: "Phoenix Smart IP43 Charger 24|25 (1+1)",
	0xA343: "Phoenix Smart IP43 Charger 24|25 (3)",
	0xA344: "Phoenix Smart IP43 Charger 12|30 (1+1)",
	0xA345: "Phoenix Smart IP43 Charger 12|30 (3)",
	0xA346: "Phoenix Smart IP43 Charger 24|16 (1+1)",
	0xA347: "Phoenix Smart IP43 Charger 24|16 (3)",
	0xA381: "BMV-712 Smart",
	0xA382: "BMV-710H Smart",
	0xA383: "BMV-712 Smart Rev2",
	0xA389: "SmartShunt 500A/50mV",
	0xA38A: "SmartShunt 1000A/50mV",
	0xA38B: "SmartShunt 2000A/50mV",
	0xA3F0: "Smart BuckBoost 12V/12V-50A"
	}
	
	static OR = {
	0x00000001: "No input power",
	0x00000002: "Switched off (power switch)",
	0x00000004: "Switched off (device mode register)",
	0x00000008: "Remote input",
	0x00000010: "Protection active",
	0x00000020: "Paygo",
	0x00000040: "BMS",
	0x00000080: "Engine shutdown detection",
	0x00000100: "Analysing input voltage"
	}

	


  def init()
    self.serial  = serial(self.serial_gpio_rx, self.serial_gpio_tx, 19200, serial.SERIAL_8N1)
    self.start()
	
  end
  
  def start()
    self.initialized = true
  end
  
  def stop()
	self.initialized = false
  end

  	
  def process_packet()
    if self.last_msg == nil
      return
	end
	
	var temp = string.split(self.last_msg.asstring(), self.linefeed.asstring() )
	
	#if (size(self.last_msg.asstring()) > 190)
	#  print("Process large Packet.  Size: : " + str(size(self.last_msg.asstring()))) 
	#  print ("Lines to process: " + str(size(temp)))
	#  print (self.last_msg.asstring())
	#end 

	if size(temp) > 2 
		self.last_msg = nil
		self.webstring = ""
		self.jsonstring =  {}
		var description
		var units
		var value
		
		
		
		for i:temp  # each row
		  if size(i) > 3
			var linevalue = string.split(i, '\t')
			if size(linevalue) == 2   # sometimes, it sends us data in "hex" mode, without a tab and starting with a ":".  This forces us to have a name\tvalue pair for processing and ignores this hex data.
				  if self.LABEL.find(linevalue[0])  # all of the below logic is for decoding some of the values for display locally.  It does not change what is sent over MQTT.
					description = self.LABEL[linevalue[0]]["Description"]
					units = self.LABEL[linevalue[0]]["Units"]
					if self.LABEL[linevalue[0]].find("Multiplyer")
					  value = real(linevalue[1]) * self.LABEL[linevalue[0]]["Multiplyer"]
					elif  linevalue[0] == "PID" && self.PID.find(int(linevalue[1]))
					  value = self.PID.find(int(linevalue[1]))
					elif  linevalue[0] == "OR" && self.OR.find(int(linevalue[1]))
					  value = self.OR.find(int(linevalue[1]))
					elif  linevalue[0] == "MPPT" && self.MPPT.find(int(linevalue[1]))
					  value = self.MPPT.find(int(linevalue[1]))
					elif  linevalue[0] == "CS" && self.CS.find(int(linevalue[1]))
					  value = self.CS.find(int(linevalue[1]))
					elif  linevalue[0] == "ERR" && self.ERR.find(int(linevalue[1]))
					  value = self.ERR.find(int(linevalue[1]))
					else
					  value = linevalue[1]
					end
				  else
					description = linevalue[0]
					units = ""
				  end
				  
				  self.webstring +=  string.format("{s}%s{m}%s %s{e}", description, value, units)

                  if linevalue[0] == "PID" || linevalue[0] == "SER#" || linevalue[0] == "OR" # These values need quotes and such, are passed in as strings so the json module quotes them on output.
				    self.jsonstring[linevalue[0]] = linevalue[1]
				  else 
				    self.jsonstring[linevalue[0]] = real(linevalue[1])
				  end
			end
			  
		  end
		end
	end
  end
  

 
  def web_sensor()
    if !self.initialized return nil end
	if self.webstring tasmota.web_send(self.webstring) end
  end  
  
  def json_append()
    if !self.initialized return nil end
	if !self.jsonstring print ("ERROR: No jsonstring..") return nil end
	tasmota.response_append(",\"" + self.sensorname + "\":" + json.dump(self.jsonstring)) 
 end

  def every_50ms()
    if !self.initialized return nil end
    if self.serial.available() == 0
      return
    end
    var msg = self.serial.read()
	#print("size: " + str(size(msg.asstring()))) 
    if msg || size(msg) > 0
	  if self.last_msg
        self.last_msg += msg
      else
		self.last_msg = msg
	  end
    end
	if string.find(self.last_msg.asstring(), "Checksum") > 0
#		    print("Checksum found in 50ms loop")
	self.process_packet()
	  end
  end

  def every_500ms()
    if !self.initialized return nil end
	if !self.last_msg return nil end
      if string.find(self.last_msg.asstring(), "Checksum") > 0
#	    print("Checksum found in 500ms loop")
	    self.process_packet()
	  end
  end

  
  def every_second()
    if !self.initialized return nil end
	if !self.last_msg return nil end
	
    if self.last_msg && size(self.last_msg) >= 200
	  print("ERROR: Hmm, no checksum found, processing anyway")
      self.process_packet()
    end
  end
end

  
victron =   VICTRON()
tasmota.add_driver(victron)
  
