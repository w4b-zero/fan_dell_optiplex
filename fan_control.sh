#!/bin/bash

# Configuración de logging para systemd
LOG_TAG="fan_control"

# Define los umbrales de temperatura en Celsius para mapeo suave
MIN_TEMP=30
MAX_TEMP=60
CRITICAL_TEMP=80  # Temperatura crítica para protección

# Define los valores PWM mínimo y máximo
MIN_PWM=60
MAX_PWM=255

# Hystéresis para evitar oscilaciones
TEMP_HYSTERESIS=2

# Configuración para protección térmica agresiva
TEMP_RISE_THRESHOLD=3  # Si sube más de 3°C en una lectura, activar protección
EMERGENCY_PWM=255      # PWM de emergencia

# Define las rutas a los archivos de hardware (se resolverán desde globs al iniciar)
GET_CPU_TEMP_FILE=""
SET_FAN_SPEED_FILE=""

# Resuelve globs a rutas concretas y asigna a las variables anteriores
resolve_paths() {
    # Habilita nullglob para que los patrones que no coincidan se expandan a nada
    shopt -s nullglob

    local temp_candidates=(/sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)
    if (( ${#temp_candidates[@]} == 0 )); then
        log_message "ERROR: No se encontró /temp1_input en coretemp hwmon (buscando: /sys/devices/platform/coretemp.0/hwmon/hwmon*/temp1_input)"
        exit 1
    fi
    GET_CPU_TEMP_FILE="${temp_candidates[0]}"

    # Verificar si dell_smm_hwmon está disponible y funcional
    local pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
    local fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
    
    if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
        log_message "WARN: dell_smm_hwmon no expone archivos de ventilador - intentando recargar módulo con force=1 restricted=0"
        
        # Mostrar estado actual del módulo
        if dmesg | tail -5 | grep -q "dell_smm_hwmon"; then
            log_message "INFO: Últimos mensajes del módulo: $(dmesg | grep dell_smm_hwmon | tail -2 | tr '\n' ' ')"
        fi
        
        modprobe -r dell_smm_hwmon 2>/dev/null || true
        sleep 2
        modprobe dell_smm_hwmon force=1 restricted=0 2>/dev/null || true
        sleep 3
        
        # Verificar de nuevo tras recarga
        pwm_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/pwm1)
        fan_candidates=(/sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/fan1_input)
        
        if (( ${#pwm_candidates[@]} == 0 )) && (( ${#fan_candidates[@]} == 0 )); then
            log_message "ERROR: EC/BIOS bloqueó acceso a control de ventilador. Archivos disponibles:"
            if ls /sys/devices/platform/dell_smm_hwmon/hwmon/hwmon*/ 2>/dev/null | grep -v "device\|power\|subsystem\|uevent" | head -5; then
                log_message "INFO: Solo sensors de temperatura disponibles. Para recuperar control PWM: apagado completo (no reinicio)"
            fi
            SET_FAN_SPEED_FILE=""
        else
            SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
            log_message "SUCCESS: Control PWM recuperado tras recarga del módulo"
        fi
    elif (( ${#pwm_candidates[@]} > 0 )); then
        SET_FAN_SPEED_FILE="${pwm_candidates[0]}"
        log_message "SUCCESS: Control PWM disponible desde inicio"
    else
        log_message "WARN: dell_smm_hwmon parcialmente funcional - solo lecturas disponibles"
        SET_FAN_SPEED_FILE=""
    fi

    # Restaurar comportamiento por defecto
    shopt -u nullglob

    log_message "Usando temp file: $GET_CPU_TEMP_FILE"
    if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
        log_message "Usando pwm file: $SET_FAN_SPEED_FILE"
    else
        log_message "MODO SOLO MONITOREO: Sin control PWM (EC/BIOS bloqueó acceso)"
    fi
}

# Variable para almacenar el PWM anterior
previous_pwm=$MIN_PWM
previous_temp=0

# Función para logging compatible con systemd
log_message() {
    # Solo usar logger para no contaminar la salida de comandos sustituidos
    logger -t "$LOG_TAG" "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Función para calcular PWM basado en temperatura con protección térmica
calculate_pwm() {
    local temp=$1
    local temp_diff=$2
    local pwm
    
    # Protección crítica: si temperatura >= 80°C, máximo inmediato
    if (( temp >= CRITICAL_TEMP )); then
        log_message "CRITICAL: Temperatura crítica ${temp}°C, PWM máximo"
        echo $MAX_PWM
        return
    fi
    
    # Protección predictiva: si temperatura sube rápidamente (>3°C), PWM agresivo
    if (( temp_diff > TEMP_RISE_THRESHOLD )); then
        # Calcula PWM agresivo: asume que la temperatura seguirá subiendo
        local predicted_temp=$((temp + temp_diff * 2))  # Predice temperatura en próximos 2 ciclos
        if (( predicted_temp > MAX_TEMP )); then
            predicted_temp=$MAX_TEMP
        fi
        pwm=$(( (predicted_temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
        if (( pwm > MAX_PWM )); then pwm=$MAX_PWM; fi
        log_message "PREDICTIVE: Subida rápida +${temp_diff}°C, PWM agresivo: ${pwm}"
        echo $pwm
        return
    fi
    
    # Mapeo normal para cambios graduales
    if (( temp <= MIN_TEMP )); then
        pwm=$MIN_PWM
    elif (( temp >= MAX_TEMP )); then
        pwm=$MAX_PWM
    else
        # Mapeo lineal suave entre MIN_TEMP y MAX_TEMP
        pwm=$(( (temp - MIN_TEMP) * (MAX_PWM - MIN_PWM) / (MAX_TEMP - MIN_TEMP) + MIN_PWM ))
    fi
    
    echo $pwm
}

# Función para verificar archivos de hardware
check_hardware_files() {
    if [[ ! -r $GET_CPU_TEMP_FILE ]]; then
        log_message "ERROR: No se puede leer archivo de temperatura: $GET_CPU_TEMP_FILE"
        exit 1
    fi
    
    # Solo verificar PWM si está disponible
    if [[ -n "$SET_FAN_SPEED_FILE" ]] && [[ ! -w $SET_FAN_SPEED_FILE ]] && [[ $EUID -ne 0 ]]; then
        log_message "ERROR: No se puede escribir archivo PWM: $SET_FAN_SPEED_FILE (ejecutar como root)"
        exit 1
    fi
}

# Función de limpieza al salir
cleanup() {
    log_message "Recibida señal de terminación, restaurando ventilador a automático"
    # Opcional: restaurar ventilador a modo automático
    exit 0
}

# Función para diagnosticar estado del dell_smm_hwmon
diagnose_dell_hwmon() {
    log_message "=== DIAGNÓSTICO DELL_SMM_HWMON ==="
    
    # Verificar si el módulo está cargado
    if lsmod | grep -q dell_smm_hwmon; then
        log_message "INFO: Módulo dell_smm_hwmon cargado"
    else
        log_message "WARN: Módulo dell_smm_hwmon NO cargado"
        return
    fi
    
    # Verificar archivos disponibles
    if [[ -d "/sys/devices/platform/dell_smm_hwmon/hwmon" ]]; then
        local hwmon_dir=$(find /sys/devices/platform/dell_smm_hwmon/hwmon -name "hwmon*" -type d | head -1)
        if [[ -n "$hwmon_dir" ]]; then
            local available_files=$(ls "$hwmon_dir" 2>/dev/null | grep -E "temp|fan|pwm" | tr '\n' ' ')
            log_message "INFO: Archivos disponibles: $available_files"
            
            # Verificar específicamente PWM y fan
            if ls "$hwmon_dir"/pwm* >/dev/null 2>&1; then
                log_message "SUCCESS: Archivos PWM encontrados - control disponible"
            elif ls "$hwmon_dir"/fan* >/dev/null 2>&1; then
                log_message "PARTIAL: Solo archivos fan - sin control PWM"
            else
                log_message "LIMITED: Solo sensores temperatura - EC bloqueó ventiladores"
            fi
        fi
    else
        log_message "ERROR: Directorio dell_smm_hwmon no encontrado"
    fi
    
    log_message "=== FIN DIAGNÓSTICO ==="
}

# Capturar señales para limpieza
trap cleanup SIGTERM SIGINT

log_message "Iniciando control de ventilador suave"
diagnose_dell_hwmon
resolve_paths
check_hardware_files

# La lógica del script se ejecutará en un bucle infinito
while true; do
    # Lee la temperatura actual en mili-Celsius y la convierte a Celsius
    current_cpu_temp=$(($(cat "$GET_CPU_TEMP_FILE") / 1000))
    
    # Calcula la diferencia de temperatura desde la última lectura
    temp_diff=$((current_cpu_temp - previous_temp))
    if (( temp_diff < 0 )); then temp_diff=0; fi  # Solo nos interesan las subidas
    
    # Calcula el PWM con protección térmica
    target_pwm=$(calculate_pwm $current_cpu_temp $temp_diff)
    
    # Aplica histéresis para evitar cambios frecuentes (excepto en emergencias)
    pwm_diff=$((target_pwm - previous_pwm))
    if (( pwm_diff < 0 )); then
        pwm_diff=$((-pwm_diff))
    fi
    
    # Condiciones para cambiar PWM:
    # - Diferencia significativa (>10)
    # - Estaba en mínimo
    # - Temperatura crítica o subida rápida (emergencia)
    emergency_condition=$((current_cpu_temp >= CRITICAL_TEMP || temp_diff > TEMP_RISE_THRESHOLD))
    
    if (( pwm_diff > 10 )) || (( previous_pwm == MIN_PWM )) || (( emergency_condition )); then
        # Solo escribir PWM si está disponible
        if [[ -n "$SET_FAN_SPEED_FILE" ]]; then
            echo "$target_pwm" > "$SET_FAN_SPEED_FILE"
            log_message "Temp: ${current_cpu_temp}°C (Δ+${temp_diff}°C), PWM: ${target_pwm} (prev: ${previous_pwm})"
        else
            log_message "Temp: ${current_cpu_temp}°C (Δ+${temp_diff}°C), PWM: ${target_pwm} (SIN CONTROL - solo monitoreo)"
        fi
        previous_pwm=$target_pwm
    fi
    
    previous_temp=$current_cpu_temp

    # Intervalo más agresivo: 2 segundos para detección rápida
    sleep 2
done
