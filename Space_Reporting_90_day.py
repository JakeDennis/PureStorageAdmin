from purestorage import purestorage
import sys
import csv
import requests
import time
import os

# Disable certificate warnings

requests.packages.urllib3.disable_warnings()

# Measure script run time

startTime = time.time()

# Set variables

array_IP = "<array_hostname>"
array_api = "<api_token>"

time_stamp = (time.strftime("%m-%d-%y"))
rptFileName = "space-report-" + time_stamp + "-" + array_IP + ".csv"

# Connect to FlashArray

array = purestorage.FlashArray(array_IP, api_token=array_api)
print('Connecting to array.')

# Get all volumes on the FlashArray

allVolumes = array.list_volumes()
print('Gathering all volumes.')

# Create CSV output file

with open(rptFileName, 'w') as csvfile:
    fieldnames = ['Volume_Name', 'Current_Data_Reduction', 'Data_Reduction_90_Days_Ago', 'Current_Size(GB)', 'Size_90_Days_Ago(GB)', '90_Day_Growth(GB)']
    writer = csv.DictWriter(csvfile,fieldnames=fieldnames)
    writer.writeheader()
    print('Parsing volume data.')

    # Loop through all volumes to get historical space data

    for currentVol in allVolumes:
        thisVol = array.get_volume(currentVol['name'], space='True', historical='90d')
        volName = thisVol[0]['name']
        volCurDR = round(thisVol[0]['data_reduction'],2)
        volStartDR = round(thisVol[len(thisVol)-1]['data_reduction'],2)
        volStartSize = round(thisVol[0]['volumes'] / 1000 / 1000 / 1000, 2)
        volCurSize = round(thisVol[len(thisVol)-1]['volumes'] / 1000 / 1000 / 1000, 2)
        volSizeDif = volCurSize - volStartSize
        volSizeDif = round(volSizeDif, 2)
        writer.writerow({'Volume_Name': volName, 'Current_Data_Reduction': volCurDR, 'Data_Reduction_90_Days_Ago': volStartDR, 'Current_Size(GB)': volCurSize, 'Size_90_Days_Ago(GB)': volStartSize, '90_Day_Growth(GB)': volSizeDif})

print('Script completed in ', round(time.time()-startTime,2), ' seconds.')
print('Output file: ', rptFileName, ' located at: ', os.getcwd())

array.invalidate_cookie()
sys.exit()
