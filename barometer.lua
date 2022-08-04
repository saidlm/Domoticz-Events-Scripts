-- Barometer dzVents Script
-- Martin Saidl (c) 2022

-- current version of script 
local version = '0.1'

-- Source devices
local Outside_Temp = 'Venkovní teplota'
local Barometer_ABS = 'Barometr (abs) - BMP'

-- Destination device
local Barometer_REL = 'Barometr (rel) - BMP'

-- Elevation
local Elev = 490


return {
	on = {
		devices = {	Barometer_ABS }
	},
	execute = function(domoticz, device)
	    tempC = domoticz.devices(Outside_Temp).temperature
	    pressA = domoticz.devices(Barometer_ABS).barometer
	    
	    -- some Arduino lib formula
	    -- pressR = domoticz.utils.round((pressA * 9.80665 * Elev) / (287 * (273 + tempC + (Elev / 400))) + pressA, 1)
	    
	    -- ICAO formula
	    pressR = domoticz.utils.round(pressA / ((273.15 + tempC - 0.0065 * Elev) / (273.15 + tempC))^5.255, 1)
	    
	    domoticz.devices(Barometer_REL).updateBarometer(pressR)
	end
}
