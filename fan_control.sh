#!/bin/bash

# Protokollierungseinstellungen für systemd
LOG_TAG="fan_control"

# Definiert Temperaturschwellen in Celsius für reibungslose Kartierung
MIN_TEMP=30
MAX_TEMP=60
CRITICAL_TEMP=80  # Kritische Temperatur für den Schutz

# Definiere die minimalen und maximalen PWM-Werte
MIN_PWM=60
MAX_PWM=255

# Hysterese zur Verhinderung von Schwingungen
TEMP_HYSTERESIS=2

# Aggressive Wärmeschutzeinstellungen
TEMP_RISE_THRESHOLD=3  # Wenn die Temperatur bei einer Messung um mehr als 3°C ansteigt, wird der Schutz aktiviert.
EMERGENCY_PWM=255      # Notfall-PWM

# Definiert die Pfade zu den Hardware-Dateien (diese werden beim Start anhand von Glob-Mustern aufgelöst)
GET_CPU_TEMP_FILE=""
SET_FAN_SPEED_FILE=""

# Glob-Muster in spezifische Routen auflösen und den vorherigen Variablen zuweisen
resolve_paths() {
    # Aktiviert Nullglob, damit nicht übereinstimmende Muster zu Nichts erweitert werden.
    shopt -s nullglob

    local temp_candidates=(/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
    if (( ${#temp_candidates[@]} == 0 )); then
        log_message "FEHLER: /temp1_input wurde in coretemp hwmon nicht gefunden (Suche: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)"
        exit 1
    fi
    GET_CPU_TEMP_FILE="${temp_candidates[0]}"

    # Prüfen, ob dell_smm_hwmon verfügbar und funktionsfähig ist
    local pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
    local fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
    
    if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
        log_message "WARNUNG: dell_smm_hwmon stellt keine Lüfterdateien bereit - Versuch, das Modul mit force=1 restricted=0 neu zu laden"
        
        # Aktuellen Modulstatus anzeigen
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
            log_message "INFO: Letzte Meldungen vom Modul: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
        fi
        
        modprobe -r dell_smm_hwmon 2>/dev/null || true
        sleep 2
        modprobe dell_smm_hwmon force=1 restricted=0 2>/dev/null || true
        sleep 3
        
        # Nach dem Aufladen erneut prüfen.
        pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
        fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
        
        if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
            log_message "FEHLER: EC/BIOS hat den Zugriff auf die Lüftersteuerung blockiert. Verfügbare Dateien:"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
                log_message "INFO: Nur Temperatursensoren verfügbar. Um die PWM-Steuerung wiederzuerlangen: Vollständiges Herunterfahren (kein Neustart)"
            fi
            SET_FAN_SPEED_FILE=""
        else
            SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
            log_message "ERFOLG: PWM-Steuerung nach Modulaufladung wiederhergestellt"
        fi
    elif (( ${#pwm_candidates[@]} > 0 )); then
        SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
        log_message "ERFOLG: PWM-Steuerung ab Start verfügbar"
    else
        log_message "WARNUNG: dell_smm_hwmon nur teilweise funktionsfähig - nur Lesezugriffe verfügbar"
        SET_FAN_SPEED_FILE=""
    fi

    # Standardverhalten wiederherstellen
    shopt -u nullglob

    log_message "Verwende temporäre Datei: $GET_CPU_TEMP_FILE"
    if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
        log_message "Verwende PWM-Datei: $SET_FAN_SPEED_FILE"
    else
        log_message "NUR-ÜBERWACHUNGSMODUS: Keine PWM-Steuerung (EC/BIOS-Zugriff blockiert)"
    fi
}

# Variable zum Speichern des vorherigen PWM-Signals
previous_pwm=$MIN_PWM
previous_temp=0

# Funktion für mit systemd kompatibles Logging
log_message() {
    # Verwenden Sie ausschließlich den Logger, um zu vermeiden, dass die Ausgabe durch ersetzte Befehle verfälscht wird.
    logger -t "$LOG_TAG" "$(date '+%Y-%m-%d %H:%M:%S') - $1"
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
        log_message "FEHLER: Temperaturdatei konnte nicht gelesen werden: $GET_CPU_TEMP_FILE"
        exit 1
    fi
    
    # PWM nur prüfen, falls verfügbar
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ ! -w $SET_FAN_SPEED_FILE ]] && [[ $EUID -ne 0 ]]; then
        log_message "FEHLER: PWM-Datei konnte nicht geschrieben werden: $SET_FAN_SPEED_FILE (als Root ausführen)"
        exit 1
    fi
}

# Ausgangsreinigungsfunktion
cleanup() {
    log_message "Abbruchsignal empfangen, Lüfter wieder auf Automatikbetrieb"
    # Optional: Lüfter wieder in den Automatikmodus versetzen
    exit 0
}

# Funktion zur Diagnose des Status des dell_smm_hwmon
diagnose_dell_hwmon() {
    log_message "=== DELL_SMM_HWMON DIAGNOSE ==="
    
    # Prüfen, ob das Modul geladen ist
    if lsmod | grep -q dell_smm_hwmon; then
        log_message "INFO: dell_smm_hwmon-Modul geladen"
    else
        log_message "WARNUNG: dell_smm_hwmon-Modul NICHT geladen"
        return
    fi
    
    # Verfügbare Dateien prüfen
    if [[ -d "/sys/devices/platform/dell_smm_hwmon/hwmon" ]]; then
        local hwmon_dir=$(find /sys/devices/platform/dell_smm_hwmon/hwmon -name "hwmon*" -type d | head -1)
        if [[ -n "$hwmon_dir" ]]; then
            local available_files=$(ls "$hwmon_dir" 2>/dev/null | grep -E "temp|fan|pwm" | tr '\n' ' ')
            log_message "INFO: Verfügbare Dateien: $available_files"
            
            # Überprüfen Sie insbesondere PWM und Lüfter
            if ls "$hwmon_dir"/pwm* >/dev/null 2>&1; then
                log_message "ERFOLG: PWM-Dateien gefunden - Steuerung verfügbar"
            elif ls "$hwmon_dir"/fan* >/dev/null 2>&1; then
                log_message "TEILWEISE: Nur Lüfterdateien - keine PWM-Steuerung"
            else
                log_message "BEGRENZT: Nur Temperatursensoren - EC blockierte Lüfter"
            fi
        fi
    else
        log_message "FEHLER: Verzeichnis dell_smm_hwmon nicht gefunden"
    fi
    
    log_message "=== ENDE DER DIAGNOSE ==="
}

# Signale zur Reinigung erfassen
trap cleanup SIGTERM SIGINT

log_message "Starte Soft-Lüftersteuerung"
diagnose_dell_hwmon
resolve_paths
check_hardware_files

# Die Skriptlogik wird in einer Endlosschleife ausgeführt.
while true; do
    # Liest die aktuelle Temperatur in Milli-Celsius und rechnet sie in Celsius um.
    current_cpu_temp=$(($(cat "$GET_CPU_TEMP_FILE") / 1000))
    
    # Berechne die Temperaturdifferenz zum letzten Messwert
    temp_diff=$((current_cpu_temp - previous_temp))
    if (( temp_diff < 0 )); then temp_diff=0; fi  # Solo nos interesan las subidas
    
    # PWM mit thermischem Schutz berechnen
    target_pwm=$(calculate_pwm $current_cpu_temp $temp_diff)
    
    # Hysterese anwenden, um häufige Änderungen zu vermeiden (außer in Notfällen)
    pwm_diff=$((target_pwm - previous_pwm))
    if (( pwm_diff < 0 )); then
        pwm_diff=$((-pwm_diff))
    fi
    
    # Bedingungen für die Änderung der PWM:
    # - Signifikanter Unterschied (>10)
    # - Es war mindestens
    # - Kritische Temperatur oder rascher Temperaturanstieg (Notfall)
    emergency_condition=$((current_cpu_temp >= CRITICAL_TEMP || temp_diff > TEMP_RISE_THRESHOLD))
    
    if (( pwm_diff > 10 )) || (( previous_pwm == MIN_PWM )) || (( emergency_condition )); then
        # Nur PWM schreiben, falls verfügbar
        if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
            echo "$target_pwm" > "$SET_FAN_SPEED_FILE"
            log_message "Temp: ${current_cpu_temp}°C (Δ+${temp_diff}°C), PWM: ${target_pwm} (prev: ${previous_pwm})"
        else
            log_message "Temp: ${current_cpu_temp}°C (Δ+${temp_diff}°C), PWM: ${target_pwm} (KEINE KONTROLLE – nur Überwachung)"
        fi
        previous_pwm=$target_pwm
    fi
    
    previous_temp=$current_cpu_temp

    # Aggressives Intervall: 2 Sekunden für schnelle Erkennung
    sleep 2
done
    # Intervalo más agresivo: 2 segundos para detección rápida
    sleep 2
done
