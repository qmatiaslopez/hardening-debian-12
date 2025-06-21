# 🔒 Debian 12 CIS Security Hardening Script

🛡️ Un script automatizado de endurecimiento de seguridad para Debian 12 que implementa controles del estándar CIS (Center for Internet Security) junto con configuraciones adicionales de seguridad. Ofrece dos modos de operación: auditoría de seguridad (benchmark) y aplicación de medidas de endurecimiento (hardening).

## 📖 Descripción

Este script proporciona una solución integral para mejorar la postura de seguridad de servidores Debian 12 mediante la aplicación automatizada de controles de seguridad reconocidos internacionalmente. Combina la flexibilidad de Ansible con la robustez de las recomendaciones CIS para ofrecer tanto capacidades de evaluación como de endurecimiento.

**🚀 Funcionalidades principales:**

- **📊 Modo Benchmark**: Ejecuta auditorías completas de seguridad utilizando Lynis para evaluar el estado actual del sistema
- **🔧 Modo Hardening**: Aplica automáticamente más de 100 controles CIS level1-server junto con configuraciones adicionales de seguridad
- **🔐 Configuración SSH avanzada**: Implementa autenticación dual (clave privada + contraseña) para máxima seguridad
- **👀 Monitoreo de archivos críticos**: Configura auditd para detectar modificaciones no autorizadas en archivos sensibles
- **🛡️ Protección contra ataques de fuerza bruta**: Instala y configura Fail2ban con reglas anti-recidiva
- **🧹 Limpieza automática**: Opción de limpiar paquetes instalados durante la ejecución

## 🖥️ Requisitos del Sistema

**💿 Sistema operativo soportado:**
- Debian 12 (Bookworm) - Tested ✅

**⚙️ Configuración de prueba:**
- Sistema con partición única para el sistema completo
- Instalación mínima con únicamente SSH habilitado
- Sin utilidades del sistema adicionales instaladas

**🔑 Privilegios requeridos:**
- Acceso root directo (el script maneja las elevaciones de privilegios internamente)
- 🌐 Conexión a Internet para descargar dependencias

## 📥 Instalación y Uso

### 🔽 Descarga del Script

```bash
wget https://raw.githubusercontent.com/qmatiaslopez/hardening-debian-12/refs/heads/main/hardening.sh
chmod +x hardening.sh
```

### ▶️ Ejecución

**🎯 Ejecuta directamente como root:**

```bash
./hardening.sh
```

### 📊 Modo Benchmark

Ejecuta una auditoría completa del sistema sin realizar cambios. Los reportes se guardan en `/var/log/lynis-reports/` con timestamp para facilitar el seguimiento histórico.

**🎯 Casos de uso:**
- Evaluación inicial de seguridad
- Auditorías periódicas de cumplimiento
- Verificación post-hardening

### 🔧 Modo Hardening

Aplica automáticamente las configuraciones de seguridad. Durante la ejecución, el script solicitará confirmación para:
- 🔐 Configuración de SSH con autenticación dual
- 👁️ Habilitación de monitoreo con auditd
- 🛡️ Instalación y configuración de Fail2ban
- 📋 Ejecución de auditoría final con Lynis

## ⚠️ Cuidados Post-Ejecución

### 🔐 Configuración SSH Crítica

**🚨 ADVERTENCIA CRÍTICA**: Si configuras SSH con autenticación dual, mantén la sesión actual abierta y prueba la conexión desde otro terminal antes de cerrar la sesión principal. Necesitarás tanto tu clave privada como la contraseña del usuario para futuras conexiones.

### 🔄 Reinicio del Sistema

Algunos cambios requieren reinicio para ser completamente efectivos. El script preguntará si deseas reiniciar automáticamente. Si eliges no reiniciar inmediatamente, hazlo manualmente cuando sea conveniente:

```bash
reboot
```

### 💾 Archivos de Configuración Modificados

El script crea respaldos automáticos de archivos críticos:
- `/etc/ssh/sshd_config.backup` - Configuración SSH original
- Configuraciones de auditd en `/etc/audit/rules.d/`
- Configuraciones de Fail2ban en `/etc/fail2ban/jail.local`

### 📋 Monitoreo y Logs

Los logs importantes se encuentran en:
- 📊 Reportes Lynis: `/var/log/lynis-reports/`
- 👁️ Logs de auditoría: `/var/log/audit/audit.log`
- 🛡️ Logs de Fail2ban: `/var/log/fail2ban.log`

## 🖥️ Compatibilidad

**✅ Sistemas probados:**
- Debian 12 con instalación mínima
- Sistemas con partición única
- Configuraciones con solo SSH habilitado

**🔒 Nota de Seguridad**: Este script modifica configuraciones críticas del sistema. Siempre prueba en un entorno de desarrollo antes de aplicar en producción. Mantén respaldos actualizados de tu sistema.
