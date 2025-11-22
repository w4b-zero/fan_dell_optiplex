#!/bin/bash
##################################################################################
#  File:        dell_fans.sh                                                     #
#  Description: A simple script for fan Dell Optiplex Computer                   #
#  Source:      https://github.com/w4b-zero/fan_dell_optiplex                    #
#  Author:      Werner Kallas (zero™)                                            #
#  Email:       w4b.zero@googlemail.com                                          #
#                                                                                #
#  tested on:   DELL Optiplex 7020                                               #
#               OS:Fedora 42                                                     #
#                                                                                #
#  inspired by: fan_control.sh from Jose Manuel Hernandez Farias                 #
#               https://github.com/KaltWulx/fan_dell_optiplex                    #
##################################################################################
##                                                                              ##
##  This program is free software; you can redistribute it and/or modify        ##
##  it under the terms of the GNU General Public License as published by        ##
##  the Free Software Foundation; either version 2 of the License, or           ##
##  (at your option) any later version.                                         ##
##                                                                              ##
##  This program is distributed in the hope that it will be useful,             ##
##  but WITHOUT ANY WARRANTY; without even the implied warranty of              ##
##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                        ##
##  See the GNU General Public License for more details.                        ##
##                                                                              ##
##  You should have received a copy of the GNU General Public License along     ##
##  with this program; if not, write to the Free Software Foundation, Inc.,     ##
##  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.                    ##
##                                                                              ##
##################################################################################

#########################################################
### programm variables
#########################################################
# NAME
	prg_name="DELL fan control"
# SCRIPTNAME
	script_name="dell_fans.sh"
# SCRIPTDESCRIPTION
	script_desc="A simple script for fan Dell Optiplex Computer"
# SCRIPT_LICENSE
	script_license="GNU General Public License v2"
# OTHER SCRIPT FILES
	script_files_other_1="dell_fans.conf (settings file)"
	script_files_other_2="dell_fans.service (to run dell_fans.sh as service)"
	script_files_other_3="dell_fans.log (logfile from dell_fans.sh)"
	script_files_other_4="dell_fans_test.sh (for create system test log)"
	script_files_other_5="dell_fans_test-[date-time].log (logfile from dell_fans_test.sh)"
# SCRIPTHOME (github repository)
	script_home="w4b-zero/dell_fan_control"
# TESTED ON HARDWARE
	script_tested_hw_1="Dell Optiplex 7020"
	#script_tested_hw_2=""
	#script_tested_hw_3=""
	#script_tested_hw_4=""
	#script_tested_hw_5=""
# TESTED ON LINUX DESTRIBUTION
	script_tested_os_1="Linux: Fedora 42"
	#script_tested_os_2=""
	#script_tested_os_3=""
	#script_tested_os_4=""
	#script_tested_os_5=""
# OTHER INFOS
	inspired_by="fan_control.sh from Jose Manuel Hernandez Farias"
	inspired_link="https://github.com/KaltWulx/fan_dell_optiplex"
# VERSION
	script_version="v1.0.0"
# AUTHOR
	script_author="Werner Kallas (zero™)"
# AUTHOREMAIL
	script_author_email="w4b.zero@googlemail.com"
# AUTHORHOME
	script_author_home="https://github.com/w4b-zero"


#########################################################
### script variables
#########################################################

# text colors
##################################################
#CSI="\033["					# Control Sequence Introducer
CSI="$(printf '\033')["    # Control Sequence Introducer
black_text="${CSI}30m"		# Black
red_text="${CSI}31m"			# Red
green_text="${CSI}32m"		# Green
yellow_text="${CSI}33m"		# Yellow
blue_text="${CSI}34m"		# Blue
magenta_text="${CSI}35m"		# Magenta
cyan_text="${CSI}36m"		# Cyan
white_text="${CSI}37m"		# White
b_black_text="${CSI}90m"		# Bright Black
b_red_text="${CSI}91m"		# Bright Red
b_green_text="${CSI}92m"		# Bright Green
b_yellow_text="${CSI}93m"	# Bright Yellow
b_blue_text="${CSI}94m"		# Bright Blue
b_magenta_text="${CSI}95m"	# Bright Magenta
b_cyan_text="${CSI}96m"		# Bright Cyan
b_white_text="${CSI}97m"		# Bright White
reset_text="${CSI}0m"		# Reset to default
clear_line="${CSI}0K"		# Clear the current line to the right to wipe any artifacts remaining from last print

# text styles
##################################################
bold_text="${CSI}1m"
blinking_text="${CSI}5m"
dim_text="${CSI}2m"

#########################################################
### check sudo permissions
#########################################################
if [[ "$EUID" = 0 ]]; then
    echo -e "${green_text}start with sudo permissions${reset_text}"
else
	echo -e "${red_text}start without sudo permissions - run script with sudo!${reset_text}"
    exit 1
fi

# log settings for systemd
##################################################
# used for output an log writing
# output: Nov 21 10:39:16 zero-pc $LOG_TAG.....
LOG_TAG="dell_fans"

# define internal vars
GET_CPU_TEMP_FILE=""
SET_FAN_SPEED_FILE=""

# working directory
SCRIPT_PATH=$(pwd)

#########################################################
### cli vars
#########################################################

# verbose mode
##################################################
# run script in verbose mode (start script with '-V' or '--verbose')
# shows verbose messages in output and logfile
# verbose mode also shows debug messages
# '-d' or '--debug' parameters are not required 
VERBOSE_MODE=false

# debug mode
##################################################
# run script in debug mode (start script with '-D' or '--debug')
# shows debug messages in output and logfile
DEBUG_MODE=false

# silent mode
##################################################
# run script in silent mode (start script with '-s' or '--silent')
# disable all message output in terminal
# no function in daemon mode, because daemon mode does not output messages
SILENT_MODE=false

# no color on log
##################################################
# use '--no_log_color' or '--nlc' parameter to disable colors on log
NO_LOG_COLOR=false # default: use colors on log

# disable all logging
##################################################
# use '--no_log' parameter to disable logging
NO_LOG=false # default: logging is active 

# daemon mode
##################################################
# run script as systemd service (start script with '-d' or '--daemon')
# write no output on terminal
# use systemd logging and not the LOGFILE (only if --use_logfile not set!) 
DAEMON_MODE=false # default: running as script
# use logfile instead of systemd logging (start script with '-d --use_logfile' or '--daemon -use_logfile')
# only on DEAMON_MODE=1 
USE_LOGFILE=false # default: use systemd logging when running as service

# logfile
##################################################
# logfile ('logfile.log' or '/path/to/logfile')
# custom logfile can used with '--logfile=/path/to/logfile.log' parameter
# if use a custom logfile and if a space in path or filename use '--logfile="/path with spaces/to/log file.log"'  
if [ "$DAEMON_MODE" = false ]; then
	# used when script NOT running as service
	LOGFILE="${SCRIPT_PATH}/dell_fans.log" # default: write file dell_fans.log in the directory who start the script
fi
if [ "$DAEMON_MODE" = true ] && [ "$USE_LOGFILE" = true ]; then
	# used when script running as service with '--use_logfile' parameter
	LOGFILE="/var/log/dell_fans.log" # default: write file dell_fans.log in the system log directory (/var/log/)
fi

# interval to check cpu temp and set fans
##################################################
# custom interval can set from commandline with '-p=1' or '--checkpause=1' parameter
# instead the interval in the settings file
CUSTOM_CHECK_PAUSE=0 # default: using CHECK_PAUSE from settings file if not set

# settings file
##################################################
# custom settings file can set from commandline with '--settings_file=/path/to/settings.conf' parameter
# if use a custom settings file and if a space in path or filename use '--settings_file="/path with spaces/to/settings file.conf"'  
if [ "$DAEMON_MODE" = false ]; then
	# used when script NOT running as service
	SETTINGS_FILE="${SCRIPT_PATH}/dell_fans.conf" # default: use settings file 'dell_fans.conf' in the directory who start the script
fi
if [ "$DAEMON_MODE" = true ]; then
	# used when script running as service
	SETTINGS_FILE="/etc/default/dell_fans.conf" # default: use settings file 'dell_fans.conf' in the system config directory (/etc/default/)
fi


loadSettingsFile() {
# check existence of settings file
# if not exist create settings file with default settings
if [ ! -f "$SETTINGS_FILE" ] || [ ! -r "$SETTINGS_FILE" ]; then
    tM_msg="${red_text}settings file${reset_text} (${b_cyan_text}$SETTINGS_FILE${reset_text}) ${red_text}does not exist or is not readable.${reset_text}"
    tM_log="settings file ($SETTINGS_FILE) does not exist or is not readable."
	tModeDebug "1" "${tM_msg}" "${tM_log}"
    tM_msg="${b_yellow_text}create settings file${reset_text} (${cyan_text}$SETTINGS_FILE${reset_text}) ${b_yellow_text}with default settings${reset_text}"
    tM_log="create default settings file ($SETTINGS_FILE)"
	tModeDebug "2" "${tM_msg}" "${tM_log}"
	echo "##################################################################################" > $SETTINGS_FILE
	echo "#  File:        ${script_name}                                                   #" >> $SETTINGS_FILE
	echo "#  Description: config settings for ${script_name}                               #" >> $SETTINGS_FILE
	echo "#  Source:      https://github.com/${script_home}                    #" >> $SETTINGS_FILE
	echo "#  Author:      ${script_author}                                            #" >> $SETTINGS_FILE
	echo "#  Email:       ${script_author_email}                                          #" >> $SETTINGS_FILE
	echo "#                                                                                #" >> $SETTINGS_FILE
	echo "#  tested HW:   ${script_tested_hw_1}                                               #" >> $SETTINGS_FILE
	echo "#  tested OS:   ${script_tested_os_1}                                                 #" >> $SETTINGS_FILE
	echo "#                                                                                #" >> $SETTINGS_FILE
	echo "#  inspired by: ${inspired_by}                 #" >> $SETTINGS_FILE
	echo "#               ${inspired_link}                    #" >> $SETTINGS_FILE
	echo "##################################################################################" >> $SETTINGS_FILE
	echo "##                                                                              ##" >> $SETTINGS_FILE
	echo "##  This program is free software; you can redistribute it and/or modify        ##" >> $SETTINGS_FILE
	echo "##  it under the terms of the GNU General Public License as published by        ##" >> $SETTINGS_FILE
	echo "##  the Free Software Foundation; either version 2 of the License, or           ##" >> $SETTINGS_FILE
	echo "##  (at your option) any later version.                                         ##" >> $SETTINGS_FILE
	echo "##                                                                              ##" >> $SETTINGS_FILE
	echo "##  This program is distributed in the hope that it will be useful,             ##" >> $SETTINGS_FILE
	echo "##  but WITHOUT ANY WARRANTY; without even the implied warranty of              ##" >> $SETTINGS_FILE
	echo "##  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                        ##" >> $SETTINGS_FILE
	echo "##  See the GNU General Public License for more details.                        ##" >> $SETTINGS_FILE
	echo "##                                                                              ##" >> $SETTINGS_FILE
	echo "##  You should have received a copy of the GNU General Public License along     ##" >> $SETTINGS_FILE
	echo "##  with this program; if not, write to the Free Software Foundation, Inc.,     ##" >> $SETTINGS_FILE
	echo "##  59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.                    ##" >> $SETTINGS_FILE
	echo "##                                                                              ##" >> $SETTINGS_FILE
	echo "##################################################################################" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# check and set fan rpm all x seconds" >> $SETTINGS_FILE
	echo "CHECK_PAUSE=1" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp min (all temps under ...)" >> $SETTINGS_FILE
	echo "TEMP_MIN=50" >> $SETTINGS_FILE
	echo "FAN1_PWM_MIN=30" >> $SETTINGS_FILE
	echo "FAN2_PWM_MIN=30" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp range 1 (first custom range)" >> $SETTINGS_FILE
	echo "TEMP_RANGE1_START=50" >> $SETTINGS_FILE
	echo "TEMP_RANGE1_END=55" >> $SETTINGS_FILE
	echo "FAN1_PWM_RANGE1=50" >> $SETTINGS_FILE
	echo "FAN2_PWM_RANGE1=30" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp range 2 (second custom range)" >> $SETTINGS_FILE
	echo "TEMP_RANGE2_START=55" >> $SETTINGS_FILE
	echo "TEMP_RANGE2_END=60" >> $SETTINGS_FILE
	echo "FAN1_PWM_RANGE2=50" >> $SETTINGS_FILE
	echo "FAN2_PWM_RANGE2=50" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp range 3 (third custom range)" >> $SETTINGS_FILE
	echo "TEMP_RANGE3_START=60" >> $SETTINGS_FILE
	echo "TEMP_RANGE3_END=65" >> $SETTINGS_FILE
	echo "FAN1_PWM_RANGE3=160" >> $SETTINGS_FILE
	echo "FAN2_PWM_RANGE3=50" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp range 4 (fourth custom range)" >> $SETTINGS_FILE
	echo "TEMP_RANGE4_START=65" >> $SETTINGS_FILE
	echo "TEMP_RANGE4_END=67" >> $SETTINGS_FILE
	echo "FAN1_PWM_RANGE4=160" >> $SETTINGS_FILE
	echo "FAN2_PWM_RANGE4=160" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp range 5 (fifth custom range)" >> $SETTINGS_FILE
	echo "TEMP_RANGE5_START=67" >> $SETTINGS_FILE
	echo "TEMP_RANGE5_END=70" >> $SETTINGS_FILE
	echo "FAN1_PWM_RANGE5=100" >> $SETTINGS_FILE
	echo "FAN2_PWM_RANGE5=160" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	echo "# temp max (all temps over ...)" >> $SETTINGS_FILE
	echo "TEMP_MAX=70" >> $SETTINGS_FILE
	echo "FAN1_PWM_MAX=100" >> $SETTINGS_FILE
	echo "FAN2_PWM_MAX=100" >> $SETTINGS_FILE
	echo "" >> $SETTINGS_FILE
	# check if settings file write susseful
	if [ ! -f "$SETTINGS_FILE" ] || [ ! -r "$SETTINGS_FILE" ]; then
		tM_msg="${red_text}write error:${reset_text} (${cyan_text}$SETTINGS_FILE${reset_text}) ${red_text}not created!${reset_text}"
		tM_log="settings file ($SETTINGS_FILE) write failed!"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
		tM_msg="${red_text}please check write permissions!${reset_text}"
		tM_log="please check write permissions!"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
		exit 1
	else
		tM_msg="${b_yellow_text}create settings file${reset_text} (${cyan_text}$SETTINGS_FILE${reset_text}) ${b_green_text}successful${reset_text}"
	    tM_log="settings file ($SETTINGS_FILE) successful created"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
	fi
fi
# load settings file
source $SETTINGS_FILE
tM_msg="${b_yellow_text}load settings file${reset_text} (${b_cyan_text}$SETTINGS_FILE${reset_text}) ${b_green_text}successful${reset_text}"
tM_log="load settings file ($SETTINGS_FILE) successful"
tModeDebug "2" "${tM_msg}" "${tM_log}"
}

checkLogfileFile() {
# check existence of logfile
	#dtstart=$(date +"%d-%b-%Y %T")
	dtstart=$(date +"%b %d %T")
	# if not exist create logfile
	if [ ! -f "$LOGFILE" ] || [ ! -r "$LOGFILE" ]; then
	    tM_msg="${b_yellow_text}logfile${reset_text} (${cyan_text}$LOGFILE${reset_text}) ${b_yellow_text}not exist. create the logfile${reset_text}"
	    tM_log="logfile ($LOGFILE) not exist. create the logfile"
		if [ "$DEBUG_MODE" = true ] || [ "$VERBOSE_MODE" = true ]; then
			#show only if m_silent off 
			if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}"
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}"
			fi
			#log
			if [ "$NO_LOG_COLOR" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}" > $LOGFILE
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}" > $LOGFILE
			else
				#echo -e "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" > $LOGFILE
				echo "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" > $LOGFILE
			fi
		fi
		# check if logfile write susseful
		if [ ! -f "$LOGFILE" ] || [ ! -r "$LOGFILE" ]; then
			tM_msg="${red_text}write error:${reset_text} (${cyan_text}$LOGFILE${reset_text}) ${red_text}not created!${reset_text}"
			#show only if m_silent off 
			if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${red_text}ERROR${reset_text}]: ${tM_msg}"
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${red_text}ERROR${reset_text}]: ${tM_msg}"
			fi
			tM_msg="${red_text}please check write permissions!${reset_text}"
			#show only if m_silent off 
			if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${red_text}ERROR${reset_text}]: ${tM_msg}"
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${red_text}ERROR${reset_text}]: ${tM_msg}"
			fi
			exit 1
		else
			tM_msg="${b_yellow_text}create logfile${reset_text} (${cyan_text}$LOGFILE${reset_text}) ${b_green_text}successful${reset_text}"
			tM_log="logfile ($LOGFILE) successful created"
			if [ "$DEBUG_MODE" = true ] || [ "$VERBOSE_MODE" = true ]; then
				#show only if m_silent off 
				if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}"
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}"
				fi
				#log
				if [ "$NO_LOG_COLOR" = false ]; then
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}" >> $LOGFILE
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}" >> $LOGFILE
				else
					#echo -e "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" >> $LOGFILE
					echo "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" >> $LOGFILE
				fi
			fi
		fi
	else
		tM_msg="${b_yellow_text}logfile${reset_text} (${cyan_text}$LOGFILE${reset_text}) ${b_green_text}found${reset_text}"
		tM_log="logfile ($LOGFILE) found"
		if [ "$DEBUG_MODE" = true ] || [ "$VERBOSE_MODE" = true ]; then
			#show only if m_silent off 
			if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}"
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}"
			fi
			#log
			if [ "$NO_LOG_COLOR" = false ]; then
				#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${b_yellow_text}DEBUG${reset_text}]: ${tM_msg}" >> $LOGFILE
				echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} [${yellow_text}DEBUG${reset_text}]: ${tM_msg}" >> $LOGFILE
			else
				#echo -e "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" >> $LOGFILE
				echo "${dtstart} ${LOG_TAG} [DEBUG]: ${tM_log}" >> $LOGFILE
			fi
		fi
	fi
}

preLoadKernelModule() {
# remove kernel module for reloading 
	tM_msg="${b_yellow_text}remove kernel module (modprobe -r dell_smm_hwmon)${reset_text}"
	tM_log="remove kernel module (modprobe -r dell_smm_hwmon)"
	tModeDebug "2" "${tM_msg}" "${tM_log}"
	modprobe -r dell_smm_hwmon 2>/dev/null || true
sleep 2

# reload kernel module with parameter
	tM_msg="${b_yellow_text}load kernel module (modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1)${reset_text}"
	tM_log="load kernel module (modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1)"
	tModeDebug "2" "${tM_msg}" "${tM_log}"
	modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1 2>/dev/null || true
sleep 3
}

# check and resolve devices paths in /sys/devices/platform/
resolve_paths() {
    # activate nullglob
    shopt -s nullglob

    temp_candidates=(/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
    if (( ${#temp_candidates[@]} == 0 )); then
		tM_msg="${red_text}/temp1_input in coretemp hwmon not found (search: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)${reset_text}"
		tM_log="/temp1_input in coretemp hwmon not found (search: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    GET_CPU_TEMP_FILE="${temp_candidates[0]}"

    # Verify that dell_smm_hwmon is available and functional
    pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
    fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
    pwm_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm2)
    fan_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan2_input)
    
	#FAN1
    if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
		tM_msg="${b_yellow_text}FAN1: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0${reset_text}"
		tM_log="FAN1: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        
        # show kernel module status
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
			tM_msg="${b_yellow_text}FAN1: latest news from the module: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')${reset_text}"
			tM_log="FAN1: latest news from the module: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
        fi
        
        preLoadKernelModule
        
        # check again after reloading the kernel module.
        pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
        fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
        
        if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
			tM_msg="${red_text}FAN1: EC/BIOS has blocked access to the fan controller.${reset_text}"
			tM_log="FAN1: EC/BIOS has blocked access to the fan controller."
			tModeDebug "1" "${tM_msg}" "${tM_log}"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
				tM_msg="${red_text}FAN1: only temperature sensors available. to regain PWM control: shut down and turn on again! (no reboot)${reset_text}"
				tM_log="FAN1: only temperature sensors available. to regain PWM control: shut down and turn on again! (no reboot)"
				tModeDebug "1" "${tM_msg}" "${tM_log}"
            fi
            SET_FAN_SPEED_FILE=""
            GET_FAN_RPM_FILE=""
        else
            SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
            GET_FAN_RPM_FILE="${fan_candidates[0]}"
			tM_msg="${b_yellow_text}FAN1: PWM control restored after 'modprobe'${reset_text}"
			tM_log="FAN1: PWM control restored after 'modprobe'"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
        fi
    elif (( ${#pwm_candidates[@]} > 0 )); then
        SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
        GET_FAN_RPM_FILE="${fan_candidates[0]}"
		tM_msg="${b_yellow_text}FAN1: PWM control available from the start${reset_text}"
		tM_log="FAN1: PWM control available from the start"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${b_yellow_text}FAN1: dell_smm_hwmon only partially functional - read-only available${reset_text}"
		tM_log="FAN1: dell_smm_hwmon only partially functional - read-only available"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        SET_FAN_SPEED_FILE=""
		GET_FAN_RPM_FILE=""
    fi

	#FAN2
    if (( ${#pwm_candidates2[@]} == 0 )) && (( ${#fan_candidates2[@]} == 0 )); then
		tM_msg="${red_text}FAN2: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0${reset_text}"
		tM_log="FAN2: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        
        # Aktuellen Modulstatus anzeigen
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
			tM_msg="${b_yellow_text}FAN2: latest news from the module:${reset_text} ${cyan_text}$(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')${reset_text}"
			tM_log="FAN2: latest news from the module: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
        fi
        preLoadKernelModule
        
        # check again after reloading the kernel module.
        pwm_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm2)
        fan_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan2_input)
        
        if (( ${#pwm_candidates2[@]} == 0 )) && (( ${#fan_candidates2[@]} == 0 )); then
			tM_msg="${red_text}FAN2: EC/BIOS has blocked access to the fan controller.${reset_text}"
			tM_log="FAN2: EC/BIOS has blocked access to the fan controller."
			tModeDebug "1" "${tM_msg}" "${tM_log}"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
				tM_msg="${red_text}FAN2: only temperature sensors available. to regain PWM control: shut down and turn on again! (no reboot)${reset_text}"
				tM_log="FAN2: only temperature sensors available. to regain PWM control: shut down and turn on again! (no reboot)"
				tModeDebug "1" "${tM_msg}" "${tM_log}"
            fi
            SET_FAN_SPEED_FILE2=""
            GET_FAN_RPM_FILE2=""
        else
            SET_FAN_SPEED_FILE2="${pwm_candidates2[0]}"
            GET_FAN_RPM_FILE2="${fan_candidates2[0]}"
			tM_msg="${b_yellow_text}FAN2: PWM control restored after 'modprobe'${reset_text}"
			tM_log="FAN2: PWM control restored after 'modprobe'"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
        fi
    elif (( ${#pwm_candidates2[@]} > 0 )); then
        SET_FAN_SPEED_FILE2="${pwm_candidates2[0]}"
        GET_FAN_RPM_FILE2="${fan_candidates2[0]}"
		tM_msg="${b_yellow_text}FAN2: PWM control available from the start${reset_text}"
		tM_log="FAN2: PWM control available from the start"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${red_text}FAN2: dell_smm_hwmon only partially functional - read-only available${reset_text}"
		tM_log="FAN2: dell_smm_hwmon only partially functional - read-only available"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        SET_FAN_SPEED_FILE2=""
		GET_FAN_RPM_FILE2=""
    fi

    # restore default behavior
    shopt -u nullglob

	tM_msg="${b_yellow_text}CPU temperature file:${reset_text} ${cyan_text}$GET_CPU_TEMP_FILE${reset_text}"
	tM_log="CPU temperature file: $GET_CPU_TEMP_FILE"
	tModeDebug "2" "${tM_msg}" "${tM_log}"
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ -n "$SET_FAN_SPEED_FILE2" ]]; then
		tM_msg="${b_yellow_text}FAN1 PWM file:${reset_text} ${cyan_text}$SET_FAN_SPEED_FILE${reset_text}"
		tM_log="FAN1 PWM file: $SET_FAN_SPEED_FILE"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
		tM_msg="${b_yellow_text}FAN2 PWM file:${reset_text} ${cyan_text}$SET_FAN_SPEED_FILE2${reset_text}"
		tM_log="FAN2 PWM file: $SET_FAN_SPEED_FILE2"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${red_text}audit-only mode: No PWM control (EC/BIOS access blocked)${reset_text}"
		tM_log="audit-only mode: No PWM control (EC/BIOS access blocked)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
    fi

}

# variable for storing the previous PWM signal
previous_pwm=$MIN_PWM
previous_temp=0

# systemd-compatible logging feature
log_message() {
    # use the logger only to avoid distorting the output with replaced commands.
#    logger -t "$LOG_TAG" "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    logger -t "$LOG_TAG" "$1"
    #echo "$(date '+%b %d %T') $LOG_TAG $1" | ccze -A --plugin=syslog | tee -a dell_fans.log
}

# Function for calculating temperature-dependent PWM with thermal protection
calculate_pwm() {
    local temp=$1
    local temp_diff=$2
    local pwm
    
    # critical protection: at a temperature of >= 80°C, immediate maximum
    if (( temp >= CRITICAL_TEMP )); then
		tM_msg="${red_text}critical: critical Temperature ${temp}°C, maximum PWM${reset_text}"
		tM_log="critical: critical Temperature ${temp}°C, maximum PWM"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        echo $MAX_PWM
        return
    fi
    
    # predictive protection: aggressive PWM adjustment in the event of rapid temperature rise (>3°C).
    if (( temp_diff > TEMP_RISE_THRESHOLD )); then
        # calculating aggressive PWM: assuming that the temperature will continue to rise
        local predicted_temp=$((temp + temp_diff * 2))  # predicts temperature in the next 2 cycles
        if (( predicted_temp > MAX_TEMP )); then
            predicted_temp=$MAX_TEMP
        fi
        pwm=$(( (predicted_temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
        if (( pwm > MAX_PWM )); then pwm=$MAX_PWM; fi
		tM_msg="${red_text}predictions: rapid increase +${temp_diff}°C, aggressive PWM: ${pwm}${reset_text}"
		tM_log="predictions: rapid increase +${temp_diff}°C, aggressive PWM: ${pwm}"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        echo $pwm
        return
    fi
    
    # normal mapping for gradual changes
    if (( temp <= MIN_TEMP )); then
        pwm=$MIN_PWM
    elif (( temp >= MAX_TEMP )); then
        pwm=$MAX_PWM
    else
        # smooth linear mapping between MIN_TEMP and MAX_TEMP
        pwm=$(( (temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
    fi
    
    echo $pwm
}

# function to check hardware files
check_hardware_files() {
    if [[ ! -r $GET_CPU_TEMP_FILE ]]; then
		tM_msg="${red_text}temperature file could not be read: $GET_CPU_TEMP_FILE${reset_text}"
		tM_log="temperature file could not be read: $GET_CPU_TEMP_FILE"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    
    # check PWM only if available
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ ! -w $SET_FAN_SPEED_FILE ]] && [[ $EUID -ne 0 ]]; then
		tM_msg="${red_text}failed to write PWM file: $SET_FAN_SPEED_FILE (run as root)${reset_text}"
		tM_log="failed to write PWM file: $SET_FAN_SPEED_FILE (run as root)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    if [[ -n "$SET_FAN_SPEED_FILE2" ]] && [[ ! -w $SET_FAN_SPEED_FILE2 ]] && [[ $EUID -ne 0 ]]; then
		tM_msg="${red_text}failed to write PWM file: $SET_FAN_SPEED_FILE2 (run as root)${reset_text}"
		tM_log="failed to write PWM file: $SET_FAN_SPEED_FILE2 (run as root)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
		exit 1
	fi
}

# output cleaning function
cleanup() {
	tM_msg="\n${red_text}stop signal received, fan back to automatic mode${reset_text}"
	tM_log="\nstop signal received, fan back to automatic mode"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    # optional: put the fan back into automatic mode
    exit 0
}

# function to diagnose the status of the dell_smm_hwmon
diagnose_dell_hwmon() {
		tM_msg="${b_yellow_text}===== dell_smm_hwmon DIAG =====${reset_text}"
		tM_log="===== dell_smm_hwmon DIAG ====="
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    
    # check if the module is loaded
    if lsmod | grep -q dell_smm_hwmon; then
		tM_msg="${green_text}dell_smm_hwmon module loaded${reset_text}"
		tM_log="dell_smm_hwmon module loaded"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${b_yellow_text}dell_smm_hwmon module NOT loaded${reset_text}"
		tM_log="dell_smm_hwmon module NOT loaded"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        return
    fi
    
    # check available files
    if [[ -d "/sys/devices/platform/dell_smm_hwmon/hwmon" ]]; then
        local hwmon_dir=$(find /sys/devices/platform/dell_smm_hwmon/hwmon/* -name "hwmon*" -type d | head -1)
        if [[ -n "$hwmon_dir" ]]; then
            local available_files=$(ls "$hwmon_dir" 2>/dev/null | grep -E "temp2|fan|pwm" | tr '\n' ' ')
			tM_msg="${b_yellow_text}available files:${reset_text} ${cyan_text}$available_files${reset_text}"
			tM_log="available files: $available_files"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
            
            # Überprüfen Sie insbesondere PWM und Lüfter
            if ls "$hwmon_dir"/pwm* >/dev/null 2>&1; then
				tM_msg="${b_yellow_text}PWM files found${reset_text} ${b_white_text}-${reset_text} ${green_text}control available${reset_text}"
			tM_log="PWM files found - control available"
				tModeDebug "2" "${tM_msg}" "${tM_log}"
            elif ls "$hwmon_dir"/fan* >/dev/null 2>&1; then
				tM_msg="${b_yellow_text}fan files only${reset_text} ${b_white_text}-${reset_text} ${red_text}no PWM control${reset_text}"
			tM_log="fan files only - no PWM control"
				tModeDebug "2" "${tM_msg}" "${tM_log}"
            else
			tM_msg="${b_yellow_text}temperature sensors only${reset_text} ${b_white_text}-${reset_text} ${red_text}EC blocked fans${reset_text}"
			tM_log="temperature sensors only - EC blocked fans"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
            fi
        fi
    else
			tM_msg="${red_text}directory dell_smm_hwmon not found${reset_text}"
			tM_log="directory dell_smm_hwmon not found"
			tModeDebug "1" "${tM_msg}" "${tM_log}"
    fi
    
			tM_msg="${b_yellow_text}========= END OF DIAG =========${reset_text}"
			tM_log="========= END OF DIAG ========="
			tModeDebug "2" "${tM_msg}" "${tM_log}"
}

runLoop() {
while true; do
    # read current temperature in milli-celsius and calculate them in celsius.
    current_cpu_temp=$(($(cat "$GET_CPU_TEMP_FILE") / 1000))
    current_rpm_speed=$(($(cat "$GET_FAN_RPM_FILE")))
    current_rpm_speed2=$(($(cat "$GET_FAN_RPM_FILE2")))

    # calculate the temperature difference from the last reading
    temp_diff=$((current_cpu_temp - previous_temp))
    if [ "$temp_diff" = "$current_cpu_temp" ]; then
		temp_diff=0
    fi
    if (( temp_diff < 0 )); then temp_diff=0; fi  # Solo nos interesan las subidas
    
#pwm = rpm  = state
#30  = 10** = 1
#50  = 11** = 2
#160 = 15** = 3 
#200 = 16** = 4 
#100 = 44** = 5 

#x-50	= fan1:30pwm		fan2:30pwm     
#50-55	= fan1:50pwm		fan2:30pwm     
#55-60	= fan1:50pwm		fan2:50pwm     
#60-65	= fan1:160pwm	fan2:50pwm     
#65-67	= fan1:160pwm	fan2:160pwm     
#67-70	= fan1:100pwm	fan2:160pwm     
#70+		= fan1:100pwm	fan2:100pwm     

min_cpu_temp=$((${TEMP_MIN} +1))
range1_temp_min=$((${TEMP_RANGE1_START} -1))
range1_temp_max=$((${TEMP_RANGE1_END} +1))

range2_temp_min=$((${TEMP_RANGE2_START} -1))
range2_temp_max=$((${TEMP_RANGE2_END} +1))

range3_temp_min=$((${TEMP_RANGE3_START} -1))
range3_temp_max=$((${TEMP_RANGE3_END} +1))

range4_temp_min=$((${TEMP_RANGE4_START} -1))
range4_temp_max=$((${TEMP_RANGE4_END} +1))

range5_temp_min=$((${TEMP_RANGE5_START} -1))
range5_temp_max=$((${TEMP_RANGE5_END} +1))

	if [ "$current_cpu_temp" -lt ${min_cpu_temp} ];then
		fan1_target_pwm=${FAN1_PWM_MIN}
		fan2_target_pwm=${FAN2_PWM_MIN}
		t_color="${blue_text}"
		t_color1="${blue_text}"
	elif [ "$current_cpu_temp" -gt ${range1_temp_min} ] && [ "$current_cpu_temp" -lt ${range1_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE1}
		fan2_target_pwm=${FAN2_PWM_RANGE1}
		t_color="${green_text}"
		t_color1="${green_text}"
	elif [ "$current_cpu_temp" -gt ${range2_temp_min} ] && [ "$current_cpu_temp" -lt ${range2_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE2}
		fan2_target_pwm=${FAN2_PWM_RANGE2}
		t_color="${b_yellow_text}"
		t_color1="${yellow_text}"
	elif [ "$current_cpu_temp" -gt ${range3_temp_min} ] && [ "$current_cpu_temp" -lt ${range3_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE3}
		fan2_target_pwm=${FAN2_PWM_RANGE3}
		t_color="${yellow_text}${bold_text}"
		t_color1="${magenta_text}"
	elif [ "$current_cpu_temp" -gt ${range4_temp_min} ] && [ "$current_cpu_temp" -lt ${range4_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE4}
		fan2_target_pwm=${FAN2_PWM_RANGE4}
		t_color="${magenta_text}${bold_text}"
		t_color1="${b_magenta_text}"
	elif [ "$current_cpu_temp" -gt ${range5_temp_min} ] && [ "$current_cpu_temp" -lt ${range5_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE5}
		fan2_target_pwm=${FAN2_PWM_RANGE5}
		t_color="${b_red_text}${bold_text}"
		t_color1="${magenta_text}"
	else
		fan1_target_pwm=${FAN1_PWM_MAX}
		fan2_target_pwm=${FAN2_PWM_MAX}
		t_color="${red_text}"
		t_color1="${red_text}"
	fi

	# set pwm to fans
	if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
		echo "$fan1_target_pwm" > "$SET_FAN_SPEED_FILE"
	fi
	if [[ -n "$SET_FAN_SPEED_FILE2" ]]; then
		echo "$fan1_target_pwm" > "$SET_FAN_SPEED_FILE2"
	fi

	# write info message 
	if [ "$fan2_target_pwm" -lt 100 ]; then
		fan2_pwm_set=" ${fan2_target_pwm}"
	else
		fan2_pwm_set="${fan2_target_pwm}"
	fi	
	if [ "$fan1_target_pwm" -lt 100 ]; then
		fan1_pwm_set=" ${fan1_target_pwm}"
	else
		fan1_pwm_set="${fan1_target_pwm}"
	fi	
	cpu_text_msg="${white_text}CPU_Temp:${reset_text} $t_color${current_cpu_temp}${reset_text}$t_color1°C${reset_text} ${cyan_text}(Δ+${temp_diff}°C)${reset_text}"
	fan1_text_msg="${white_text}CPU_FAN:${reset_text} ${b_cyan_text}${fan1_pwm_set}pwm${reset_text}/${b_cyan_text}${current_rpm_speed}rpm${reset_text}"
	fan2_text_msg="${white_text}CASE_FAN:${reset_text} ${b_cyan_text}${fan2_pwm_set}pwm${reset_text}/${b_cyan_text}${current_rpm_speed2}rpm${reset_text}"
	tM_msg="${cpu_text_msg} ${fan1_text_msg} ${fan2_text_msg}"
	tM_log="CPU_Temp: ${current_cpu_temp}°C (Δ+${temp_diff}°C) FAN1: ${fan1_pwm_set}pwm/${current_rpm_speed}rpm FAN2: ${fan2_pwm_set}pwm/${current_rpm_speed2}rpm"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

    previous_temp=$current_cpu_temp

    sleep ${CHECK_PAUSE}
done
}

tModeDebug() {
    local msgId
    local msgText
    local logText
    local dtstart
	msgId=$1
	msgText=$2
	logText=$3

	if [ "$msgId" = "1" ]; then #error
		msgTyp="[${red_text}ERROR${reset_text}]"
		logTyp="[ERROR]"
	elif [ "$msgId" = "2" ]; then #debug
		msgTyp="[${yellow_text}DEBUG${reset_text}]"
		logTyp="[DEBUG]"
	elif [ "$msgId" = "3" ]; then #verbose
		msgTyp="[${cyan_text}VERBOSE${reset_text}]"
		logTyp="[VERBOSE]"
	else #info
		msgTyp="[${green_text}INFO${reset_text}]"
		logTyp="[INFO]"
	fi

	#dtstart=$(date +"%d-%b-%Y %T")
	dtstart=$(date +"%b %d %T")

	# verbose messages
	if [ "$msgId" = "3" ] && [ "$VERBOSE_MODE" = true ]; then
#echo "v_testpoint0"
		#show only if m_silent off 
		if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
#echo "v_testpoint1"
	    		#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
	    		echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ "$NO_LOG" = false ]; then
#echo "v_testpoint2"
			if [ "$DAEMON_MODE" = false ]; then
#echo "v_testpoint3"
				if [ "$NO_LOG_COLOR" = false ]; then
#echo "v_testpoint4"
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
				else
#echo "v_testpoint5"
					#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
				fi
			fi
			if [ "$DAEMON_MODE" = true ]; then
#echo "v_testpoint6"
				if [ "$USE_LOGFILE" = true ]; then
#echo "v_testpoint7"
					if [ "$NO_LOG_COLOR" = false ]; then
#echo "v_testpoint8"
						#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
						echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					else
#echo "v_testpoint9"
						#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					fi
				else
#echo "v_testpoint10"
					if [ "$NO_LOG_COLOR" = false ]; then
#echo "v_testpoint11"
						log_message "${msgTyp}: ${msgText}"
					else
#echo "v_testpoint12"
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
	
	# debug messages
	if [ "$msgId" = "2" ] && { [ "$DEBUG_MODE" = true ] || [ "$VERBOSE_MODE" = true ]; }; then
#echo "d_testpoint0"
		#show only if m_silent off 
		if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
#echo "d_testpoint1"
			#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
			echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
	    fi
		#log
		if [ "$NO_LOG" = false ]; then
#echo "d_testpoint2"
			if [ "$DAEMON_MODE" = false ]; then
#echo "d_testpoint3"
				if [ "$NO_LOG_COLOR" = false ]; then
#echo "d_testpoint4"
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
				else
#echo "d_testpoint5"
					#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
				fi
			fi
			if [ "$DAEMON_MODE" = true ]; then 
#echo "d_testpoint6"
				if [ "$USE_LOGFILE" = true ]; then
#echo "d_testpoint7"
					if [ "$NO_LOG_COLOR" = false ]; then
#echo "d_testpoint8"
						#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
						echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					else
#echo "d_testpoint9"
						#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					fi
				else
#echo "d_testpoint10"
					if [ "$NO_LOG_COLOR" = false ]; then
#echo "d_testpoint11"
						log_message "${msgTyp}: ${msgText}"
					else
#echo "d_testpoint12"
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
	
	# error messages
	if [ "$msgId" = "1" ]; then
		#show only if m_silent off 
		if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
			#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
			echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ "$NO_LOG" = false ]; then
			if [ "$DAEMON_MODE" = false ]; then
				if [ "$NO_LOG_COLOR" = false ]; then
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
				else
					#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
				fi
			fi
			if [ "$DAEMON_MODE" = true ]; then 
				if [ "$USE_LOGFILE" = true ]; then
					if [ "$NO_LOG_COLOR" = false ]; then
						#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
						echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					else
						#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					fi
				else
					if [ "$NO_LOG_COLOR" = false ]; then
						log_message "${msgTyp}: ${msgText}"
					else
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
	
	# info messages
	if [ "$msgId" = "0" ]; then
		#show only if m_silent off 
		if [ "$SILENT_MODE" = false ] && [ "$DAEMON_MODE" = false ]; then
			#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
			echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ "$NO_LOG" = false ]; then
			if [ "$DAEMON_MODE" = false ]; then
				if [ "$NO_LOG_COLOR" = false ]; then
					#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
				else
					#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
				fi
			fi
			if [ "$DAEMON_MODE" = true ]; then 
				if [ "$USE_LOGFILE" = true ]; then
					if [ "$NO_LOG_COLOR" = false ]; then
						#echo -e "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
						echo "${cyan_text}${dtstart}${reset_text} ${blue_text}${LOG_TAG}${reset_text} ${msgTyp}: ${msgText}" >> $LOGFILE
					else
						#echo -e "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> $LOGFILE
					fi
				else
					if [ "$NO_LOG_COLOR" = false ]; then
						log_message "${msgTyp}: ${msgText}"
					else
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
}

ShowVersion() {
#    ############################################################"
#    ###############  DELL fan control  (v1.0.0)  ###############"
#    ############################################################"
#    #  Desc.:  A simple script for fan Dell Optiplex Computer  #"
#    #  Github: w4b-zero/dell_fan_control                       #"
#    #  Author: Werner Kallas (zero™)                           #"
#    #  Email:  w4b.zero@googlemail.com                         #"
#    #                                                          #"
#    #  inspired by:                                            #"
#    #        fan_control.sh from Jose Manuel Hernandez Farias  #"
#    #        https://github.com/KaltWulx/fan_dell_optiplex     #"
#    ############################################################"

# scriptname and version
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}###############${reset_text}  ${b_green_text}${prg_name}${reset_text}  ${b_white_text}(${script_version})${reset_text}  ${blue_text}###############${reset_text}"
    tM_log="###############  ${prg_name}  (${script_version})  ###############"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}  ${cyan_text}Desc.:${reset_text}  ${b_cyan_text}${script_desc}${reset_text}  ${blue_text}#${reset_text}"
    tM_log="#  Desc.:  ${script_desc}  #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}  ${cyan_text}Github:${reset_text} ${b_cyan_text}${script_home}${reset_text}                       ${blue_text}#${reset_text}"
    tM_log="#  Github: ${script_home}                      #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}  ${cyan_text}Author:${reset_text} ${b_cyan_text}${script_author}${reset_text}                           ${blue_text}#${reset_text}"
    tM_log="#  Author: ${script_author}                           #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}  ${cyan_text}Email:${reset_text}  ${b_cyan_text}${script_author_email}${reset_text}                         ${blue_text}#${reset_text}"
    tM_log="#  Email:  ${script_author_email}                         #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}                                                          ${blue_text}#${reset_text}"
    tM_log="#                                                          #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}  ${cyan_text}inspired by:${reset_text}                                            ${blue_text}#${reset_text}"
    tM_log="#  inspired by:                                            #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}        ${b_cyan_text}${inspired_by}${reset_text}  ${blue_text}#${reset_text}"
    tM_log="#        ${inspired_by}  #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}        ${b_cyan_text}${inspired_link}${reset_text}     ${blue_text}#${reset_text}"
    tM_log="#        ${inspired_link}     #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    exit 0
}

Showstart() {
#    ############################################################"
#    ###############  DELL fan control  (v1.0.0)  ###############"
#    ############################################################"
#    #      A simple script for fan Dell Optiplex Computer      #"
#    ############################################################"

# scriptname and version (short)
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}###############${reset_text}  ${b_green_text}${prg_name}${reset_text}  ${b_white_text}(${script_version})${reset_text}  ${blue_text}###############${reset_text}"
    tM_log="###############  ${prg_name}  (${script_version})  ###############"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}#${reset_text}      ${b_cyan_text}${script_desc}${reset_text}      ${blue_text}#${reset_text}"
    tM_log="#      ${script_desc}      #"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}############################################################${reset_text}"
    tM_log="############################################################"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

	# debug: used settings header
    tM_msg="${b_yellow_text}======== USED SETTINGS ========${reset_text}"
    tM_log="======== USED SETTINGS ========"
	tModeDebug "2" "${tM_msg}"
	
	# debug: VERBOSE_MODE
	if [ "$VERBOSE_MODE" = true ]; then
		tM_msg="${b_yellow_text}VERBOSE_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="VERBOSE_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}VERBOSE_MODE:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="VERBOSE_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: DEBUG_MODE
	if [ "$DEBUG_MODE" = true ]; then
		tM_msg="${b_yellow_text}DEBUG_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="DEBUG_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}DEBUG_MODE:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="DEBUG_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: SILENT_MODE
	if [ "$SILENT_MODE" = true ]; then
		tM_msg="${b_yellow_text}SILENT_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="SILENT_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}SILENT_MODE:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="SILENT_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: NO_LOG_COLOR
	if [ "$NO_LOG_COLOR" = true ]; then
		tM_msg="${b_yellow_text}NO_LOG_COLOR:${reset_text} ${green_text}true${reset_text}"
		tM_log="NO_LOG_COLOR: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}NO_LOG_COLOR:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="NO_LOG_COLOR: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: NO_LOG
	if [ "$NO_LOG" = true ]; then
		tM_msg="${b_yellow_text}NO_LOG:${reset_text} ${green_text}true${reset_text}"
		tM_log="NO_LOG: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}NO_LOG:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="NO_LOG: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: DAEMON_MODE
	if [ "$DAEMON_MODE" = true ]; then
		tM_msg="${b_yellow_text}DAEMON_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="DAEMON_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}DAEMON_MODE:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="DAEMON_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: USE_LOGFILE
	if [ "$USE_LOGFILE" = true ]; then
		tM_msg="${b_yellow_text}USE_LOGFILE:${reset_text} ${green_text}true${reset_text}"
		tM_log="USE_LOGFILE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}USE_LOGFILE:${reset_text} ${b_white_text}false${reset_text}"
		tM_log="USE_LOGFILE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: CUSTOM_CHECK_PAUSE
	if [ ! "$CUSTOM_CHECK_PAUSE" = 0 ]; then
		tM_msg="${b_yellow_text}CUSTOM_CHECK_PAUSE:${reset_text} ${green_text}${CUSTOM_CHECK_PAUSE}${reset_text}"
		tM_log="CUSTOM_CHECK_PAUSE: ${CUSTOM_CHECK_PAUSE}"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}CUSTOM_CHECK_PAUSE:${reset_text} ${b_white_text}0${reset_text}"
		tM_log="CUSTOM_CHECK_PAUSE: 0"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: LOGFILE
    tM_msg="${b_yellow_text}LOGFILE:${reset_text} ${b_cyan_text}${LOGFILE}${reset_text}"
    tM_log="LOGFILE: ${LOGFILE}"
	tModeDebug "2" "${tM_msg}"
	
	# debug: SETTINGS_FILE
    tM_msg="${b_yellow_text}SETTINGS_FILE:${reset_text} ${b_cyan_text}${SETTINGS_FILE}${reset_text}"
    tM_log="SETTINGS_FILE: ${SETTINGS_FILE}"
	tModeDebug "2" "${tM_msg}"

	# debug: CHECK_PAUSE
    tM_msg="${b_yellow_text}CHECK_PAUSE: ${reset_text} ${b_cyan_text}${CHECK_PAUSE}${reset_text}"
    tM_log="CHECK_PAUSE: ${CHECK_PAUSE}"
	tModeDebug "2" "${tM_msg}"

	# debug: range settings 
    tM_msg="${b_yellow_text}temp range${reset_text} ${white_text}|${reset_text} ${b_yellow_text}fan1 pwm${reset_text} ${white_text}|${reset_text} ${b_yellow_text}fan2 pwm ${reset_text}"
    tM_log="temp_range | fan1 rpm | fan2 rmp"
	tModeDebug "2" "${tM_msg}"
    tM_msg="${white_text}-----------|----------|----------${reset_text}"
    tM_log="-----------|----------|----------"
	tModeDebug "2" "${tM_msg}"

	# minrange
    if [ ${FAN1_PWM_MIN} -lt 100 ]; then
		fan1pwmmin="  ${FAN1_PWM_MIN} pwm  "
	else
		fan1pwmmin=" ${FAN1_PWM_MIN} pwm  "
	fi	
    if [ ${FAN2_PWM_MIN} -lt 100 ]; then
		fan2pwmmin="  ${FAN2_PWM_MIN} pwm  "
	else
		fan2pwmmin=" ${FAN2_PWM_MIN} pwm  "
	fi	
	tempminrange="  0°C-${TEMP_MIN}°C "
    tM_msg="${b_cyan_text}${tempminrange}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmmin}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmmin}${reset_text}"
    tM_log="${tempminrange}|${fan1pwmmin}|${fan2pwmmin}"
	tModeDebug "2" "${tM_msg}"

	#range1
    if [ ${FAN1_PWM_RANGE1} -lt 100 ]; then
		fan1pwmrange1="  ${FAN1_PWM_RANGE1} pwm  "
	else
		fan1pwmrange1=" ${FAN1_PWM_RANGE1} pwm  "
	fi	
    if [ ${FAN2_PWM_RANGE1} -lt 100 ]; then
		fan2pwmrange1="  ${FAN2_PWM_RANGE1} pwm  "
	else
		fan2pwmrange1=" ${FAN2_PWM_RANGE1} pwm  "
	fi	
	temprange1=" ${TEMP_RANGE1_START}°C-${TEMP_RANGE1_END}°C "
    tM_msg="${b_cyan_text}${temprange1}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmrange1}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmrange1}${reset_text}"
    tM_log="${temprange1}|${fan1pwmrange1}|${fan2pwmrange1}"
	tModeDebug "2" "${tM_msg}"

	#range2
    if [ ${FAN1_PWM_RANGE2} -lt 100 ]; then
		fan1pwmrange2="  ${FAN1_PWM_RANGE2} pwm  "
	else
		fan1pwmrange2=" ${FAN1_PWM_RANGE2} pwm  "
	fi	
    if [ ${FAN2_PWM_RANGE2} -lt 100 ]; then
		fan2pwmrange2="  ${FAN2_PWM_RANGE2} pwm  "
	else
		fan2pwmrange2=" ${FAN2_PWM_RANGE2} pwm  "
	fi	
	temprange2=" ${TEMP_RANGE2_START}°C-${TEMP_RANGE2_END}°C "
    tM_msg="${b_cyan_text}${temprange2}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmrange2}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmrange2}${reset_text}"
    tM_log="${temprange2}|${fan1pwmrange2}|${fan2pwmrange2}"
	tModeDebug "2" "${tM_msg}"

	#range3
    if [ ${FAN1_PWM_RANGE3} -lt 100 ]; then
		fan1pwmrange3="  ${FAN1_PWM_RANGE3} pwm  "
	else
		fan1pwmrange3=" ${FAN1_PWM_RANGE3} pwm  "
	fi	
    if [ ${FAN2_PWM_RANGE3} -lt 100 ]; then
		fan2pwmrange3="  ${FAN2_PWM_RANGE3} pwm  "
	else
		fan2pwmrange3=" ${FAN2_PWM_RANGE3} pwm  "
	fi	
	temprange3=" ${TEMP_RANGE3_START}°C-${TEMP_RANGE3_END}°C "
    tM_msg="${b_cyan_text}${temprange3}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmrange3}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmrange3}${reset_text}"
    tM_log="${temprange3}|${fan1pwmrange3}|${fan2pwmrange3}"
	tModeDebug "2" "${tM_msg}"

	#range4
    if [ ${FAN1_PWM_RANGE4} -lt 100 ]; then
		fan1pwmrange4="  ${FAN1_PWM_RANGE4} pwm  "
	else
		fan1pwmrange4=" ${FAN1_PWM_RANGE4} pwm  "
	fi	
    if [ ${FAN2_PWM_RANGE4} -lt 100 ]; then
		fan2pwmrange4="  ${FAN2_PWM_RANGE4} pwm  "
	else
		fan2pwmrange4=" ${FAN2_PWM_RANGE4} pwm  "
	fi	
	temprange4=" ${TEMP_RANGE4_START}°C-${TEMP_RANGE4_END}°C "
    tM_msg="${b_cyan_text}${temprange4}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmrange4}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmrange4}${reset_text}"
    tM_log="${temprange4}|${fan1pwmrange4}|${fan2pwmrange4}"
	tModeDebug "2" "${tM_msg}"

	#range5
    if [ ${FAN1_PWM_RANGE5} -lt 100 ]; then
		fan1pwmrange5="  ${FAN1_PWM_RANGE5} pwm  "
	else
		fan1pwmrange5=" ${FAN1_PWM_RANGE5} pwm  "
	fi	
    if [ ${FAN2_PWM_RANGE5} -lt 100 ]; then
		fan2pwmrange5="  ${FAN2_PWM_RANGE5} pwm  "
	else
		fan2pwmrange5=" ${FAN2_PWM_RANGE5} pwm  "
	fi	
	temprange5=" ${TEMP_RANGE5_START}°C-${TEMP_RANGE5_END}°C "
    tM_msg="${b_cyan_text}${temprange5}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmrange5}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmrange5}${reset_text}"
    tM_log="${temprange5}|${fan1pwmrange5}|${fan2pwmrange5}"
	tModeDebug "2" "${tM_msg}"

	# maxrange
    if [ ${FAN1_PWM_MAX} -lt 100 ]; then
		fan1pwmmax="  ${FAN1_PWM_MAX} pwm  "
	else
		fan1pwmmax=" ${FAN1_PWM_MAX} pwm  "
	fi	
    if [ ${FAN2_PWM_MAX} -lt 100 ]; then
		fan2pwmmax="  ${FAN2_PWM_MAX} pwm  "
	else
		fan2pwmmax=" ${FAN2_PWM_MAX} pwm  "
	fi	
	tempmaxrange="   ${TEMP_MAX}°C+   "
    tM_msg="${b_cyan_text}${tempmaxrange}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan1pwmmax}${reset_text}${white_text}|${reset_text}${b_cyan_text}${fan2pwmmax}${reset_text}"
    tM_log="${tempmaxrange}|${fan1pwmmax}|${fan2pwmmax}"
	tModeDebug "2" "${tM_msg}"

}

DisplayHelp() {
#Showstart
    cat << EOM
::: HELP =================================================================================================
:::   ${prg_name} (${script_version})
:::   ${script_desc}
::: INFO =================================================================================================
:::   Source avaiable on: ${script_home}
:::   License: ${script_license}
:::   Author: ${script_author}
:::   Email: ${script_author_email}
:::
:::   Tested on Hardware:
:::      - ${script_tested_hw_1}
:::   Tested on Linux Distributions:
:::      - ${script_tested_os_1}
:::   other files from this programm:
:::     - ${script_files_other_1}
:::     - ${script_files_other_2}
:::     - ${script_files_other_3}
:::     - ${script_files_other_4}
:::     - ${script_files_other_5}
:::   inspired by: ${inspired_by}
:::                ${inspired_link}
::: USAGE ================================================================================================
:::   sudo ./${script_name} [OPTIONS] [PARAMETERS]
:::   sudo ./${script_name} --verbose -p=2 --logfile=/home/zero/Downloads/dell_fans.log
:::   sudo ./${script_name} --daemon
:::   sudo ./${script_name} -d --use_logfile -p=2 --logfile=/tmp/dell_fans.log
:::
::: Options ==============================================================================================
:::   -d,--daemon					DaemonMode (Start script as a Service)
:::   -V,--verbose					VerboseMode (Show what this script do)
:::	  -D,--debug						debugMode (Show debug messages)
:::	  -s,--silent					silentMode (Show nothing - log on file only)
:::   --no_log_color,--nlc			no colored logging (log without colors)
:::   --no_log						deactivate logging
:::   --use_logfile					use logfile instead systemd logging (only on DaemonMode)
:::								
::: PARAMETERS ==============================================================================================
:::   --settings_file=<file.conf>	set the settings file (can use with path)
:::   --logfile=<file.log>			set the logfile (can use with path)
:::									(logfile created by script but path must exist!)
:::   -p=[num],--checkpause=[num]	set custom interval (instead the interval in the settings file)
::: 
::: Options *cannot be combined with other options* ======================================================
:::   -v, --version           		show version and exit
:::   -h, --help              		display this help text and exit
:::
EOM
exit 0
}

main(){
	if [ "$DAEMON_MODE" = false ] && [ "$NO_LOG" = false ]; then
		checkLogfileFile
	elif [ "$DAEMON_MODE" = true ] && [ "$USE_LOGFILE" = true ] && [ "$NO_LOG" = false ]; then
		checkLogfileFile
	fi
	
	preLoadKernelModule
	
	trap cleanup SIGTERM SIGINT

	loadSettingsFile	
	if [ $CUSTOM_CHECK_PAUSE -gt 0 ]; then
		$CHECK_PAUSE=$CUSTOM_CHECK_PAUSE
	fi

    Showstart

	diagnose_dell_hwmon
	resolve_paths
	check_hardware_files

	tM_msg="${b_yellow_text}====== start fan control ======${reset_text}"
	tM_log="====== start fan control ======"
	tModeDebug "2" "${tM_msg}" "${tM_log}"

	runLoop
}

# As long as there is at least one more argument, keep looping
# Process all options (if present)
#while [ "$#" -gt 0 ]; do
for i in "$@"; do
    case "$i" in
        -h|--help) 
          NO_LOG=true
          DisplayHelp
          exit 0
          ;;
        -v|--version)
          NO_LOG=true
          ShowVersion
          exit 0
          ;;
        --logfile=*)
          LOGFILE="${i#*=}"
          shift # past argument=value
          ;;
        --no_log_color|--nlc)
          NO_LOG_COLOR=true
          ;;
        --no_log)
          NO_LOG=true
          ;;
        -d|--daemon) 
          DAEMON_MODE=true
          shift # past argument=value
          ;;
        -s|--silent)
          SILENT_MODE=true
          ;;
        -V|--verbose)
          VERBOSE_MODE=true
          ;;
        -D|--debug)
          DEBUG_MODE=true
          ;;
        --use_logfile) 
          USE_LOGFILE=true
          shift # past argument=value
          ;;
        -p=*|--checkpause=*) 
          CUSTOM_CHECK_PAUSE="${i#*=}"
          shift # past argument=value
          ;;
        --settings_file=*) 
          SETTINGS_FILE="${i#*=}"
          shift # past argument=value
          ;;
        *)
          ;;
    esac
    #shift
done

main




