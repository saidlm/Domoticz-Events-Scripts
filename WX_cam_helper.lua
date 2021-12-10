-- WX Camera helper dzVents Script
-- Martin Saidl 2021

        local version = '1.0'                   -- current version of script 
        ------------------------------------------------------------------------
        local LOGGING = false                   -- true or false LOGGING info to domoticz log.
        local shellScript = '/config/scripts/shell_scripts/wxcam/bin/wxcam.sh'
    
    
local function log(domoticz, text, lvlError)
    local lvlLog = domoticz.LOG_INFO
    if lvlError ~= nil and lvlError == true then lvlLog = domoticz.LOG_ERROR end 
    if LOGGING then domoticz.log(text, lvlLog) end
end


return {
    logging = {
    -- level = domoticz.LOG_ERROR,
        marker = "WX_Camera_helper"
    },
	on = {
        timer = { 'every 5 minutes' } -- or can be change to 'every minute'
	},
	execute = function(domoticz)
	    log(domoticz,'')
	    log(domoticz,'WX_Camera_helper ver: ' .. version)
        log(domoticz,'Executing shell command: ' .. shellScript)
        
        local fileHandle = assert(io.popen(shellScript, 'r'))
        local commandOutput = assert(fileHandle:read('*a'))
        local returnTable = {fileHandle:close()}
        
        log(domoticz, "Return Code: " .. returnTable[3])
        log(domoticz, "Command Output: " .. commandOutput)
        
        log(domoticz,'Done')
    end
}
