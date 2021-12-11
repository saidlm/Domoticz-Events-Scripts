-- WeatherReporter dzVents Script
-- Base on - origanal script from Toulon7559; addapted for dzVents by Henry Joubert
-- Martin Saidl 2021

        local version = '1.1'                   -- current version of script 
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
        -- Configuration for Weatherundeground like servers
        local cfg = {
        -- Weatherwunderground
            {   
                url = 'http://weatherstation.wunderground.com/weatherstation/updateweatherstation.php?',
                id = <PWS ID>,
                pass = <PASSWORD>,
            },
        -- xxxx.xy
            --{
            --    url = "http://xxxx.xy/weatherstation/updateweatherstation.php?",
            --    id = <PWS ID>,
            --    pass = <PASSWORD>,
            --},
        }

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
        
         url = ''
        
        if Outside_Temp_Hum ~= '' and domoticz.devices(Outside_Temp_Hum).lastUpdate.minutesAgo < AliveTime then
           url = url .. "&tempf=" .. string.format("%3.1f", CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).temperature))
           url = url .. "&humidity=" .. domoticz.devices(Outside_Temp_Hum).humidity
           url = url .. "&dewptf=" .. string.format("%3.1f", CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).dewPoint))
           log(domoticz,'Adding Temp&hum to URL:' .. url)
        end
        
        if Barometer ~= '' and domoticz.devices(Barometer).lastUpdate.minutesAgo < AliveTime then
           url = url .. "&baromin=" .. string.format("%2.2f", hPatoInches(domoticz.devices(Barometer).barometer))
           log(domoticz,'Adding Preasure to URL:' .. url)
        end
        
        if RainMeter ~= '' and domoticz.devices(RainMeter).lastUpdate.minutesAgo < AliveTime then
           url = url .. "&dailyrainin=" .. string.format("%2.2f", mmtoInches(domoticz.devices(RainMeter).rain))
           url = url .. "&rainin=" .. string.format("%2.2f", mmtoInches(domoticz.devices(RainMeter).rainRate))
           log(domoticz,'Adding Rain to URL:' .. url)
        end
        
        if WindMeter ~= '' and domoticz.devices(WindMeter).lastUpdate.minutesAgo < AliveTime then
           url = url .. "&winddir=" .. string.format("%.0f", domoticz.devices(WindMeter).direction)
           url = url .. "&windspeedmph=" .. string.format("%.0f", kmhtomph(domoticz.devices(WindMeter).speed))
           url = url .. "&windgustmph=" .. string.format("%.0f", mstomph(domoticz.devices(WindMeter).gust))
           log(domoticz,'Adding Wind to URL:' .. url)
        end
        
        if UVMeter ~= '' and domoticz.devices(UVMeter).lastUpdate.minutesAgo < AliveTime then
            url = url .. "&UV=" .. string.format("%.1f", (domoticz.devices(UVMeter).uv))
            log(domoticz,'Adding UV to URL:' .. url)
        end
        
        if SolarRadiation ~= '' and domoticz.devices(SolarRadiation).lastUpdate.minutesAgo < AliveTime then
            url = url .. "&solarradiation=" .. string.format("%.1f", (domoticz.devices(SolarRadiation).radiation))
            log(domoticz,'Adding Sloars Radiation to URL:' .. url)
        end
        
        url = url .. "&softwaretype=" .. SoftwareType .. "&action=updateraw"
        
        for i, server in ipairs(cfg) do
            serverUrl = server.url .. "ID=" .. server.id .. "&PASSWORD=" .. server.pass .. "&dateutc=" .. timestring
            serverUrl = serverUrl .. url
            log(domoticz,'Sending information to URL:' .. serverUrl)
            domoticz.openURL(serverUrl)
        end
        
        log(domoticz,'Done')
        log(domoticz,'')
	end
}
