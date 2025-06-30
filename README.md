# Server Diagnostic Tool (diagnostico-servidor)

Herramienta de diagnóstico integral para servidores Linux (Debian 12), orientada a administradores de sistemas y equipos de SRE.

## 🛠️ Funcionalidad principal

Este script realiza un diagnóstico general del estado del servidor y proporciona información clave sobre:

- Uso de memoria RAM y CPU (por usuario y proceso)
- Particiones montadas y espacio disponible
- Servicios fallidos detectados por `systemd`
- Logs críticos y de error (`journalctl`)
- Interfaces de red activas y su tráfico RX/TX
- Escaneo de red local o de un host específico (requiere `nmap`)
- Verificación de comandos necesarios en el sistema

## 📦 Instalación

Clona el repositorio:

```bash
git clone https://github.com/AMJ1601/OPSDIAG
cd OPSDIAG
chmod +x opsdiag.sh
