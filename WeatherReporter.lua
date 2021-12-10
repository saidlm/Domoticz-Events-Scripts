-- WeatherReporter dzVents Script
-- Base on - origanal script from Toulon7559; addapted for dzVents by Henry Joubert
-- Martin Saidl 2021

        local version = '1.0'                   -- current version of script 
        ------------------------------------------------------------------------
        local LOGGING = false                   -- true or false LOGGING info to domoticz log.
        
        -- Source devices
        local Outside_Temp_Hum = 'Venkovní teplota'
        local Barometer = 'Barometr'
        local RainMeter = 'Srážkoměr'
        local WindMeter = 'Anemometr'
        local UVMeter = 'UV Index'
        local SolarRadiation = 'Sluneční záření'
        -- Maximum time from last update in minutes
        local AliveTime = 60

        -- Servers Settings
        local baseurl = "http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?"
        local ID = <PWS ID>
        local PASSWORD = <PASSWORD>


--********
-- FUNCTIONS
--********

local function CelciusToFarenheit(C)
   return (C * (9/5)) + 32
end

local function hPatoInches(hpa)
   return hpa * 0.0295301
end

local function mmtoInches(mm)
   return mm * 0.039370
end

local function mstomph(ms)
   return ms * 2.236936
end

local function kmhtomph(kmh)
   return kmh * 0.621371
end

local function log(domoticz, text, lvlError)
    local lvlLog = domoticz.LOG_INFO
    if lvlError ~= nil and lvlError == true then lvlLog = domoticz.LOG_ERROR end 
    if LOGGING then domoticz.log(text, lvlLog) end 
end     

return {
	logging = {
        --level = domoticz.LOG_ERROR,
        marker = "WeatherReporter"
    },
	on = {
        timer = { 'every minute' }
	    },
	execute = function(domoticz)
        log(domoticz,'')
        log(domoticz,'WeatherReporter  ver: '.. version)
    -- Extraction of required calendar info
        utc_dtime = os.date("!%m-%d-%y %H:%M:%S",os.time())
        month = string.sub(utc_dtime, 1, 2)
        day = string.sub(utc_dtime, 4, 5)
        year = "20" .. string.sub(utc_dtime, 7, 8)
        hour = string.sub(utc_dtime, 10, 11)
        minutes = string.sub(utc_dtime, 13, 14)
        seconds = string.sub(utc_dtime, 16, 17)
    
        timestring = year .. "-" .. month .. "-" .. day .. "+" .. hour .. "%3A" .. minutes .. "%3A" .. seconds
    
        SoftwareType="Domoticz"
    
    -- Current date as date.year, date.month, date.day, date.hour, date.min, date.sec
        date = os.date("*t")
        WU_URL= baseurl .. "ID=" .. ID .. "&PASSWORD=" .. PASSWORD .. "&dateutc=" .. timestring
    
        if Outside_Temp_Hum ~= '' and domoticz.devices(Outside_Temp_Hum).lastUpdate.minutesAgo < AliveTime then
           WU_URL = WU_URL .. "&tempf=" .. string.format("%3.1f", CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).temperature))
           WU_URL = WU_URL .. "&humidity=" .. domoticz.devices(Outside_Temp_Hum).humidity
           WU_URL = WU_URL .. "&dewptf=" .. string.format("%3.1f", CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).dewPoint))
           log(domoticz,'WeatherReporter - Addin Temp&hum to URL:' .. WU_URL)
        end
        
        if Barometer ~= '' and domoticz.devices(Barometer).lastUpdate.minutesAgo < AliveTime then
           WU_URL = WU_URL .. "&baromin=" .. string.format("%2.2f", hPatoInches(domoticz.devices(Barometer).barometer))
           log(domoticz,'WeatherReporter - Adding Preasure to URL:' .. WU_URL)
        end
        
        if RainMeter ~= '' and domoticz.devices(RainMeter).lastUpdate.minutesAgo < AliveTime then
           WU_URL = WU_URL .. "&dailyrainin=" .. string.format("%2.2f", mmtoInches(domoticz.devices(RainMeter).rain))
           WU_URL = WU_URL .. "&rainin=" .. string.format("%2.2f", mmtoInches(domoticz.devices(RainMeter).rainRate))
           log(domoticz,'WeatherReporter - Adding Rain to URL:' .. WU_URL)
        end
        
        if WindMeter ~= '' and domoticz.devices(WindMeter).lastUpdate.minutesAgo < AliveTime then
           WU_URL = WU_URL .. "&winddir=" .. string.format("%.0f", domoticz.devices(WindMeter).direction)
           WU_URL = WU_URL .. "&windspeedmph=" .. string.format("%.0f", kmhtomph(domoticz.devices(WindMeter).speed))
           WU_URL = WU_URL .. "&windgustmph=" .. string.format("%.0f", mstomph(domoticz.devices(WindMeter).gust))
           log(domoticz,'WeatherReporter - Adding Wind to URL:' .. WU_URL)
        end
        
        if UVMeter ~= '' and domoticz.devices(UVMeter).lastUpdate.minutesAgo < AliveTime then
            WU_URL = WU_URL .. "&UV=" .. string.format("%.1f", (domoticz.devices(UVMeter).uv))
            log(domoticz,'WeatherReporter - Adding UV to URL:' .. WU_URL)
        end
        
        if SolarRadiation ~= '' and domoticz.devices(SolarRadiation).lastUpdate.minutesAgo < AliveTime then
            WU_URL = WU_URL .. "&solarradiation=" .. string.format("%.1f", (domoticz.devices(SolarRadiation).radiation))
            log(domoticz,'WeatherReporter - Adding Sloars Radiation to URL:' .. WU_URL)
        end
        
        WU_URL = WU_URL .. "&softwaretype=" .. SoftwareType .. "&action=updateraw"
        
        log(domoticz,'WeatherReporter - Sending information to URL:' .. WU_URL)
        domoticz.openURL(WU_URL)
        log(domoticz,'WetherReporter - Done')

	end
}
