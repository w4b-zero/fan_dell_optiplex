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
CSI="$(printf '\033')["    # Control Sequence Introducer
black_text="${CSI}30m"     # Black
red_text="${CSI}31m"       # Red
green_text="${CSI}32m"     # Green
yellow_text="${CSI}33m"    # Yellow
blue_text="${CSI}34m"      # Blue
magenta_text="${CSI}35m"   # Magenta
cyan_text="${CSI}36m"      # Cyan
white_text="${CSI}37m"     # White
b_black_text="${CSI}90m"   # Bright Black
b_red_text="${CSI}91m"     # Bright Red
b_green_text="${CSI}92m"   # Bright Green
b_yellow_text="${CSI}93m"  # Bright Yellow
b_blue_text="${CSI}94m"    # Bright Blue
b_magenta_text="${CSI}95m" # Bright Magenta
b_cyan_text="${CSI}96m"    # Bright Cyan
b_white_text="${CSI}97m"   # Bright White
reset_text="${CSI}0m"      # Reset to default
clear_line="${CSI}0K"      # Clear the current line to the right to wipe any artifacts remaining from last print

# text styles
##################################################
bold_text="${CSI}1m"
blinking_text="${CSI}5m"
dim_text="${CSI}2m"

# log settings for systemd
##################################################
# used for output an log writing
# output: Nov 21 10:39:16 zero-pc $LOG_TAG.....
LOG_TAG="dell_fans"

# define internal vars
GET_CPU_TEMP_FILE=""
SET_FAN_SPEED_FILE=""


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
# use '--log_off' parameter to disable logging
LOG_OFF=false # default: logging is active 

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
if [ $DAEMON_MODE = "false" ]; then
	# used when script NOT running as service
	LOGFILE="dell_fans.log" # default: write file dell_fans.log in the directory who start the script
fi
if [ $DAEMON_MODE = "true" ] && [ $USE_LOGFILE = "true" ]; then
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
if [ $DAEMON_MODE = "false" ]; then
	# used when script NOT running as service
	SETTINGS_FILE="dell_fans.conf" # default: use settings file 'dell_fans.conf' in the directory who start the script
fi
if [ $DAEMON_MODE = "true" ]; then
	# used when script running as service
	SETTINGS_FILE="/etc/default/dell_fans.conf" # default: use settings file 'dell_fans.conf' in the system config directory (/etc/default/)
fi


loadSettingsFile() {
# check existence of settings file
# if not exist create settings file with default settings
if [ ! -f "$SETTINGS_FILE" ] || [ ! -r "$SETTINGS_FILE" ]; then
    tM_msg="${red_text}settings file (${b_red_text}$SETTINGS_FILE${reset_text}) does not exist or is not readable.${reset_text}"
    tM_log="settings file ($SETTINGS_FILE) does not exist or is not readable."
	tModeDebug "2" "${tM_msg}" "${tM_log}"
    tM_msg="${yellow_green}create default settings file ($SETTINGS_FILE)${reset_text}"
    tM_log="create default settings file ($SETTINGS_FILE)"
	tModeDebug "1" "${tM_msg}" "${tM_log}"
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
		tM_msg="${red_text}settings file (${b_red_text}$SETTINGS_FILE${reset_text}) write failed!${reset_text}"
		tM_log="settings file ($SETTINGS_FILE) write failed!"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
		tM_msg="${red_text}please check write permissions!${reset_text}"
		tM_log="please check write permissions!"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
		exit 1
	else
		tM_msg="${red_green}settings file ($SETTINGS_FILE) with default settings created${reset_text}"
	    tM_log="settings file ($SETTINGS_FILE) with default settings created"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
	fi
fi
# load settings file
source $SETTINGS_FILE
}

preLoadKernelModule() {
# remove kernel module for reloading 
tM_msg="${cyan_text}remove kernel module (modprobe -r dell_smm_hwmon)${reset_text}"
tM_log="remove kernel module (modprobe -r dell_smm_hwmon)"
tModeDebug "0" "${tM_msg}" "${tM_log}"
modprobe -r dell_smm_hwmon 2>/dev/null || true
sleep 2

# reload kernel module with parameter
tM_msg="${cyan_text}load kernel module (modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1)${reset_text}"
tM_log="load kernel module (modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1)"
tModeDebug "0" "${tM_msg}" "${tM_log}"
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
    
	#fan1
    if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
		tM_msg="${yellow_text}Fan1: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0${reset_text}"
		tM_log="Fan1: dell_smm_hwmon doesn't mount fan files - trying to reload the module with force=1 restricted=0"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        
        # show kernel module status
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
			tM_msg="${cyan_text}Fan1: latest message from the kernel module: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')${reset_text}"
			tM_log="Fan1: latest message from the kernel module: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
        fi
        
        preLoadKernelModule
        
        # check again after reload th kernel module
        pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
        fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
        
        if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
			tM_msg="${red_text}Fan1: EC/BIOS hat den Zugriff auf die Lüftersteuerung blockiert.${reset_text}"
			tM_log="Fan1: EC/BIOS hat den Zugriff auf die Lüftersteuerung blockiert."
			tModeDebug "0" "${tM_msg}" "${tM_log}"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
				tM_msg="${cyan_text}Fan1: Nur Temperatursensoren verfügbar. Um die PWM-Steuerung wiederzuerlangen: Herunterfahren und wieder Einschalten! (kein reboot)${reset_text}"
				tM_log="Fan1: Nur Temperatursensoren verfügbar. Um die PWM-Steuerung wiederzuerlangen: Herunterfahren und wieder Einschalten! (kein reboot)"
				tModeDebug "0" "${tM_msg}" "${tM_log}"
            fi
            SET_FAN_SPEED_FILE=""
            GET_FAN_RPM_FILE=""
        else
            SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
            GET_FAN_RPM_FILE="${fan_candidates[0]}"
			tM_msg="${cyan_text}Fan1: PWM-Steuerung nach 'modprobe' wiederhergestellt${reset_text}"
			tM_log="Fan1: PWM-Steuerung nach 'modprobe' wiederhergestellt"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
        fi
    elif (( ${#pwm_candidates[@]} > 0 )); then
        SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
        GET_FAN_RPM_FILE="${fan_candidates[0]}"
		tM_msg="${cyan_text}Fan1: PWM-Steuerung ab Start verfügbar${reset_text}"
		tM_log="Fan1: PWM-Steuerung ab Start verfügbar"
		tModeDebug "0" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${yellow_text}Fan1: dell_smm_hwmon nur teilweise funktionsfähig - nur Lesezugriffe verfügbar${reset_text}"
		tM_log="Fan1: dell_smm_hwmon nur teilweise funktionsfähig - nur Lesezugriffe verfügbar"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        SET_FAN_SPEED_FILE=""
		GET_FAN_RPM_FILE=""
    fi

	#fan2
    if (( ${#pwm_candidates2[@]} == 0 )) && (( ${#fan_candidates2[@]} == 0 )); then
		tM_msg="${yellow_text}Fan2: dell_smm_hwmon stellt keine Lüfterdateien bereit - Versuch, das Modul mit force=1 restricted=0 neu zu laden${reset_text}"
		tM_log="Fan2: dell_smm_hwmon stellt keine Lüfterdateien bereit - Versuch, das Modul mit force=1 restricted=0 neu zu laden"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        
        # Aktuellen Modulstatus anzeigen
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
			tM_msg="${cyan_text}Fan2: Letzte Meldungen vom Modul: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')${reset_text}"
			tM_log="Fan2: Letzte Meldungen vom Modul: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
        fi
        
        preLoadKernelModule
        
        # Nach dem Aufladen erneut prüfen.
        pwm_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm2)
        fan_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan2_input)
        
        if (( ${#pwm_candidates2[@]} == 0 )) && (( ${#fan_candidates2[@]} == 0 )); then
			tM_msg="${red_text}Fan2: EC/BIOS hat den Zugriff auf die Lüftersteuerung blockiert.${reset_text}"
			tM_log="Fan2: EC/BIOS hat den Zugriff auf die Lüftersteuerung blockiert."
			tModeDebug "0" "${tM_msg}" "${tM_log}"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
				tM_msg="${cyan_text}Fan2: Nur Temperatursensoren verfügbar. Um die PWM-Steuerung wiederzuerlangen: Herunterfahren und wieder Einschalten! (kein reboot)${reset_text}"
				tM_log="Fan2: Nur Temperatursensoren verfügbar. Um die PWM-Steuerung wiederzuerlangen: Herunterfahren und wieder Einschalten! (kein reboot)"
				tModeDebug "0" "${tM_msg}" "${tM_log}"
            fi
            SET_FAN_SPEED_FILE2=""
            GET_FAN_RPM_FILE2=""
        else
            SET_FAN_SPEED_FILE2="${pwm_candidates2[0]}"
            GET_FAN_RPM_FILE2="${fan_candidates2[0]}"
			tM_msg="${cyan_text}Fan2: PWM-Steuerung nach 'modprobe' wiederhergestellt${reset_text}"
			tM_log="Fan2: PWM-Steuerung nach 'modprobe' wiederhergestellt"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
        fi
    elif (( ${#pwm_candidates2[@]} > 0 )); then
        SET_FAN_SPEED_FILE2="${pwm_candidates2[0]}"
        GET_FAN_RPM_FILE2="${fan_candidates2[0]}"
		tM_msg="${cyan_text}Fan2: PWM-Steuerung ab Start verfügbar${reset_text}"
		tM_log="Fan2: PWM-Steuerung ab Start verfügbar"
		tModeDebug "0" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${yellow_text}Fan2: dell_smm_hwmon nur teilweise funktionsfähig - nur Lesezugriffe verfügbar${reset_text}"
		tM_log="Fan2: dell_smm_hwmon nur teilweise funktionsfähig - nur Lesezugriffe verfügbar"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        SET_FAN_SPEED_FILE2=""
		GET_FAN_RPM_FILE2=""
    fi

    # Standardverhalten wiederherstellen
    shopt -u nullglob

	tM_msg="${cyan_text}CPU Temperatur-Datei: $GET_CPU_TEMP_FILE${reset_text}"
	tM_log="CPU Temperatur-Datei: $GET_CPU_TEMP_FILE"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ -n "$SET_FAN_SPEED_FILE2" ]]; then
		tM_msg="${cyan_text}Fan1 PWM-Datei: $SET_FAN_SPEED_FILE${reset_text}"
		tM_log="Fan1 PWM-Datei: $SET_FAN_SPEED_FILE"
		tModeDebug "0" "${tM_msg}" "${tM_log}"
		tM_msg="${cyan_text}Fan2 PWM-Datei: $SET_FAN_SPEED_FILE2${reset_text}"
		tM_log="Fan2 PWM-Datei: $SET_FAN_SPEED_FILE2"
		tModeDebug "0" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${yellow_text}NUR-ÜBERWACHUNGSMODUS: Keine PWM-Steuerung (EC/BIOS-Zugriff blockiert)${reset_text}"
		tM_log="NUR-ÜBERWACHUNGSMODUS: Keine PWM-Steuerung (EC/BIOS-Zugriff blockiert)"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
    fi

}

# Variable zum Speichern des vorherigen PWM-Signals
previous_pwm=$MIN_PWM
previous_temp=0

# Funktion für mit systemd kompatibles Logging
log_message() {
    # Verwenden Sie ausschließlich den Logger, um zu vermeiden, dass die Ausgabe durch ersetzte Befehle verfälscht wird.
#    logger -t "$LOG_TAG" "$(date '+%Y-%m-%d %H:%M:%S') - $1"
    logger -t "$LOG_TAG" "$1"
    #echo "$(date '+%b %d %T') $LOG_TAG $1" | ccze -A --plugin=syslog | tee -a dell_fans.log
}

# Funktion zur Berechnung der temperaturabhängigen PWM mit thermischem Schutz
calculate_pwm() {
    local temp=$1
    local temp_diff=$2
    local pwm
    
    # Kritischer Schutz: Bei einer Temperatur von >= 80°C sofortige maximale
    if (( temp >= CRITICAL_TEMP )); then
        log_message "KRITISCH: Kritische Temperatur ${temp}°C, maximales PWM"
        echo $MAX_PWM
        return
    fi
    
    # Vorausschauender Schutz: Bei schnellem Temperaturanstieg (>3°C) aggressive PWM-Anpassung.
    if (( temp_diff > TEMP_RISE_THRESHOLD )); then
        # Aggressive PWM berechnen: Annahme, dass die Temperatur weiter ansteigt
        local predicted_temp=$((temp + temp_diff * 2))  # Sagt die Temperatur in den nächsten 2 Zyklen voraus
        if (( predicted_temp > MAX_TEMP )); then
            predicted_temp=$MAX_TEMP
        fi
        pwm=$(( (predicted_temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
        if (( pwm > MAX_PWM )); then pwm=$MAX_PWM; fi
        log_message "VORHERSAGEN: Schneller Anstieg +${temp_diff}°C, aggressives PWM: ${pwm}"
        echo $pwm
        return
    fi
    
    # Normalenmapping für allmähliche Änderungen
    if (( temp <= MIN_TEMP )); then
        pwm=$MIN_PWM
    elif (( temp >= MAX_TEMP )); then
        pwm=$MAX_PWM
    else
        # Glatte lineare Zuordnung zwischen MIN_TEMP und MAX_TEMP
        pwm=$(( (temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
    fi
    
    echo $pwm
}

# Funktion zum Überprüfen von Hardwaredateien
check_hardware_files() {
    if [[ ! -r $GET_CPU_TEMP_FILE ]]; then
		tM_msg="${red_text}Temperaturdatei konnte nicht gelesen werden: $GET_CPU_TEMP_FILE${reset_text}"
		tM_log="Temperaturdatei konnte nicht gelesen werden: $GET_CPU_TEMP_FILE"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    
    # PWM nur prüfen, falls verfügbar
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ ! -w $SET_FAN_SPEED_FILE ]] && [[ $EUID -ne 0 ]]; then
		tM_msg="${red_text}PWM-Datei konnte nicht geschrieben werden: $SET_FAN_SPEED_FILE (als Root ausführen)${reset_text}"
		tM_log="PWM-Datei konnte nicht geschrieben werden: $SET_FAN_SPEED_FILE (als Root ausführen)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    if [[ -n "$SET_FAN_SPEED_FILE2" ]] && [[ ! -w $SET_FAN_SPEED_FILE2 ]] && [[ $EUID -ne 0 ]]; then
		tM_msg="${red_text}PWM-Datei konnte nicht geschrieben werden: $SET_FAN_SPEED_FILE2 (als Root ausführen)${reset_text}"
		tM_log="PWM-Datei konnte nicht geschrieben werden: $SET_FAN_SPEED_FILE2 (als Root ausführen)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
}

# Ausgangsreinigungsfunktion
cleanup() {
	tM_msg="\n${yellow_text}Abbruchsignal empfangen, Lüfter wieder auf Automatikbetrieb${reset_text}"
	tM_log="\nAbbruchsignal empfangen, Lüfter wieder auf Automatikbetrieb"
	tModeDebug "2" "${tM_msg}" "${tM_log}"
    # Optional: Lüfter wieder in den Automatikmodus versetzen
    exit 0
}

# Funktion zur Diagnose des Status des dell_smm_hwmon
diagnose_dell_hwmon() {
		tM_msg="${cyan_text}=== DELL_SMM_HWMON DIAGNOSE ===${reset_text}"
		tM_log="=== DELL_SMM_HWMON DIAGNOSE ==="
		tModeDebug "0" "${tM_msg}" "${tM_log}"
    
    # Prüfen, ob das Modul geladen ist
    if lsmod | grep -q dell_smm_hwmon; then
		tM_msg="${cyan_text}dell_smm_hwmon-Modul geladen${reset_text}"
		tM_log="dell_smm_hwmon-Modul geladen"
		tModeDebug "0" "${tM_msg}" "${tM_log}"
    else
		tM_msg="${yellow_text}dell_smm_hwmon-Modul NICHT geladen${reset_text}"
		tM_log="dell_smm_hwmon-Modul NICHT geladen"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        return
    fi
    
    # Verfügbare Dateien prüfen
    if [[ -d "/sys/devices/platform/dell_smm_hwmon/hwmon" ]]; then
        local hwmon_dir=$(find /sys/devices/platform/dell_smm_hwmon/hwmon -name "hwmon*" -type d | head -1)
        if [[ -n "$hwmon_dir" ]]; then
            local available_files=$(ls "$hwmon_dir" 2>/dev/null | grep -E "temp|fan|pwm" | tr '\n' ' ')
			tM_msg="${cyan_text}Verfügbare Dateien: $available_files${reset_text}"
			tM_log="Verfügbare Dateien: $available_files"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
            
            # Überprüfen Sie insbesondere PWM und Lüfter
            if ls "$hwmon_dir"/pwm* >/dev/null 2>&1; then
				tM_msg="${cyan_text}PWM-Dateien gefunden - Steuerung verfügbar${reset_text}"
			tM_log="PWM-Dateien gefunden - Steuerung verfügbar"
				tModeDebug "0" "${tM_msg}" "${tM_log}"
            elif ls "$hwmon_dir"/fan* >/dev/null 2>&1; then
				tM_msg="${yellow_text}Nur Lüfterdateien - keine PWM-Steuerung${reset_text}"
			tM_log="Nur Lüfterdateien - keine PWM-Steuerung"
				tModeDebug "2" "${tM_msg}" "${tM_log}"
            else
			tM_msg="${yellow_text}Nur Temperatursensoren - EC blockierte Lüfter${reset_text}"
			tM_log="Nur Temperatursensoren - EC blockierte Lüfter"
			tModeDebug "2" "${tM_msg}" "${tM_log}"
            fi
        fi
    else
			tM_msg="${red_text}Verzeichnis dell_smm_hwmon nicht gefunden${reset_text}"
			tM_log="Verzeichnis dell_smm_hwmon nicht gefunden"
			tModeDebug "1" "${tM_msg}" "${tM_log}"
    fi
    
			tM_msg="${cyan_text}=== ENDE DER DIAGNOSE ===${reset_text}"
			tM_log="=== ENDE DER DIAGNOSE ==="
			tModeDebug "0" "${tM_msg}" "${tM_log}"
}

runLoop() {
# Die Skriptlogik wird in einer Endlosschleife ausgeführt.
while true; do
    # Liest die aktuelle Temperatur in Milli-Celsius und rechnet sie in Celsius um.
    current_cpu_temp=$(($(cat "$GET_CPU_TEMP_FILE") / 1000))
    current_rpm_speed=$(($(cat "$GET_FAN_RPM_FILE")))
    current_rpm_speed2=$(($(cat "$GET_FAN_RPM_FILE2")))

    # Berechne die Temperaturdifferenz zum letzten Messwert
    temp_diff=$((current_cpu_temp - previous_temp))
    if (( temp_diff < 0 )); then temp_diff=0; fi  # Solo nos interesan las subidas
    
    # PWM mit thermischem Schutz berechnen
#    target_pwm=$(calculate_pwm $current_cpu_temp $temp_diff)

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
		tc="${blue_text}"
		tc1="${blue_text}"
	elif [ "$current_cpu_temp" -gt ${range1_temp_min} ] && [ "$current_cpu_temp" -lt ${range1_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE1}
		fan2_target_pwm=${FAN2_PWM_RANGE1}
		tc="${green_text}"
		tc1="${green_text}"
	elif [ "$current_cpu_temp" -gt ${range2_temp_min} ] && [ "$current_cpu_temp" -lt ${range2_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE2}
		fan2_target_pwm=${FAN2_PWM_RANGE2}
		tc="${b_yellow_text}"
		tc1="${yellow_text}"
	elif [ "$current_cpu_temp" -gt ${range3_temp_min} ] && [ "$current_cpu_temp" -lt ${range3_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE3}
		fan2_target_pwm=${FAN2_PWM_RANGE3}
		tc="${yellow_text}${bold_text}"
		tc1="${magenta_text}"
	elif [ "$current_cpu_temp" -gt${range4_temp_min} ] && [ "$current_cpu_temp" -lt ${range4_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE4}
		fan2_target_pwm=${FAN2_PWM_RANGE4}
		tc="${magenta_text}${bold_text}"
		tc1="${b_magenta_text}"
	elif [ "$current_cpu_temp" -gt ${range5_temp_min} ] && [ "$current_cpu_temp" -lt ${range5_temp_max} ];then
		fan1_target_pwm=${FAN1_PWM_RANGE5}
		fan2_target_pwm=${FAN2_PWM_RANGE5}
		tc="${b_red_text}${bold_text}"
		tc1="${magenta_text}"
	else
		fan1_target_pwm=${FAN1_PWM_MAX}
		fan2_target_pwm=${FAN2_PWM_MAX}
		tc="${red_text}"
		tc1="${red_text}"
	fi

	# set pwm to fans
	if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
		echo "$fan1_target_pwm" > "$SET_FAN_SPEED_FILE"
	fi
	if [[ -n "$SET_FAN_SPEED_FILE2" ]]; then
		echo "$fan1_target_pwm" > "$SET_FAN_SPEED_FILE2"
	fi

	# write info message 
	if [ ${fan2_target_pwm} -lt 100 ]; then
		fan2_pwm_set=" ${fan2_target_pwm}"
	else
		fan2_pwm_set="${fan2_target_pwm}"
	fi	
	if [ ${fan1_target_pwm} -lt 100 ]; then
		fan1_pwm_set=" ${fan1_target_pwm}"
	else
		fan1_pwm_set="${fan1_target_pwm}"
	fi	
	tM_msg="	${white_text}CPU:${reset_text} ${tc}${current_cpu_temp}${reset_text}${tc1}°C${reset_text} ${cyan_text}(Δ+${temp_diff}°C)${reset_text} ${white_text}FAN1:${reset_text} ${b_cyan_text}${fan1_pwm_set}pwm${reset_text}${white_text}/${reset_text}${b_cyan_text}${current_rpm_speed}rpm${reset_text} ${white_text}FAN2:${reset_text} ${b_cyan_text}${fan2_pwm_set}pwm${reset_text}${white_text}/${reset_text}${b_cyan_text}${current_rpm_speed2}rpm${reset_text}"
	tM_log="CPU: ${current_cpu_temp}°C (Δ+${temp_diff}°C) FAN1: ${fan1_pwm_set}pwm/${current_rpm_speed}rpm FAN2: ${fan2_pwm_set}pwm/${current_rpm_speed2}rpm"
	#tM_log="CPU: 00°C (Δ+0°C) FAN1: 000pwm/0000rpm FAN2: 000pwm/0000rpm"
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
		msgTyp="[${yellow_text}WARNING${reset_text}]"
		logTyp="[WARNING]"
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
	if [ "$msgId" = "3" ] && [ "$VERBOSE_MODE" = "true" ]; then
		#show only if m_silent off 
		if [ "$SILENT_MODE" = "false" ] && [ $DAEMON_MODE = "false" ]; then
	    		echo "${dtstart} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ $LOGOFF = "false" ]; then
			if [ $DAEMON_MODE = "false" ]; then
				if [ $NO_LOG_COLOR = "false" ]; then
					echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
				else
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
				fi
			fi
			if [ $DAEMON_MODE = "true" ]; then 
				if [ $USE_LOGFILE = "true" ]; then
					if [ $NO_LOG_COLOR = "false" ]; then
						echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
					else
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
					fi
				else
					if [ $NO_LOG_COLOR = "false" ]; then
						log_message "${msgTyp}: ${msgText}"
					else
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
	
	# debug messages
	if [ "$msgId" = "2" ] && { [ "$DEBUG_MODE" = "true" ] || [ "$VERBOSE_MODE" = "true" ]; }; then
		#show only if m_silent off 
		if [ "$SILENT_MODE" = "false" ] && [ $DAEMON_MODE = "false" ]; then
			echo "${dtstart} ${msgTyp}: ${msgText}"
	    fi
		#log
		if [ $LOGOFF = "false" ]; then
			if [ $DAEMON_MODE = "false" ]; then
				if [ $NO_LOG_COLOR = "false" ]; then
					echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
				else
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
				fi
			fi
			if [ $DAEMON_MODE = "true" ]; then 
				if [ $USE_LOGFILE = "true" ]; then
					if [ $NO_LOG_COLOR = "false" ]; then
						echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
					else
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
					fi
				else
					if [ $NO_LOG_COLOR = "false" ]; then
						log_message "${msgTyp}: ${msgText}"
					else
						log_message "${logTyp}: ${logText}"
					fi
				fi
			fi
		fi
	fi
	
	# error messages
	if [ "$msgId" = "1" ]; then
		#show only if m_silent off 
		if [ "$SILENT_MODE" = "false" ] && [ $DAEMON_MODE = "false" ]; then
			echo "${dtstart} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ $LOGOFF = "false" ]; then
			if [ $DAEMON_MODE = "false" ]; then
				if [ $NO_LOG_COLOR = "false" ]; then
					echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
				else
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
				fi
			fi
			if [ $DAEMON_MODE = "true" ]; then 
				if [ $USE_LOGFILE = "true" ]; then
					if [ $NO_LOG_COLOR = "false" ]; then
						echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
					else
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
					fi
				else
					if [ $NO_LOG_COLOR = "false" ]; then
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
		if [ "$SILENT_MODE" = "false" ] && [ $DAEMON_MODE = "false" ]; then
			echo "${dtstart} ${msgTyp}: ${msgText}"
		fi
		#log
		if [ $LOGOFF = "false" ]; then
			if [ $DAEMON_MODE = "false" ]; then
				if [ $NO_LOG_COLOR = "false" ]; then
					echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
				else
					echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
				fi
			fi
			if [ $DAEMON_MODE = "true" ]; then 
				if [ $USE_LOGFILE = "true" ]; then
					if [ $NO_LOG_COLOR = "false" ]; then
						echo "${dtstart} ${LOG_TAG} ${msgTyp}: ${msgText}" >> "${logfile}"
					else
						echo "${dtstart} ${LOG_TAG} ${logTyp}: ${logText}" >> "${logfile}"
					fi
				else
					if [ $NO_LOG_COLOR = "false" ]; then
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
    tM_msg="${b_yellow_text}used settings${reset_text}"
    tM_log="used settings"
	tModeDebug "2" "${tM_msg}"
    tM_msg="${b_yellow_text}===========================${reset_text}"
    tM_log="==========================="
	tModeDebug "2" "${tM_msg}"
	
	# debug: VERBOSE_MODE
	if [ ${VERBOSE_MODE} = "true" ]; then
		tM_msg="${b_yellow_text}VERBOSE_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="VERBOSE_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}VERBOSE_MODE:${reset_text} ${white_text}false${reset_text}"
		tM_log="VERBOSE_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: DEBUG_MODE
	if [ ${DEBUG_MODE} = "true" ]; then
		tM_msg="${b_yellow_text}DEBUG_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="DEBUG_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}DEBUG_MODE:${reset_text} ${white_text}false${reset_text}"
		tM_log="DEBUG_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: SILENT_MODE
	if [ ${SILENT_MODE} = "true" ]; then
		tM_msg="${b_yellow_text}SILENT_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="SILENT_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}SILENT_MODE:${reset_text} ${white_text}false${reset_text}"
		tM_log="SILENT_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: NO_LOG_COLOR
	if [ ${NO_LOG_COLOR} = "true" ]; then
		tM_msg="${b_yellow_text}NO_LOG_COLOR:${reset_text} ${green_text}true${reset_text}"
		tM_log="NO_LOG_COLOR: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}NO_LOG_COLOR:${reset_text} ${white_text}false${reset_text}"
		tM_log="NO_LOG_COLOR: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: LOG_OFF
	if [ ${LOG_OFF} = "true" ]; then
		tM_msg="${b_yellow_text}LOG_OFF:${reset_text} ${green_text}true${reset_text}"
		tM_log="LOG_OFF: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}LOG_OFF:${reset_text} ${white_text}false${reset_text}"
		tM_log="LOG_OFF: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: DAEMON_MODE
	if [ ${DAEMON_MODE} = "true" ]; then
		tM_msg="${b_yellow_text}DAEMON_MODE:${reset_text} ${green_text}true${reset_text}"
		tM_log="DAEMON_MODE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}DAEMON_MODE:${reset_text} ${white_text}false${reset_text}"
		tM_log="DAEMON_MODE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: USE_LOGFILE
	if [ ${USE_LOGFILE} = "true" ]; then
		tM_msg="${b_yellow_text}USE_LOGFILE:${reset_text} ${green_text}true${reset_text}"
		tM_log="USE_LOGFILE: true"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}USE_LOGFILE:${reset_text} ${white_text}false${reset_text}"
		tM_log="USE_LOGFILE: false"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: CUSTOM_CHECK_PAUSE
	if [ ${CUSTOM_CHECK_PAUSE} -gt 0 ]; then
		tM_msg="${b_yellow_text}${green_text}CUSTOM_CHECK_PAUSE:${reset_text} ${green_text}${CUSTOM_CHECK_PAUSE}${reset_text}"
		tM_log="CUSTOM_CHECK_PAUSE: ${CUSTOM_CHECK_PAUSE}"
		tModeDebug "2" "${tM_msg}"
	else
		tM_msg="${b_yellow_text}${green_text}CUSTOM_CHECK_PAUSE:${reset_text} ${white_text}0${reset_text}"
		tM_log="CUSTOM_CHECK_PAUSE: 0"
		tModeDebug "2" "${tM_msg}"
	fi
	
	# debug: LOGFILE
    tM_msg="${b_yellow_text}LOGFILE: ${LOGFILE}${reset_text}"
    tM_log="LOGFILE: ${LOGFILE}"
	tModeDebug "2" "${tM_msg}"
	
	# debug: SETTINGS_FILE
    tM_msg="${b_yellow_text}SETTINGS_FILE: ${SETTINGS_FILE}${reset_text}"
    tM_log="SETTINGS_FILE: ${SETTINGS_FILE}"
	tModeDebug "2" "${tM_msg}"

	# debug: CHECK_PAUSE
    tM_msg="${b_yellow_text}CHECK_PAUSE: ${CHECK_PAUSE}${reset_text}"
    tM_log="CHECK_PAUSE: ${CHECK_PAUSE}"
	tModeDebug "2" "${tM_msg}"

	# debug: range settings 
    tM_msg="${b_yellow_text}temp range${reset_text} ${white_text}|${reset_text} {b_yellow_text}fan1 pwm${reset_text} ${white_text}|${reset_text} {b_yellow_text}fan2 pwm ${reset_text}"
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
    tM_msg="${b_yellow_text}${tempminrange}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmmin}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmmin}${reset_text}"
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
    tM_msg="${b_yellow_text}${temprange1}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmrange1}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmrange1}${reset_text}"
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
    tM_msg="${b_yellow_text}${temprange2}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmrange2}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmrange2}${reset_text}"
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
    tM_msg="${b_yellow_text}${temprange3}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmrange3}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmrange3}${reset_text}"
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
    tM_msg="${b_yellow_text}${temprange4}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmrange4}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmrange4}${reset_text}"
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
    tM_msg="${b_yellow_text}${temprange5}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmrange5}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmrange5}${reset_text}"
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
    tM_msg="${b_yellow_text}${tempmaxrange}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan1pwmmax}${reset_text}${white_text}|${reset_text}${b_yellow_text}${fan2pwmmax}${reset_text}"
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
:::   --logoff						deactivate logging
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

	runLoop
}

# As long as there is at least one more argument, keep looping
# Process all options (if present)
#while [ "$#" -gt 0 ]; do
for i in "$@"; do
    case "$i" in
        -h|--help) 
          DisplayHelp
          exit 0
          ;;
        -v|--version)
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
        --logoff)
          LOGOFF=1
          ;;
        -d|--daemon) 
          DAEMON_MODE=1
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
          USE_LOGFILE=1
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




