# DELL fan control

A simple script for fan Dell Optiplex Computer
with a option to use as a systemd service

inspired by: fan_control.sh script from Jose Manuel Hernandez Farias
             https://github.com/KaltWulx/fan_dell_optiplex
             
## instructions to use the DELL fan control script

- sudo is required!
- the DELL fan control script can run from a terminal
- install as a systemd service is optional

### 1.) run a test to create logfile with pwm & rpm stats:
command:
```
sudo ./dell_fans_test.sh
```

### 2.) open the created logfile to find the state changes.

on my test (FAN1):
```
pwm = rpm  = state
-------------------
30  = 10** = 1
50  = 11** = 2
160 = 15** = 3 
100 = 44** = 4 
```
(FAN2 not tested! i think it use the same states)

i use the follow settings:
case      |CPU temp	|FAN1 pwm   |FAN2 pwm
----------|-----------|-----------|-----------
temp min  |   0-50°C  |   30pwm   |   30pwm
range1    |   50-55°C |   50pwm   |   30pwm
range2    |   55-60°C |   50pwm   |   50pwm
range3    |   60-65°C |   160pwm  |   50pwm
range4    |   65-67°C |   160pwm  |   160pwm
range5    |   67-70°C |   100pwm  |   160pwm
temp max  |   70+°C   |   100pwm  |   100pwm

### 3.) edit the dell_fans.conf file to use your settings:

command:
```
nano ./dell_fans.conf
```

### 4.) test the settings
for test the settings run the script in verbose mode

command:
```
sudo ./dell_fans.sh -V --logoff
```
if no error you can copy files to install the DELL fan control service

### 5.) install: copy the files in the system-folders
commands:
```
sudo cp dell_fans.sh /usr/bin/dell_fans.sh
sudo cp dell_fans.conf /etc/default/dell_fans.conf
sudo cp dell_fans.service /usr/lib/systemd/system/dell_fans.service
```

### 6.) start service
start the dell_fans service:
command:
```
sudo systenctl start dell_fans
```

### 7.) check status of service:
command:
```
sudo systenctl status dell_fans
```

### 8.) if no error - enable service to start at boot:
command:
```
sudo systenctl enable dell_fans
```

## file: fan_control.sh
This file is the original script only with automatically translated texts in German!
It's just a reference file - which is not used in my source!

original source from this file is:
https://github.com/KaltWulx/fan_dell_optiplex

(big thanks to Jose Manuel Hernandez Farias for this great script!)

