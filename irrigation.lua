-- irrigation dzVents Script
-- Martin Saidl (c) 2023

        local version = '1.0'                   -- current version of script 
        ------------------------------------------------------------------------
        local LOGGING = true                    -- true or false LOGGING info to domoticz log.
        local NOTIFYING = true                  -- true or false to enable or disable notification
        
        -- Source devices
        local Outside_Temp_Hum =    'Venkovní teplota'
        local RainMeter =           'Srážkoměr'
        
        local Switch =              'Zalévání'
        
        -- Destination devices
        local Pump =                'Zalévání - čerpadlo'
        
        -- Constants
        -- Maximum time from last update in minutes
        local AliveTime =           60
        -- Regulation contants in seconds
        local AbsoluteTime =        50
        local TemperatureTime =     80
        local RepeatCycles =        2
        
        -- Notification
        local NotificationMessage = 'Zalévání'


--********
-- FUNCTIONS
--********
        
local function log(domoticz, text, lvlError)
    local lvlLog = domoticz.LOG_INFO
    if lvlError ~= nil and lvlError == true then lvlLog = domoticz.LOG_ERROR end 
    if LOGGING then domoticz.log(text, lvlLog) end 
end     

-- Geting actual rain conditions
local function actualRainConditions(domoticz)
	    
    if RainMeter ~= '' and domoticz.devices(RainMeter).lastUpdate.minutesAgo < AliveTime then
        rainDay = domoticz.devices(RainMeter).rain
        rain = rainDay - domoticz.data.rainLast8
        domoticz.data.rainLast8 = domoticz.data.rainLast4
        domoticz.data.rainLast4 = rainDay
        
        log(domoticz,'Rain in last 8 hours: ' .. rain .. 'mm')
    else
        rain = 0
        domoticz.data.rainLast8 = 0
        domoticz.data.rainLast4 = 0
        log(domoticz,'Rain value is unknown, setting value to 0 mm')
    end
    return rain
end	    

-- Getting actual temperature conditions
local function actualTemperatureConditions(domoticz)
    
    if Outside_Temp_Hum ~= '' and domoticz.devices(Outside_Temp_Hum).lastUpdate.minutesAgo < AliveTime then
        temp = domoticz.devices(Outside_Temp_Hum).temperature
    else
        temp = 22
        log(domoticz,'Temperature is unknown, setting value to 22 °C')
    end
    
    if temp <= 20 then
        iTemp = 0
    elseif temp > 20 and temp < 35 then
        iTemp = (temp - 20)/15
    else
        iTemp = 1
    end
        
    log(domoticz,'Temperature: ' .. temp .. '°C; Temperature index: ' .. iTemp)
    return iTemp
end

--********
-- Main Loop
--********
return {
	logging = {
        marker = "irrigation"
  },
	on = {
        timer = { 
            'at 8:00',
            'at 12:00',
            'at 16:00',
            'at 20:00',
        },
	},
	data = {
        rainLast4 = { initial = 0 },
        rainLast8 = { initial = 0 }
  },
	execute = function(domoticz, item)
	
	    if item.isTimer and (domoticz.devices(Switch).state == 'On') then
            local now = domoticz.time.hour
            log(domoticz,'Actual time hour is: ' .. now)
            if now == 8 then
                domoticz.data.rainLast4 = 0
                domoticz.data.rainLast8 = 0
                booster = 2
            elseif now == 20 then
                booster = 1.5
            else
                booster = 1
            end
            
            rain = actualRainConditions(domoticz)
            iTemp = actualTemperatureConditions(domoticz)    
        
            -- Counting "pump on" interval 
            if rain <= 0.2 then
                interval = (AbsoluteTime + iTemp * TemperatureTime) * booster
                domoticz.devices(Pump).switchOn().forSec(interval).repeatAfterSec(15, RepeatCycles)
                --domoticz.devices(Pump).switchOn().forSec(interval)
                log(domoticz,'Pump is ON for: ' .. RepeatCycles .. ' interval(s) of ' .. interval .. 'seconds.')
                if NOTIFYING then
                    domoticz.notify(NotificationMessage)
                end
            else
                log(domoticz,'Pump has not been switched on.')
            end
        end
	end
}
