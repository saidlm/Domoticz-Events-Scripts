-- WeatherReporter dzVents Script
-- Base on - origanal script from Toulon7559; addapted for dzVents by Henry Joubert
-- Martin Saidl 2021

        local version = '1.3'                   -- current version of script 
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
        local wuCfg = {
        -- Weather wunderground
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
    
        -- Configure APRS viz APRS-IS
        local aprsCfg = {
            cmd = '/config/scripts/shell_scripts/aprs_send',
            aprsis = 'czech.aprs2.net',
            port = '14580',
            call = 'OK1XY',
            ssid = '5',
            pass = <PASSKEY>,
            loc = '1234.12N/12345.12E',
            desc = 'GARNI2055/Domoticz'
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
        timer = { 'every minute' },
        customEvents = { 'nextIn30s' },
	    },
	execute = function(domoticz, item)
        
        log(domoticz,'')
        log(domoticz,'WeatherReporter  ver: '.. version)
        
        -- Start the script in every 30s
        if item.isTimer then
            domoticz.emitEvent('nextIn30s', domoticz.time.rawTime ).afterSec(30)
            log(domoticz,'Started as delayed event')
        else
            log(domoticz,'Started by Domoticz -> Setting next start in 30s')
        end
        
    -- Extraction of required calendar info
        utc_dtime = os.date("!%m-%d-%y %H:%M:%S",os.time())
        month = string.sub(utc_dtime, 1, 2)
        day = string.sub(utc_dtime, 4, 5)
        year = "20" .. string.sub(utc_dtime, 7, 8)
        hour = string.sub(utc_dtime, 10, 11)
        minutes = string.sub(utc_dtime, 13, 14)
        seconds = string.sub(utc_dtime, 16, 17)
    
        timestring = year .. "-" .. month .. "-" .. day .. "+" .. hour .. "%3A" .. minutes .. "%3A" .. seconds
        asrsTimestamp = day .. hour .. minutes
    
        SoftwareType="Domoticz"
    
    -- Current date as date.year, date.month, date.day, date.hour, date.min, date.sec
        date = os.date("*t")
        
        url = ''
        aprsMsg = ''
        aprs = {
            windDir = '...', windSpeed = '...', windGust = 'g...', 
            temp = 't...', rainHour = 'r...' , rain24 = 'p...', rainDay = 'P...',
            hum ='h..', press = 'b....'
        }
        wu = {}
        
        if Outside_Temp_Hum ~= '' and domoticz.devices(Outside_Temp_Hum).lastUpdate.minutesAgo < AliveTime then
            temp = CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).temperature)
            hum = domoticz.devices(Outside_Temp_Hum).humidity
            dewp = CelciusToFarenheit(domoticz.devices(Outside_Temp_Hum).dewPoint)
            wu.temp = 'tempf=' .. string.format("%3.1f", temp)
            wu.hum  = 'humidity=' .. hum
            wu.dewp  = 'dewptf=' .. string.format("%3.1f", dewp)
            aprs.temp = 't' .. string.format("%03.0f", temp)
            aprs.hum = 'h' .. string.format("%02.0f", hum)
            log(domoticz,'Adding Temp, hum, dewp: ' .. temp .. ', ' .. temp .. ', ' .. dewp)
        end
        
        if Barometer ~= '' and domoticz.devices(Barometer).lastUpdate.minutesAgo < AliveTime then
            press = domoticz.devices(Barometer).barometer
            wu.press = 'baromin=' ..string.format("%2.2f", hPatoInches(press))
            aprs.press = 'b' .. string.format("%05.0f", press * 10)
            log(domoticz,'Adding Pressure: ' .. press)
        end
        
        if RainMeter ~= '' and domoticz.devices(RainMeter).lastUpdate.minutesAgo < AliveTime then
            rain = mmtoInches(domoticz.devices(RainMeter).rain)
            rainRate = mmtoInches(domoticz.devices(RainMeter).rainRate)
            wu.dailyRainIn = 'dailyrainin=' .. string.format("%2.2f", rain)
            wu.rainIn = 'rainin=' .. string.format("%2.2f", rainRate)
            aprs.rainDay = 'P' .. string.format("%03.0f", rain * 100)
            log(domoticz,'Adding Rain / Rainrate:' .. rain .. '/' .. rainRate)
        end
        
        if WindMeter ~= '' and domoticz.devices(WindMeter).lastUpdate.minutesAgo < AliveTime then
            windDir = domoticz.devices(WindMeter).direction
            windSpeed = kmhtomph(domoticz.devices(WindMeter).speed)
            windGust = mstomph(domoticz.devices(WindMeter).gust)
            wu.windDir = 'winddir=' .. string.format("%.0f", windDir)
            wu.windSpeed = 'windspeedmph=' .. string.format("%.0f", windSpeed)
            wu.windGust = 'windgustmph=' .. string.format("%.0f", windGust)
            aprs.windDir = string.format("%03.0f", windDir)
            aprs.windSpeed = string.format("%03.0f", windSpeed)
            aprs.windGust = 'g' ..string.format("%03.0f", windGust)
            log(domoticz,'Adding Wind: ' .. windDir .. '/' .. windSpeed .. ', ' .. windGust)
        end
        
        if UVMeter ~= '' and domoticz.devices(UVMeter).lastUpdate.minutesAgo < AliveTime then
            uv = domoticz.devices(UVMeter).uv
            wu.uv = 'UV=' .. string.format("%.1f", (uv))
            log(domoticz,'Adding UV: ' .. uv)
        end
        
        if SolarRadiation ~= '' and domoticz.devices(SolarRadiation).lastUpdate.minutesAgo < AliveTime then
            radiation = domoticz.devices(SolarRadiation).radiation
            wu.radiation = 'solarradiation=' .. string.format("%.1f", (radiation))
            if radiation >= 1000 then 
                aprs.radiation = 'l' .. string.format("%04.0f", (radiation))
            else
                aprs.radiation = 'L' .. string.format("%03.0f", (radiation))
            end
            log(domoticz,'Adding Solar Radiation: ' .. radiation)
        end
        
        -- WU like servers reporting
        url = wu.temp .. '&' .. wu.hum .. '&' .. wu.dewp .. '&' .. wu.press .. '&' ..
            wu.rainIn .. '&' .. wu.dailyRainIn .. '&' .. wu.windDir .. '&' ..
            wu.windSpeed .. '&' .. wu.windGust .. '&' ..wu.uv .. '&' .. wu.radiation
            
        url = url .. "&softwaretype=" .. SoftwareType .. "&action=updateraw"
        
        for i, server in ipairs(wuCfg) do
            serverUrl = server.url .. "ID=" .. server.id .. "&PASSWORD=" .. server.pass .. "&dateutc=" .. timestring
            serverUrl = serverUrl .. '&' .. url
            
            log(domoticz,'Sending information to URL:' .. serverUrl)
            
            domoticz.openURL(serverUrl)
        end
        
        -- APRS reporting
        if aprsCfg ~= nil and math.fmod(minutes, 5) == 0 and tonumber(seconds) < 10 then
            aprsMsg = '@' .. asrsTimestamp .. 'z' .. aprsCfg.loc .. '_'
        
            aprsMsg = aprsMsg .. aprs.windDir .. '/' .. aprs.windSpeed .. aprs.windGust ..
                aprs.temp .. aprs.rainHour .. aprs.rain24 .. aprs.rainDay .. aprs.hum .. 
                aprs.press .. aprs.radiation .. aprs.Descr
                
            log(domoticz,'APRS - Sending WX Report: ' .. aprsMsg)
            
            -- ShellScript aprsMsg Call SSID pass IS-server IS-port
            os.execute(aprsCfg.cmd .. ' ' .. aprsMsg .. ' ' .. aprsCfg.call .. ' ' .. 
                aprsCfg.ssid .. ' ' .. aprsCfg.pass .. ' ' .. aprsCfg.aprsis .. ' '  .. aprsCfg.port)
        end
        
        log(domoticz,'Done')
        log(domoticz,'')
	end
}
