-- WeatherReporter dzVents Script
-- Base on - origanal script from Toulon7559; addapted for dzVents by Henry Joubert
-- Martin Saidl 2021

        local version = '1.7'                   -- current version of script 
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
                software = 'Domoticz'
            },
        -- Pocasi Meteo
            {
                url = 'http://ms.pocasimeteo.cz/weatherstation/updateweatherstation.php?',
                id = <PWS ID>,
                pass = <PASSWORD>,
                software = 'Domoticz'
            },
        }
        
        -- Configuration for Open Weather Map (OWM)
        local owmCfg = {
            appid = <APPID,
            pwsid = <STATION ID>,
        } 

         -- Configuration for WeatherCloud
        local wcCfg = {
            wid = <ID>,
            key = <KEY>,
        }

        -- Configuration of APRS via APRS-IS
        local aprsCfg = {
            cmd = '/config/scripts/shell_scripts/aprs_send',
            aprsis = 'czech.aprs2.net',
            port = '14580',
            call = 'OK1XY',
            ssid = '5',
            pass = <PASSKEY>,
            loc = '1234.12N/12345.12E',
            descr = 'GARNI2055/Domoticz'
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

local function positiveonly(num)
    if num > 0 then
        return num
    else 
        return 0
    end
end

local function log(domoticz, text, lvlError)
    local lvlLog = domoticz.LOG_INFO
    if lvlError ~= nil and lvlError == true then lvlLog = domoticz.LOG_ERROR end 
    if LOGGING then domoticz.log(text, lvlLog) end 
end     

return {
	logging = {
        marker = "WeatherReporter"
    },
	on = {
        timer = { 'every minute' },
        devices = { WindMeter, RainMeter },
        httpResponses = { 'owmResponse', 'wuResponse', 'wcResponse' },
        customEvents = { 'nextIn30s' },
	    },
    data = {
        rainLast = { initial = 0 },
        rainWindow = { history = true, maxItems = 3000, maxHours = 25 },
        windGustWindow = { history = true, maxItems = 40, maxMinutes = 10 },
        rainRateWindow = { history = true, maxItems = 40, maxMinutes = 10 },
        },
	execute = function(domoticz, item)
        
        log(domoticz,'')
        log(domoticz,'WeatherReporter  ver: '.. version)
        
        -- Start the script in every 30s
        if item.isTimer then
            log(domoticz,'Started as delayed event')
            domoticz.emitEvent('nextIn30s', domoticz.time.rawTime ).afterSec(30)
        -- HTTP Response handler
        elseif item.isHTTPResponse then
            log(domoticz,'Trigered by HTTP Response')        
            log(domoticz,item.data)
            return
        -- Devices handler
        elseif item.isDevice then
            log(domoticz,'Trigered by device activity')
            if item == domoticz.devices(WindMeter) then
                log(domoticz,'Adding new wind gust value to window: ' .. domoticz.devices(WindMeter).gustMs)
                domoticz.data.windGustWindow.add(domoticz.devices(WindMeter).gustMs)
            elseif item == domoticz.devices(RainMeter) then
                log(domoticz,'Adding new rain rate value to window: ' .. domoticz.devices(RainMeter).rainRate)
                domoticz.data.rainRateWindow.add(domoticz.devices(RainMeter).rainRate)
            end
            return
        -- Reporting
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
        unixEpoch = os.time(os.date("!*t"))
    
        timestring = year .. "-" .. month .. "-" .. day .. "+" .. hour .. "%3A" .. minutes .. "%3A" .. seconds
        asrsTimestamp = day .. hour .. minutes
    
        wu = {}
        owm = {}
        wc = {}
        aprsMsg = ''
        aprs = {
            windDir = '...', windSpeed = '...', windGust = 'g...', 
            temp = 't...', rainHour = 'r...' , rain24 = 'p...', rainDay = 'P...',
            hum ='h..', press = 'b....'
        }
        
        if Outside_Temp_Hum ~= '' and domoticz.devices(Outside_Temp_Hum).lastUpdate.minutesAgo < AliveTime then
            tempC = domoticz.devices(Outside_Temp_Hum).temperature
            tempF = CelciusToFarenheit(tempC)
            hum = domoticz.devices(Outside_Temp_Hum).humidity
            dewpC = domoticz.devices(Outside_Temp_Hum).dewPoint
            dewpF = CelciusToFarenheit(dewpC)
            wu.temp = 'tempf=' .. string.format("%3.1f", tempF)
            wu.hum  = 'humidity=' .. string.format("%2.0f", hum)
            wu.dewp  = 'dewptf=' .. string.format("%3.1f", dewpF)
            owm.temperature = tonumber(string.format("%3.1f", tempC))
            owm.humidity =  tonumber(string.format("%2.0f",hum))
            owm.dew_point = tonumber(string.format("%3.1f",dewpC))
            wc.temp = 'temp/' .. string.format("%.0f", (tempC * 10))
            wc.hum = 'hum/' .. string.format("%.0f", hum)
            wc.dewp = 'dew/' ..string.format("%.0f", (dewpC * 10))
            aprs.temp = 't' .. string.format("%03.0f", tempF)
            aprs.hum = 'h' .. string.format("%02.0f", hum)
            log(domoticz,'Adding Temp, hum, dewp: ' .. tempC .. ', ' .. hum .. ', ' .. dewpC)
        end
        
        if Barometer ~= '' and domoticz.devices(Barometer).lastUpdate.minutesAgo < AliveTime then
            press = domoticz.devices(Barometer).barometer
            wu.press = 'baromin=' ..string.format("%2.2f", hPatoInches(press))
            owm.pressure = tonumber(string.format("%4.1f", press))
            wc.press = 'bar/' .. string.format("%.0f", (press * 10))
            aprs.press = 'b' .. string.format("%05.0f", press * 10)
            log(domoticz,'Adding Pressure: ' .. press)
        end
        
        if RainMeter ~= '' and domoticz.devices(RainMeter).lastUpdate.minutesAgo < AliveTime then
            rainDayMm = domoticz.devices(RainMeter).rain
            rainRateMm = domoticz.data.rainRateWindow.maxSince('00:00:30')
            rainRateMm10 = domoticz.data.rainRateWindow.maxSince('00:10:00')
            if rainRateMm == nil then
                rainRateMm = 0
            end
            if rainRateMm10 == nil then
                rainRateMm10 = 0
            end
            rainDay = mmtoInches(rainDayMm)
            rainRate = mmtoInches(rainRateMm)
            rainDelta = rainDay - domoticz.data.rainLast
            if rainDelta >= 0 then
                domoticz.data.rainWindow.add(rainDelta)
            end
            domoticz.data.rainLast = rainDay
            rainHour = positiveonly(domoticz.data.rainWindow.sumSince('01:00:00'))
            rain6 = positiveonly(domoticz.data.rainWindow.sumSince('06:00:00'))
            rain24 = positiveonly(domoticz.data.rainWindow.sumSince('24:00:00'))
            wu.dailyRainIn = 'dailyrainin=' .. string.format("%2.2f", rainDay)
            wu.rainIn = 'rainin=' .. string.format("%2.2f", rainRate)
            owm.rain_1h = tonumber(string.format("%3.0f",  rainHour))
            owm.rain_6h = tonumber(string.format("%3.0f",  rain6))
            owm.rain_24h = tonumber(string.format("%3.0f",  rain24))
            wc.rain = 'rain/' .. string.format("%.0f", (rainDayMm * 10))
            wc.rainRate = 'rainrate/' .. string.format("%.0f", (rainRateMm10 * 10))
            aprs.rainHour = 'r' .. string.format("%03.0f",  rainHour * 100)
            aprs.rain24 = 'p' .. string.format("%03.0f",  rain24 * 100)
            aprs.rainDay = 'P' .. string.format("%03.0f", rainDay * 100)
            log(domoticz,'Adding Rain / Rainrate:' .. rainDay .. '/' .. rainRate)
        end
        
        if WindMeter ~= '' and domoticz.devices(WindMeter).lastUpdate.minutesAgo < AliveTime then
            windDir = domoticz.devices(WindMeter).direction
            windSpeedM = domoticz.devices(WindMeter).speedMs
            windGustM = domoticz.data.windGustWindow.maxSince('00:00:30')
            windGustM5 = domoticz.data.windGustWindow.maxSince('00:05:00')
            windGustM10 = domoticz.data.windGustWindow.maxSince('00:10:00')
            if windGustM == nil then
                windGustM = 0 
            end
            if windGustM5 == nil then
                windGustM5 = 0
            end
            if windGustM10 == nil then
                windGustM10 = 0
            end
            windSpeedMph = mstomph(windSpeedM)
            windGustMph = mstomph(windGustM)
            windGustMph5 = mstomph(windGustM5)
            wu.windDir = 'winddir=' .. string.format("%.0f", windDir)
            wu.windSpeed = 'windspeedmph=' .. string.format("%.0f", windSpeedMph)
            wu.windGust = 'windgustmph=' .. string.format("%.0f", windGustMph)
            owm.wind_deg = tonumber(string.format("%.0f", windDir))                 
            owm.wind_speed = tonumber(string.format("%.1f", windSpeedM))
            owm.wind_gust = tonumber(string.format("%.1f", windGustM5))
            wc.wdir = 'wdir/' .. string.format("%.0f", windDir)
            wc.wspd = 'wspd/' .. string.format("%.0f", (windSpeedM * 10))
            wc.wspdhi = 'wspdhi/' .. string.format("%.0f", (windGustM10 * 10))
            aprs.windDir = string.format("%03.0f", windDir)
            aprs.windSpeed = string.format("%03.0f", windSpeedMph)
            aprs.windGust = 'g' ..string.format("%03.0f", windGustMph5)
            log(domoticz,'Adding Wind: ' .. windDir .. '/' .. windSpeedMph .. ', ' .. windGustMph .. ' [' .. windGustMph5 .. ']' )
        end
        
        if UVMeter ~= '' and domoticz.devices(UVMeter).lastUpdate.minutesAgo < AliveTime then
            uv = domoticz.devices(UVMeter).uv
            wu.uv = 'UV=' .. string.format("%.1f", uv)
            wc.uv = 'uvi/' .. string.format("%.0f", (uv * 10))
            log(domoticz,'Adding UV: ' .. uv)
        end
        
        if SolarRadiation ~= '' and domoticz.devices(SolarRadiation).lastUpdate.minutesAgo < AliveTime then
            radiation = domoticz.devices(SolarRadiation).radiation
            wu.radiation = 'solarradiation=' .. string.format("%.1f", radiation)
            wc.radiation = 'solarrad/' .. string.format("%.0f", (radiation * 10))
            if radiation >= 1000 then 
                aprs.radiation = 'l' .. string.format("%04.0f", (radiation))
            else
                aprs.radiation = 'L' .. string.format("%03.0f", (radiation))
            end
            log(domoticz,'Adding Solar Radiation: ' .. radiation)
        end
        
        -- WU like servers reporting
        if wuCfg ~= nil then
            url = ''
            for var, val in pairs(wu) do
                url = url ..'&' .. val
            end
        
            for i, server in pairs(wuCfg) do
                url = url .. '&softwaretype=' .. server.software .. '&action=updateraw'
                serverUrl = server.url .. 'ID=' .. server.id .. '&PASSWORD=' .. server.pass .. '&dateutc=' .. timestring
                serverUrl = serverUrl .. url
            
                log(domoticz,'Sending information to URL:' .. serverUrl)    
            
                domoticz.openURL({
                    url =  serverUrl,
                    method = 'GET',
                    callback = 'wuResponse'
                    })
            end
        end
        
        -- OWM reporting (every 5 minutes)
        if owmCfg ~= nil and math.fmod(minutes, 5) == 0 and tonumber(seconds) < 10 then
            owm.station_id = owmCfg.pwsid
            owm.dt = unixEpoch
            data = domoticz.utils.toJSON(owm)
            url = 'http://api.openweathermap.org/data/3.0/measurements?appid=' .. owmCfg.appid
            
            log(domoticz, 'OWM JSON: ' .. data)
            log(domoticz, 'OWM URL: ' .. url)
            
            domoticz.openURL({
                url = url,
                method = 'POST',
                postData = '[' .. data .. ']',
                headers = { ['Content-Type'] = 'application/json' },
                callback = 'owmResponse'
            })
        end
        
        -- WC reporting (every 10 minutes - mimimum interval value)
        if wcCfg ~= nil and math.fmod(minutes, 10) == 0 and tonumber(seconds) < 10 then
            url = ''
            for var, val in pairs(wc) do
                url = url ..'/' .. val
            end
                
            serverUrl = 'http://api.weathercloud.net/set/wid/' .. wcCfg.wid .. '/key/' .. wcCfg.key .. url .. '/ver/1.2/type/201'
            
            log(domoticz,'Sending information to URL:' .. serverUrl)
            
            domoticz.openURL({
                url =  serverUrl,
                method = 'GET',
                callback = 'wcResponse'
                })
            
        end 
        
        -- APRS reporting (every 5 minutes)
        if aprsCfg ~= nil and math.fmod(minutes, 5) == 0 and tonumber(seconds) < 10 then
            aprsMsg = '@' .. asrsTimestamp .. 'z' .. aprsCfg.loc .. '_'
        
            aprsMsg = aprsMsg .. aprs.windDir .. '/' .. aprs.windSpeed .. aprs.windGust ..
                aprs.temp .. aprs.rainHour .. aprs.rain24 .. aprs.rainDay .. aprs.hum .. 
                aprs.press .. aprs.radiation .. aprsCfg.descr
                
            log(domoticz,'APRS - Sending WX Report: ' .. aprsMsg)
            
            -- ShellScript $1=aprsMsg $2=Call $3=SSID $4=pass $5=IS-server $6=IS-port
            domoticz.executeShellCommand({
                command = aprsCfg.cmd .. ' ' .. aprsMsg .. ' ' .. aprsCfg.call .. ' ' .. 
                aprsCfg.ssid .. ' ' .. aprsCfg.pass .. ' ' .. aprsCfg.aprsis .. ' '  .. aprsCfg.port,
                timeout = 60
                })
        end
        
        log(domoticz,'Done')
        log(domoticz,'')
	end
}
