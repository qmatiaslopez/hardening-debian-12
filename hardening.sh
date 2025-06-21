#!/usr/bin/env bash
# harden_debian12_cis.sh
#
# Script de seguridad para Debian 12 con dos modos:
# - Benchmark: Ejecuta auditoría de seguridad con Lynis
# - Hardening: Aplica endurecimiento CIS level1-server y configuraciones adicionales

set -euo pipefail

# --------------------------- Selección de modo -----------------------------
echo "Script de Seguridad para Debian 12"
echo "======================================"
echo ""
echo "Selecciona el modo de operación:"
echo "1) Benchmark - Auditoría de seguridad con Lynis"
echo "2) Hardening - Aplicar endurecimiento CIS y configuraciones adicionales"
echo ""

while true; do
    read -r -p "Ingresa tu opción (1 o 2): " mode_choice
    case $mode_choice in
        1)
            MODE="benchmark"
            echo "Modo seleccionado: Benchmark (Auditoría de seguridad)"
            break
            ;;
        2)
            MODE="hardening"
            echo "Modo seleccionado: Hardening (Endurecimiento del sistema)"
            break
            ;;
        *)
            echo "Opción inválida. Por favor ingresa 1 o 2."
            ;;
    esac
done

echo ""

# ========================== MODO BENCHMARK ==========================
if [[ "$MODE" == "benchmark" ]]; then
    echo "INICIANDO MODO BENCHMARK"
    echo "=========================="
    
    # Lista de paquetes instalados para benchmark
    BENCHMARK_PACKAGES=()
    
    # Verificar e instalar Lynis
    echo "Verificando instalación de Lynis..."
    if ! command -v lynis &> /dev/null; then
        echo "Lynis no está instalado. Instalando..."
        apt update
        apt install -y lynis
        BENCHMARK_PACKAGES+=("lynis")
        echo "Lynis instalado correctamente"
    else
        echo "Lynis ya está instalado"
        lynis --version
    fi
    
    echo ""
    echo "Ejecutando auditoría de seguridad completa del sistema..."
    echo "Esto puede tomar varios minutos dependiendo de la configuración del sistema"
    echo ""
    
    # Crear directorio para reportes si no existe
    mkdir -p /var/log/lynis-reports
    
    # Ejecutar Lynis con configuración optimizada para reporting
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    REPORT_FILE="/var/log/lynis-reports/lynis_report_${TIMESTAMP}.log"
    
    echo "Iniciando auditoría Lynis..."
    lynis audit system --quick --log-file "$REPORT_FILE" || true
    
    echo ""
    echo "RESUMEN DE LA AUDITORÍA COMPLETADA"
    echo "===================================="
    echo "Auditoría de seguridad completada"
    echo "Reportes disponibles en:"
    echo "   • Reporte detallado: $REPORT_FILE"
    echo "   • Log principal: /var/log/lynis.log"
    echo "   • Datos estructurados: /var/log/lynis-report.dat"
    echo ""
    echo "Para revisar los resultados:"
    echo "   • Ver resumen: lynis show report"
    echo "   • Ver sugerencias: grep 'suggestion\\|warning' $REPORT_FILE"
    echo "   • Ver índice de endurecimiento: grep -i 'hardening index' $REPORT_FILE"
    echo ""
    echo "Recomendación: Ejecuta este benchmark regularmente (mensual/trimestral)"
    echo "   para monitorear el estado de seguridad del sistema."
    
    # Cleanup para modo benchmark
    if [[ ${#BENCHMARK_PACKAGES[@]} -gt 0 ]]; then
        echo ""
        read -r -p "¿Quieres limpiar los paquetes instalados para el benchmark? (y/N): " cleanup_resp
        cleanup_resp=${cleanup_resp,,}
        
        if [[ "$cleanup_resp" == "y" || "$cleanup_resp" == "yes" || "$cleanup_resp" == "si" || "$cleanup_resp" == "s" ]]; then
            echo "Limpiando paquetes instalados: ${BENCHMARK_PACKAGES[*]}"
            apt remove -y "${BENCHMARK_PACKAGES[@]}"
            apt autoremove -y
            apt autoclean
            echo "Cleanup completado"
        fi
    fi
    
    exit 0
fi

# ========================== MODO HARDENING ==========================
echo "INICIANDO MODO HARDENING"
echo "=========================="

# Lista para rastrear paquetes instalados durante el hardening
INSTALLED_PACKAGES=()

# --------------------------- 0. Actualizar el sistema --------------------------
echo "0/6 – Actualizando Debian 12..."
apt update
apt full-upgrade -y
apt autoremove -y
echo "Sistema actualizado"

# -------------------- 1. Verificar e instalar los requisitos -------------------
echo "1/6 – Instalando requisitos (git, Ansible, Python, ACL...)..."

# Verificar qué paquetes necesitan instalarse
REQUIRED_PACKAGES=("git" "ansible" "python3" "python3-pip" "python3-apt" "acl" "lynis")
PACKAGES_TO_INSTALL=()

for package in "${REQUIRED_PACKAGES[@]}"; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        PACKAGES_TO_INSTALL+=("$package")
    fi
done

if [[ ${#PACKAGES_TO_INSTALL[@]} -gt 0 ]]; then
    echo "Instalando paquetes: ${PACKAGES_TO_INSTALL[*]}"
    apt install -y "${PACKAGES_TO_INSTALL[@]}"
    INSTALLED_PACKAGES+=("${PACKAGES_TO_INSTALL[@]}")
    echo "Paquetes instalados correctamente"
else
    echo "Todos los paquetes requeridos ya están instalados"
fi

# ------------------- 1b. Clonar o actualizar el rol CIS ------------------------
REPO_DIR="/tmp/DEBIAN12-CIS"
if [[ -d "$REPO_DIR/.git" ]]; then
  echo "El repositorio ya existe, actualizando..."
  git -C "$REPO_DIR" pull --ff-only
else
  echo "Clonando ansible-lockdown/DEBIAN12-CIS..."
  git clone https://github.com/ansible-lockdown/DEBIAN12-CIS.git "$REPO_DIR"
fi

# --------------- 1c. Instalar colecciones Galaxy que exige el rol --------------
echo "Instalando dependencias de Ansible Galaxy..."
ansible-galaxy collection install \
  -r "$REPO_DIR/collections/requirements.yml" \
  --force

# ------------ 2. Crear playbook envoltorio y lanzar level1-server --------------
echo "2/6 – Creando playbook y ejecutando controles level1-server..."
PLAYBOOK="/tmp/debian12_cis_wrapper.yml"
cat > "$PLAYBOOK" <<'EOF'
- name: Endurecimiento CIS Debian 12 (level1-server)
  hosts: localhost
  gather_facts: yes
  become: yes
  roles:
    - role: DEBIAN12-CIS
EOF

export ANSIBLE_ROLES_PATH="/tmp"
ansible-playbook "$PLAYBOOK" --tags level1-server

# ---- 3. Configurar SSH para requerir clave privada Y contraseña ---------------
read -r -p "¿Quieres configurar SSH para requerir clave privada Y contraseña? (y/N): " resp
resp=${resp,,}

if [[ "$resp" == "y" || "$resp" == "yes" || "$resp" == "si" || "$resp" == "s" ]]; then
  echo "3/6 – Configurando SSH para autenticación dual (clave + contraseña)..."
  
  # Hacer backup del archivo de configuración
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
  echo "Backup creado en /etc/ssh/sshd_config.backup"
  
  # Configurar SSH para requerir tanto clave pública como contraseña
  echo "Configurando autenticación dual en SSH..."
  
  # Habilitar autenticación por clave pública
  sed -i 's/^#\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
  
  # Habilitar autenticación por contraseña
  sed -i 's/^#\?PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  
  # Deshabilitar contraseñas vacías
  sed -i 's/^#\?PermitEmptyPasswords .*/PermitEmptyPasswords no/' /etc/ssh/sshd_config
  
  # Habilitar PAM
  sed -i 's/^#\?UsePAM .*/UsePAM yes/' /etc/ssh/sshd_config
  
  # Configurar métodos de autenticación para requerir AMBOS
  if grep -q "^AuthenticationMethods" /etc/ssh/sshd_config; then
    sed -i 's/^AuthenticationMethods .*/AuthenticationMethods "publickey,password"/' /etc/ssh/sshd_config
  else
    echo 'AuthenticationMethods "publickey,password"' | tee -a /etc/ssh/sshd_config > /dev/null
  fi
  
  # Verificar configuración antes de reiniciar
  if sshd -t; then
    echo "Configuración SSH válida"
    systemctl restart ssh
    echo "Servicio SSH reiniciado"
    
    echo "SSH configurado para requerir TANTO clave privada COMO contraseña"
    echo "IMPORTANTE: Mantén esta sesión abierta y prueba la conexión desde otro terminal"
    echo "para verificar que puedes acceder antes de cerrar esta sesión."
    echo "Necesitarás tanto tu clave privada como la contraseña del usuario."
  else
    echo "Error en la configuración SSH. Restaurando backup..."
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    systemctl restart ssh
    echo "Configuración restaurada"
  fi
else
  echo "3/6 – Se omite la configuración de SSH."
fi

# ---- 4. Configurar monitoreo de archivos críticos con auditd ------------------
read -r -p "¿Quieres configurar monitoreo de archivos críticos con auditd? (y/N): " audit_resp
audit_resp=${audit_resp,,}

if [[ "$audit_resp" == "y" || "$audit_resp" == "yes" || "$audit_resp" == "si" || "$audit_resp" == "s" ]]; then
  echo "4/6 – Configurando monitoreo de archivos críticos con auditd..."
  
  # Verificar e instalar auditd si no está instalado
  AUDIT_PACKAGES=("auditd" "audispd-plugins")
  AUDIT_TO_INSTALL=()
  
  for package in "${AUDIT_PACKAGES[@]}"; do
      if ! dpkg -l | grep -q "^ii  $package "; then
          AUDIT_TO_INSTALL+=("$package")
      fi
  done
  
  if [[ ${#AUDIT_TO_INSTALL[@]} -gt 0 ]]; then
      echo "Instalando auditd: ${AUDIT_TO_INSTALL[*]}"
      apt install -y "${AUDIT_TO_INSTALL[@]}"
      INSTALLED_PACKAGES+=("${AUDIT_TO_INSTALL[@]}")
  fi
  
  # Habilitar y iniciar auditd
  systemctl enable auditd
  systemctl start auditd
  
  # Crear archivo de reglas permanentes para archivos críticos
  AUDIT_RULES="/etc/audit/rules.d/critical-files.rules"
  echo "Creando reglas de auditoría permanentes..."
  
  tee "$AUDIT_RULES" > /dev/null <<'EOF'
# Eliminar reglas anteriores
-D

# Configuración básica del buffer
-b 8192

# Archivos de usuarios más críticos
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes

# Configuración de privilegios administrativos
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d/ -p wa -k sudoers_changes

# SSH - acceso remoto crítico
-w /etc/ssh/sshd_config -p wa -k ssh_config

# Configuración de red básica
-w /etc/hosts -p wa -k hosts_changes

# Hacer la configuración inmutable (requiere reinicio para cambios)
-e 2
EOF

  echo "Reglas de auditoría creadas en $AUDIT_RULES"
  
  # Reiniciar auditd para aplicar las reglas
  echo "Aplicando reglas de auditoría..."
  systemctl restart auditd
  
  # Verificar que las reglas están activas
  if auditctl -l &> /dev/null; then
    echo "Auditd configurado correctamente"
    echo "Archivos monitoreados:"
    echo "   • /etc/passwd, /etc/shadow, /etc/group (usuarios)"
    echo "   • /etc/sudoers y /etc/sudoers.d/ (privilegios)"
    echo "   • /etc/ssh/sshd_config (SSH)"
    echo "   • /etc/hosts (red)"
  else
    echo "Advertencia: Hubo un problema configurando auditd"
  fi
else
  echo "4/6 – Se omite la configuración de auditd."
fi

# ---- 5. Configurar Fail2ban con protección avanzada contra reintentos ---------
read -r -p "¿Quieres configurar Fail2ban con protección avanzada contra ataques SSH? (y/N): " fail2ban_resp
fail2ban_resp=${fail2ban_resp,,}

if [[ "$fail2ban_resp" == "y" || "$fail2ban_resp" == "yes" || "$fail2ban_resp" == "si" || "$fail2ban_resp" == "s" ]]; then
  echo "5/6 – Configurando Fail2ban con protección avanzada..."
  
  # Verificar e instalar fail2ban y dependencias
  FAIL2BAN_PACKAGES=("fail2ban" "iptables" "python3-systemd")
  FAIL2BAN_TO_INSTALL=()
  
  for package in "${FAIL2BAN_PACKAGES[@]}"; do
      if ! dpkg -l | grep -q "^ii  $package "; then
          FAIL2BAN_TO_INSTALL+=("$package")
      fi
  done
  
  if [[ ${#FAIL2BAN_TO_INSTALL[@]} -gt 0 ]]; then
      echo "Instalando Fail2ban: ${FAIL2BAN_TO_INSTALL[*]}"
      apt install -y "${FAIL2BAN_TO_INSTALL[@]}"
      INSTALLED_PACKAGES+=("${FAIL2BAN_TO_INSTALL[@]}")
  fi
  
  # Crear configuración personalizada
  echo "Creando configuración de Fail2ban..."
  tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[DEFAULT]
# Configuración global
backend = systemd
bantime = 600
findtime = 60
maxretry = 5

# Configuración de notificaciones (opcional)
destemail = root@localhost
sender = fail2ban@localhost
action = %(action_mw)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
findtime = 60
bantime = 600

[recidive]
# Jail especial para IPs que reinciden múltiples veces
# Bloquea por 24 horas después de 3 bloqueos previos
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
banaction = iptables-allports
bantime = 86400
findtime = 86400
maxretry = 3
EOF

  echo "Configuración de Fail2ban creada"
  
  # Habilitar y iniciar fail2ban
  echo "Habilitando e iniciando Fail2ban..."
  systemctl enable fail2ban
  systemctl start fail2ban
  
  # Verificar el estado
  sleep 3
  if systemctl is-active --quiet fail2ban; then
    echo "Fail2ban iniciado correctamente"
    
    # Mostrar estado de los jails
    echo "Estado de los jails configurados:"
    fail2ban-client status 2>/dev/null || echo "   • Servicio iniciándose..."
    
    echo ""
    echo "Fail2ban configurado con:"
    echo "   • SSH: Bloqueo de 10 minutos tras 5 intentos fallidos en 1 minuto"
    echo "   • Recidive: Bloqueo de 24 horas tras 3 bloqueos previos en 24 horas"
    echo "   • Logs disponibles en /var/log/fail2ban.log para SIEM"
  else
    echo "Advertencia: Hubo un problema iniciando Fail2ban"
    echo "Verificando configuración..."
    fail2ban-client --test 2>&1 || echo "Error en la configuración"
  fi
else
  echo "5/6 – Se omite la configuración de Fail2ban."
fi

# ---- 6. Ejecutar auditoría final con Lynis (opcional) -------------------------
read -r -p "¿Quieres ejecutar una auditoría final con Lynis para verificar los cambios? (y/N): " lynis_final_resp
lynis_final_resp=${lynis_final_resp,,}

if [[ "$lynis_final_resp" == "y" || "$lynis_final_resp" == "yes" || "$lynis_final_resp" == "si" || "$lynis_final_resp" == "s" ]]; then
  echo "Ejecutando auditoría final con Lynis..."
  
  # Crear reporte post-hardening
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
  FINAL_REPORT="/var/log/lynis-reports/post_hardening_${TIMESTAMP}.log"
  mkdir -p /var/log/lynis-reports
  
  echo "Iniciando auditoría post-endurecimiento..."
  lynis audit system --quick --log-file "$FINAL_REPORT" || true
  
  echo "Auditoría final completada"
  echo "Reporte post-endurecimiento disponible en: $FINAL_REPORT"
else
  echo "Se omite la auditoría final."
fi

echo "Endurecimiento CIS (level1-server) completado con éxito."

# ---- 7. Cleanup de paquetes instalados durante el script ---------------------
if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    echo ""
    echo "CLEANUP DE PAQUETES"
    echo "==================="
    echo "Los siguientes paquetes se instalaron durante la ejecución del script:"
    printf '   • %s\n' "${INSTALLED_PACKAGES[@]}"
    echo ""
    read -r -p "¿Quieres mantener estos paquetes instalados? (Y/n): " keep_packages_resp
    keep_packages_resp=${keep_packages_resp,,}
    
    if [[ "$keep_packages_resp" == "n" || "$keep_packages_resp" == "no" ]]; then
        echo "Removiendo paquetes instalados durante el script..."
        apt remove -y "${INSTALLED_PACKAGES[@]}"
        echo "Limpiando dependencias no utilizadas..."
        apt autoremove -y
        apt autoclean
        echo "Cleanup de paquetes completado"
    else
        echo "Manteniendo paquetes instalados"
        echo "Para limpiar dependencias no utilizadas ejecuta: apt autoremove"
    fi
else
    echo ""
    echo "No se instalaron paquetes nuevos durante la ejecución"
    echo "Limpiando dependencias no utilizadas..."
    apt autoremove -y
    apt autoclean
fi

# ---- 8. Cleanup de archivos temporales ----------------------------------------
echo ""
echo "Limpiando archivos temporales..."
rm -rf "$REPO_DIR" 2>/dev/null || true
rm -f "$PLAYBOOK" 2>/dev/null || true
echo "Archivos temporales eliminados"

# ---- 9. Pregunta de reinicio del sistema --------------------------------------
echo ""
echo "Algunos cambios pueden requerir un reinicio del sistema para ser completamente efectivos."
read -r -p "¿Quieres reiniciar el sistema ahora? (y/N): " reboot_resp
reboot_resp=${reboot_resp,,}

if [[ "$reboot_resp" == "y" || "$reboot_resp" == "yes" || "$reboot_resp" == "si" || "$reboot_resp" == "s" ]]; then
  echo "Reiniciando el sistema en 10 segundos..."
  echo "Presiona Ctrl+C para cancelar"
  sleep 10
  reboot
else
  echo "Reinicio omitido. Considera reiniciar manualmente más tarde."
  echo "Para aplicar completamente todas las configuraciones, ejecuta: reboot"
fi
