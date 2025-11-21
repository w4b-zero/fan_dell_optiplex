#!/bin/bash
### programm vars
# NAME
prg_name="DELL fan pwm2rpm test"
# SCRIPTNAME
script_name="dell_fans_test.sh"
# SCRIPTHOME
script_home="https://github.com/w4b-zero/dell_fan_control"
# VERSION
script_version="v1.0.0"
# AUTHOR
script_author="zero™"
# AUTHOREMAIL
script_author_email="w4b.zero@googlemail.com"
# AUTHORHOME
script_author_home="https://github.com/w4b-zero"

# COLORS
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
# STYLES
bold_text="${CSI}1m"
blinking_text="${CSI}5m"
dim_text="${CSI}2m"

# file to write test result
dtlogfile=$(date +"%Y_%b_%d-%T")
logfile="dell_fans_test-${dtlogfile}.log"

# default vars
testfan=1 # fan1=cpu fan2=casefan
startpwm=20 
endpwm=223 # upper 223 shows write error
testpause=30 # waiting seconds for fan to change rpm
logoff=0 # 0=write logfile / 1=write NO logfile
runs=0 # 0=calculate from startpwm and endpwm / if set -r=*/-runs=* use the set runs


# safe the system when pwm too low but cpu to hot!
CRITICAL_TEMP=70 # cpu temp to abort test
GET_CPU_TEMP_FILE=""
SET_FAN_SPEED_FILE=""
SET_FAN_SPEED_FILE2=""
GET_FAN_RPM_FILE=""
GET_FAN_RPM_FILE2=""

# Glob-Muster in spezifische Routen auflösen und den vorherigen Variablen zuweisen
resolve_paths() {
    # Aktiviert Nullglob, damit nicht übereinstimmende Muster zu Nichts erweitert werden.
    shopt -s nullglob

    temp_candidates=(/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
    if (( ${#temp_candidates[@]} == 0 )); then
		tM_msg="${red_text}/temp1_input wurde in coretemp hwmon nicht gefunden (Suche: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)${reset_text}"
		tM_log="/temp1_input wurde in coretemp hwmon nicht gefunden (Suche: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)"
		tModeDebug "1" "${tM_msg}" "${tM_log}"
        exit 1
    fi
    GET_CPU_TEMP_FILE="${temp_candidates[0]}"

    # Prüfen, ob dell_smm_hwmon verfügbar und funktionsfähig ist
    pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
    fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
    pwm_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm2)
    fan_candidates2=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan2_input)
    
	#fan1
    if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
		tM_msg="${yellow_text}Fan1: dell_smm_hwmon stellt keine Lüfterdateien bereit - Versuch, das Modul mit force=1 restricted=0 neu zu laden${reset_text}"
		tM_log="Fan1: dell_smm_hwmon stellt keine Lüfterdateien bereit - Versuch, das Modul mit force=1 restricted=0 neu zu laden"
		tModeDebug "2" "${tM_msg}" "${tM_log}"
        
        # Aktuellen Modulstatus anzeigen
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
			tM_msg="${cyan_text}Fan1: Letzte Meldungen vom Modul: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')${reset_text}"
			tM_log="Fan1: Letzte Meldungen vom Modul: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
			tModeDebug "0" "${tM_msg}" "${tM_log}"
        fi
        
        modprobe -r dell_smm_hwmon 2>/dev/null || true
        sleep 2
        modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1 2>/dev/null || true
        sleep 3
        
        # Nach dem Aufladen erneut prüfen.
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
        
        modprobe -r dell_smm_hwmon 2>/dev/null || true
        sleep 2
        modprobe dell_smm_hwmon dell-smm-hwmon ignore_dmi=1 fan_max=4 restricted=0 force=1 power_status=1 2>/dev/null || true
        sleep 3
        
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

runTest(){
	if [ "$testfan" == 1 ]; then
		setpwm_file=$SET_FAN_SPEED_FILE
		getrpm_file=$GET_FAN_RPM_FILE
	elif [ "$testfan" == 2 ]; then
		setpwm_file=$SET_FAN_SPEED_FILE2
		getrpm_file=$GET_FAN_RPM_FILE2
	fi
	x=1
	setpwm=$startpwm
	
	if [ "$runs" == 0 ]; then
		runs1=$(($endpwm-$startpwm+1))
	else
		runs1=$runs
	fi
	#echo "$runs1"

	SECONDS=0
	tM_msg="${cyan_text}=== DELL fan test start ===${reset_text}"
	tM_log="=== DELL fan test start ==="
	tModeDebug "0" "${tM_msg}" "${tM_log}"

	while [ $x -le $runs1 ]
	do
		testtime=$(date +"%b %d %T")
		if [ $logoff == 0 ]; then
			printf "$testtime [FAN$testfan test]: " >> "${logfile}"
		fi
		printf "${b_cyan_text}$testtime${reset_text} [${b_magenta_text}FAN$testfan test${reset_text}]: "
		
		cpu_temp=$(($(cat "$GET_CPU_TEMP_FILE") / 1000))
		echo "${setpwm}" > $setpwm_file
		fan_rpm=$(cat "$GET_FAN_RPM_FILE")

		if [ $logoff == 0 ]; then
			printf "RUN: $x | FAN-PWM: $setpwm | FAN-RPM: $fan_rpm | " >> "${logfile}"
		fi
		printf "RUN: ${b_cyan_text}$x/$runs1${reset_text} ${b_magenta_text}|${reset_text} FAN-PWM: ${b_cyan_text}$setpwm${reset_text} ${b_magenta_text}|${reset_text} FAN-RPM: ${b_cyan_text}$fan_rpm${reset_text} ${b_magenta_text}|${reset_text} "
		setpwm=$(( $setpwm + 1 ))
		x=$(( $x + 1 ))
#		waiting=0
#		while [ $waiting -le $testpause ]
#		do
#			printf "\r" "wait $testpause Seconds for fan"
#			sleep 1
#			waiting=$(( $waiting + 1 ))
#		done
#		printf "done\n"
	seconds=$testpause
	col=$testpause
	addp=$(($testpause+2))
	printf "%02d %1s" "$seconds" "${b_magenta_text}[${reset_text}"
#	printf "$seconds ["
	z=$testpause
	while [ $z -gt 0 ]; do
		printf "${b_red_text}-${reset_text}"
		z=$(( $z - 1 ))
	done
	printf "${b_magenta_text}]${reset_text}"
	#sleep 5
	load=0
	while [ $seconds -gt 0 ]; do 
		let seconds=$seconds-1 
			if [ $seconds -gt 9 ]; then
				y=$testpause
				charback="\b\b\b\b\b"
				while [ $y -gt 0 ]; do
					charback="$charback\b"
#					printf "\b "
					y=$(($y-1))
				done
				#printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b$(echo $seconds) "
				printf "${charback}$(echo $seconds) "
			fi
			if [ $seconds -le 9 ]; then
				y=$testpause
				charback="\b\b\b\b\b"
				while [ $y -gt 0 ]; do
					charback="$charback\b"
#					printf "\b "
					y=$(($y-1))
				done
				#printf "\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b\b0$(echo $seconds) "
				#echo "charback=$charback"
				printf "${charback}0$(echo $seconds) "
			fi
			printf "${b_magenta_text}[${reset_text}"
			load=$(($col - $seconds))
			while [ $load -gt 0 ]; do
				printf "${b_green_text}>${reset_text}"
				let load=$load-1
			done
			end=$seconds
			while [ $end -gt 0 ]; do
				printf "${b_red_text}-${reset_text}"
				let end=$end-1
			done
			printf "${b_magenta_text}]${reset_text}"
			sleep 1
		done
		fan_rpm=$(cat "$GET_FAN_RPM_FILE")
			printf " ${b_magenta_text}|${reset_text} FAN-RPM: ${b_cyan_text}$fan_rpm${reset_text}\n"
			if [ $logoff == 0 ]; then
				printf "FAN-RPM: $fan_rpm\n"  >> "${logfile}"
			fi
	done

	duration=$SECONDS
	scripttime="(test duration: $(($duration / 3600)):$((($duration / 60) % 60)):$(($duration % 60)))"
	tM_msg="${cyan_text}=== DELL fan test end  ===${reset_text}"
	tM_log="=== DELL fan test end  ==="
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${b_black}${scripttime}${reset_text}"
	tM_log="${scripttime}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

        exit 1
}

tModeDebug() {
    local msgId
    local msgText
    local dtstart
		msgId=$1
		msgText=$2
		msgLog=$3
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

	    	echo "${b_cyan_text}${dtstart}${reset_text} ${msgTyp}: ${msgText}"
		if [ $logoff == 0 ]; then
		    	echo "${dtstart} ${logTyp}: ${msgLog}" >> "${logfile}"
		fi
}


ShowVersion() {
	# scriptname and version
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣${reset_text}               ${b_green_text}${prg_name}${reset_text} ${b_white_text}${script_version}${reset_text}                  ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

#    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
#    tM_log="⏣			            Userspace Logfile Manager v1.0.0            			  ⏣"
#    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
#    tM_log="⏣	Source: https://github.com/w4b-zero/userspace_logfile_manader   ⏣"
#    tM_log="⏣	Author: zero™ (w4b.zero@googlemail.com)						 ⏣"
#    tM_log="⏣	       Web: https://github.com/w4b-zero                                                               ⏣"
#    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"


    tM_msg="${blue_text}⏣${reset_text} Source: ${script_home} ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

    tM_msg="${blue_text}⏣${reset_text} Author: ${script_author} (${b_white_text}${script_author_email}${reset_text})                       ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

    tM_msg="${blue_text}⏣${reset_text}    Web: ${script_author_home}                           ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

    exit 0
}

ShowColors() {
	# scriptname and version
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣${reset_text}               ${b_green_text}${prg_name}${reset_text} ${b_white_text}${script_version}${reset_text}                  ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"


	# debug: used settings header
    tM_msg="${bold_text}${green_text}test message colors${reset_text}"
    tM_log="test message colors"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${bold_text}${green_text}===========================${reset_text}"
    tM_log="==========================="
	tModeDebug "0" "${tM_msg}" "${tM_log}"
	
	# info
    tM_msg="INFO message"
    tM_log="INFO message"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
	# error
    tM_msg="ERROR message"
    tM_log="ERROR message"
	tModeDebug "1" "${tM_msg}"
	# debug
    tM_msg="DEBUG message"
    tM_log="DEBUG message"
	tModeDebug "2" "${tM_msg}"
	# verbose
    tM_msg="VERBOSE message"
    tM_log="VERBOSE message"
	tModeDebug "3" "${tM_msg}"

	# ${black_text}
    tM_msg="${black_text}black_text${reset_text}"
    tM_log="${black_text}black_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${red_text}
    tM_msg="${red_text}red_text${reset_text}"
    tM_log="${red_text}red_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${green_text}
    tM_msg="${green_text}green_text${reset_text}"
    tM_log="${green_text}green_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${yellow_text}
    tM_msg="${yellow_text}yellow_text${reset_text}"
    tM_log="${yellow_text}yellow_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${blue_text}
    tM_msg="${blue_text}blue_text${reset_text}"
    tM_log="${blue_text}blue_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${magenta_text}
    tM_msg="${magenta_text}magenta_text${reset_text}"
    tM_log="${magenta_text}magenta_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${cyan_text}
    tM_msg="${cyan_text}cyan_text${reset_text}"
    tM_log="${cyan_text}cyan_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${white_text}
    tM_msg="${white_text}white_text${reset_text}"
    tM_log="${white_text}white_text${reset_text}"
	tModeDebug "2" "${tM_msg}"

	# ${b_black_text}
    tM_msg="${b_black_text}b_black_text${reset_text}"
    tM_log="${b_black_text}b_black_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_red_text}
    tM_msg="${b_red_text}b_red_text${reset_text}"
    tM_log="${b_red_text}b_red_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_green_text}
    tM_msg="${b_green_text}b_green_text${reset_text}"
    tM_log="${b_green_text}b_green_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_yellow_text}
    tM_msg="${b_yellow_text}b_yellow_text${reset_text}"
    tM_log="${b_yellow_text}b_yellow_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_blue_text}
    tM_msg="${b_blue_text}b_blue_text${reset_text}"
    tM_log="${b_blue_text}b_blue_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_magenta_text}
    tM_msg="${b_magenta_text}b_magenta_text${reset_text}"
    tM_log="${b_magenta_text}b_magenta_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_cyan_text}
    tM_msg="${b_cyan_text}b_cyan_text${reset_text}"
    tM_log="${b_cyan_text}b_cyan_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	# ${b_white_text}
    tM_msg="${b_white_text}b_white_text${reset_text}"
    tM_log="${b_white_text}b_white_text${reset_text}"
	tModeDebug "2" "${tM_msg}"
	exit 0
}

Showstart() {
	# scriptname and version
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣${reset_text}               ${b_green_text}${prg_name}${reset_text} ${b_white_text}${script_version}${reset_text}                  ${blue_text}⏣${reset_text}"
    tM_log="${prg_name} ${script_version}"
	tModeDebug "0" "${tM_msg}" "${tM_log}"
    tM_msg="${blue_text}⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣${reset_text}"
    tM_log="⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣⏣"
	tModeDebug "0" "${tM_msg}" "${tM_log}"

	# debug: used settings header
    tM_msg="${bold_text}${green_text}used settings${reset_text}"
    tM_log="used settings"
	tModeDebug "2" "${tM_msg}"
    tM_msg="${bold_text}${green_text}===========================${reset_text}"
    tM_log="==========================="
	tModeDebug "2" "${tM_msg}"
	
	# debug: dirlist
    tM_msg="${bold_text}${green_text}--dirlist=$dirlist${reset_text}"
    tM_log="--dirlist=$dirlist"
	tModeDebug "2" "${tM_msg}"
	
	# debug: maxdepth
    tM_msg="${bold_text}${green_text}--maxdepth=${maxdepth} subfolder depth${reset_text}"
    tM_log="--maxdepth=${maxdepth} subfolder depth"
	tModeDebug "2" "${tM_msg}"
	
	# debug: toggle
    tM_msg="${bold_text}${green_text}--toggle=${interval} seconds${reset_text}"
    tM_log="--toggle=${interval} seconds"
	tModeDebug "2" "${tM_msg}"
	
	# debug: logfile
    tM_msg="${bold_text}${green_text}--logfile=${logfile}${reset_text}"
    tM_log="--logfile=${logfile}"
	tModeDebug "2" "${tM_msg}"
}

DisplayHelp() {
Showstart
    cat << EOM
::: HELP =================================================================================================
:::   wallpaper_diashow.sh is a helper tool for hydrapaper!
:::
::: USAGE ================================================================================================
:::   ./wallpaper_diashow.sh [OPTIONS] [PARAMETERS]
:::   ./wallpaper_diashow.sh --verbose --path=<path_to_wallpapers> --toggle=[num] --logfile=<path_with_logfile>
:::   ./wallpaper_diashow.sh --daemon --path=<path_to_wallpapers> --toggle=[num] --logfile=<path_with_logfile>
:::   ./wallpaper_diashow.sh --version 
:::   ./wallpaper_diashow.sh --help 
:::
::: Options ==============================================================================================
:::   -D,--daemon					DaemonMode (Start script as a Service)
:::   -V,--verbose					VerboseMode (Show what this script do)
:::	  -d,--debug						debugMode (Show debug messages)
:::	  -s,--silent					silentMode (Show nothing - log on file only)
:::	  --lognocolor|--lnc 			no color in logfile
:::
::: PARAMETERS ==============================================================================================
:::   --dirlist=<path/file.log>		set the dirlisrfile with path*
:::									 *contain pathes to one or more wallpaper folders
::: 
:::   -m=[num],--maxdepth=[num]		set the depth of included subfolders
:::   -t=[num],--toggle=[num]		set the interval in seconds to toggle the wallpaper
:::   --logfile=<path/file.txt>		set the logfile with path!
:::
::: Options *cannot be combined with other options* ======================================================
:::   --colortest           			show output-color-examples
:::   -v, --version           		show wallpaper_diashow.sh version info
:::   -h, --help              		display this help text
:::
::: Default settings
======================================================
::: --dirlist=${HOME}/.config/wallpaper_diashow/dirlist.txt
::: --maxdepth=1
::: --toggle=30
::: --logfile=${HOME}/.local/var/log/wallpaper_diashow/wallpaper_diashow.log

EOM
}

main(){
	trap cleanup SIGTERM SIGINT

    Showstart
	diagnose_dell_hwmon
	resolve_paths
	check_hardware_files
	runTest
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
        --colortest)
          ShowColors
          exit 0
          ;;
        --logfile=*)
          logfile="${i#*=}"
          shift # past argument=value
          ;;
        --logoff)
          logoff=1
          ;;
        -f=*|--testfan=*) 
          testfan="${i#*=}"
          shift # past argument=value
          ;;
        -p=*|--testpause=*) 
          testpause="${i#*=}"
          shift # past argument=value
          ;;
        -s=*|--startpwm=*) 
          startpwm="${i#*=}"
          shift # past argument=value
          ;;
        -r=*|--runs=*) 
          runs="${i#*=}"
          shift # past argument=value
          ;;
        -e=*|--endpwm=*) 
          endpwm="${i#*=}"
          shift # past argument=value
          ;;
        *)
          ;;
    esac
    #shift
done

main

