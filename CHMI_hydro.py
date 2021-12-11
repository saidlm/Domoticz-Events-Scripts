# CHMI Hydro script v 1.0
# River level data grabber; Gets data from CHMI web pages
# Martin Saidl 2021

import urllib.request
import re
import datetime
import DomoticzEvents as domoticz

# Paremeters
chmiUrl = 'https://hydro.chmi.cz/hpps/hpps_prfdyn.php?seq=307237'   # CHMI page
updateInterval = 15                                                 # Update interval in minutes
deviceName = 'Nežárka - Stav'                                       # Device name
# Nezarka - Lasenice
regExp = r'<table [^>]*>\\n<tr >\\n<th.*<\/th>\\n<\/tr>\\n<tr [^>]*>\\n<td [^>]*>([0-9]{2}\.[0-9]{2}\.[0-9]{4} [0-9]{2}:[0-9]{2})<\/td>\\n<td [^>]*>([0-9]*)<\/td>\\n<td [^>]*>([0-9.]*)<\/td>\\n<td [^>]*>([0-9.]*)<\/td>'
# deviceIndex = 99

domoticz.Log("chmi_hydro: Started!")

deviceIndex = domoticz.Devices[deviceName].id 
lastUpdate = datetime.datetime.strptime(domoticz.Devices[deviceName].last_update_string,"%Y-%m-%d %H:%M:%S")
now = datetime.datetime.now()
nextUpdate = lastUpdate + datetime.timedelta(minutes=updateInterval)

if (now > nextUpdate):
    domoticz.Log("chmi_hydro: Updating river level data")

    try:
        domoticz.Log("chmi_hydro: Contacting www.chmi.cz")
        webResponse  = urllib.request.urlopen(chmiUrl)
        webResultCode = webResponse.getcode()
    except URLError as error:
        domoticz.Log("chmi_hydro: Unable to connect to www.chmi.cz")
        domoticz.Log(error)
        exit

    if (webResultCode == 200):
        domoticz.Log("chmi_hydro: Downloading data from www.chmi.cz")
        data = webResponse.read()
        # Extract information from page
        match = re.findall(regExp,str(data))

        if match:
            chmiTime = match[0][0]
            chmiLevel = match[0][1]
            
            domoticz.Log("chmi_hydro: Last measurement at: "+chmiTime)
            domoticz.Log("chmi_hydro: Last value: "+chmiLevel)
            lastMeasurement = datetime.datetime.strptime(match[0][0], "%d.%m.%Y %H:%M")
            if (now - datetime.timedelta(hours=1) < lastMeasurement):
                domoticzUrl = 'http://127.0.0.1:8080/json.htm?type=command&param=udevice&idx='+str(deviceIndex)+'&nvalue=0&svalue='+str(chmiLevel)
                try:
                    domoticz.Log("chmi_hydro: Updating device: "+str(deviceIndex))
                    webResponse  = urllib.request.urlopen(domoticzUrl)
                except URLError as error:
                    domoticz.Log("chmi_hydro: Unable to connect to Domoticz local TCP port")
                    domoticz.Log(error)
                    exit
                domoticz.Log("chmi_hydro: Sucessfuly done!")
            else:
                domoticz.Log("chmi_hydro: Measured data are too old; skipped!")
