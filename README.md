# Server Diagnostic Tool (diagnostico-servidor)  
*Comprehensive diagnostic tool for Linux servers (Debian 12), designed for system administrators and SRE teams.*

## 🛠️ Core Functionality  
This script performs a general server health check and provides key information about:  

- **RAM and CPU usage** (by user and process)  
- **Mounted partitions** and available space  
- **Failed services** detected by systemd  
- **Critical and error logs** (journalctl)  
- **Active network interfaces** and their RX/TX traffic  
- **Local network scan** or specific host scan (requires nmap)  
- **Verification** of required system commands  

## 📦 Installation  
Clone the repository:
```bash
git clone https://github.com/AMJ1601/OPSDIAG
cd OPSDIAG
chmod +x opsdiag.sh
```
https://roadmap.sh/projects/server-stats
