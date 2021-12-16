# Domticz-Events-Script
Set of Domoticz Events scripts writen in python or DzVents

## CHMI_hydro 
Python script which is getting data from chmi.cz parsing them to find level of Nezarka river in Lasenice and finaly updating dummy device in Domoticz.
## WeatherReporter
The script is written in DzVents. It is periodicaly updating weather data on weather server / servers base on information store in Domoticz. 
* From version 1.1 it supports multiple WU like servers with update interval 30s. 
* In version 1.2 APRS support has been added. Update interval is set to 5 minutes. It calls external script which allows various ways how to sent APRS updates. The example of script is short bash script aprs_send which is updating WX status via TCP/IP (Internet) using APRS-IS server. 

The plan is to add OWM server, WeatherCloud and other servers.
## WX_cam_helper
It is pure helper script for main shell script. The purpose of it is to periodicaly start shell script which is getting image from WX camera and sending it via ssh tunnel to external server. In fact it can be easily done with cron but I would like to have everythig on one place - in Domoticz
