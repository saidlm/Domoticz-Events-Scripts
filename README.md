# Domticz-Events-Script
Set of Domoticz Events scrips writen in python or DzVents

## CHMI_hydro 
Python script which is getting data from chmi.cz parsing them to find level of Nezarka river in Lasenice and finaly updating dummy device in Domoticz.
## WeatherReporter
The script is written in DzVents. It is periodicaly updating weather data on weather server / servers base on information store in Domoticz. Currently it works only with WU server. The plan is to add OWN server, WeatherCloud and other servers.
## WX_cam_helper
It is pure helper script for main shell script. The purpose of it is to periodicaly start shell script which is getting image from WX camera and sending it via ssh tunnel to external server. In fact it can be easily done with cron but I would like to have everythig on one place - in Domoticz
