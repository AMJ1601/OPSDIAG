#!/bin/bash
# Autor: Antonio Madrid
# Descripción: Diágnostico completo del servidor
# Fecha: 24/06/2025
# SO: Debian 12
# Version: 1.0.0

# Paleta de colores
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

# Root
if [ $UID != 0 ]; then
	echo -e "${redColour}[!] Mejor ejecutar con root"
fi

#Comprobación de existencias de comandos
function requeriments(){
	comands=("free" "echo" "exit" "date" "uptime" "uname" "top" "ps" "who" "df" "awk" "grep" "sed" "cut" "tr" "systemctl" "journalctl" "nmap" "ping" "jobs" "cat" "ip")
	for comand in ${comands[@]}; do
		if ! command -v $comand &>/dev/null; then
			echo -e "${redColour}[!] Comando no encontrado $comand"	
		else
			echo -e "${blueColour}[+] Comando encontrado $comand "
		fi
	done
	salto
}
# Mensaje de despedida
trap 'echo -e "${blueColour}Hemos terminado 😊${endColour}​"' EXIT # Cuando termine el script ejecuta el echo

# Detección de errores
set -eo pipefail # -e: cualquier comando retorna código distinto a 0 el script termina, -o pipefile: si algún comando falla en un pipeline lo detecta
function error(){
	echo -e "{redColour}Error en la línea $1, $2"
	exit 1	
}
trap 'error "$LINENO" "$BASH_COMMAND"' ERR # Cuando detecta error ejecuta la función con la línea donde ha fallado el código y el comando que ha fallado

# Función estética para ejecutar al finalizar funciones
function salto(){
	echo -e "\n"
	for i in {1..100}; do
		echo -ne "${grayColour}-${endColour}" # bucle que imprime guiones sin saltos de linea gracias a -n
	done
	echo -e "\n"
}

# Capturar control c y salir
trap ctrl_c INT
function ctrl_c(){
	echo -e "${redColour}[!] Saliendo...${endColour}"
	exit 1
}

# Panel de ayuda
function helpanel(){
	salto
	echo -e "\n"
	echo -e "\t${yellowColour}-p: checkeo de múltiples servicios${endColour}"
		echo -e "\t\t${yellowColour}Proporcioname los servicios \"ssh,docker\" o ssh,docker (PERO SIN ESPACIOS)${endColour}"
	echo -e "\t${yellowColour}-j: Fallos de systmd (desde el último boot)${endColour}"
		echo -e "\t\t${yellowColour}Proporcioname los niveles que quieres ver (1-3) o (3), 7 es el último ${endColour}"
	echo -e "\t${yellowColour}-o: Escanea un host${endColour}"
		echo -e "\t\t${yellowColour}Proporciona IP (192.168.10.0) [!] Escanea todos los puertos${endColour}"
	echo -e "\t${yellowColour}-s: escaneo de hosts activos locales${endColour}"
		echo -e "\t\t${yellowColour}Proporciona IP/MASK (192.168.10.0/24) [!] Solo escanea los 1000 puertos mas usados${endColour}"
	echo -e "\t${yellowColour}-d: Ver sistemas de archivos${endColour}"
	echo -e "\t${yellowColour}-c: Ver uso del procesador${endColour}"
	echo -e "\t${yellowColour}-m: Ver uso de la memoria${endColour}"
	echo -e "\t${yellowColour}-f: Ver servicios del sistemas caidos${endColour}"
	echo -e "\t${yellowColour}-i: Monitor de interfaces de red${endColour}"
	echo -e "\t${yellowColour}-r: Comprobar existencia de comandos necesarios${endColour}"
	echo -e "\t${yellowColour}-h: Panel de ayuda${endColour}"
}

# Si no hay argumentos muestra el panel de ayuda y sale y si no muestra la fecha y el tiempo que lleva encendido el sistema
if [[ $# == 0 ]]; then
	helpanel
	exit 1
else
	clear
	dat=$(date)
    tactivo=$(uptime | xargs)
    kernel=$(uname -r)
	hostname=$(cat /etc/hostname)
	echo -e "${yellowColour}Fecha: ${purpleColour}$dat\n${yellowColour}Tiempo activo: ${purpleColour}$tactivo${endColour}"
    echo -e "${yellowColour}Versión de kernel: ${purpleColour}$kernel${endColour}"
	echo -e "${yellowColour}Nombre del equipo: ${purpleColour}$hostname${endColour}"
	salto
fi

# Mirar memoria en uso y memoria total
function showmemory(){
	memuso=$(free -h | awk '/Mem:/ {print $3}')
	memtotal=$(free -h | awk '/Mem:/ {print $2}') # Coge valores de la RAM legibles
	memuso2=$(free | awk '/Mem:/ {print $3}') 
	memtotal2=$(free | awk '/Mem:/ {print $2}') # Coge valores de la RAM en la misma unidad de media
	porcentaje=$(( memuso2 * 100 / memtotal2 )) # Calculo de % de uso de la RAM
	todo="Memoria en uso: $memuso \tMemoria total: $memtotal \tPorcentaje de uso: $porcentaje%"
	if [ $porcentaje -lt 90 ]; then
		echo -e "${blueColour}$todo${endColour}\n"
	else
		echo -e "${redColour}$todo${endColour}\n"
	fi # Según el % lo imprime de un color u otro
	echo -e "${greenColour}Procesos que mas ram consume de cada usuario:${endColour}"
	echo -e "${turquoiseColour}$(ps aux | head -1)${endColour}"
	echo -e "${yellowColour}$(ps aux --sort=-%mem | awk '$1=="root" {print;exit}')${endColour}"
	users=$(who | awk '{printf "%s ", $1}') # Usuarios conecados
	if [ "$users" ]; then
		for user in $users; do 
			proces=$(ps aux --sort=-%mem | awk -v user="$user" '$1==user {print;exit}')
			echo -e "${yellowColour}$proces${endColour}"
		done
	fi # Itera los usuarios e imprime el proceso que mas consume de cada uno de ellos
	salto
}

# Mirar uso del procesador
function showcpu(){
	uso=$((100 - $(top -bn1 | awk '/Cpu/ gsub(/[.,]/, " "){ for(i=1;i<=NF;i++){ if($i=="id"){ printf "%s", $(i-2)}}}'))) # Calcula el % de uso de la CPU con datos que propociona top, exactamente id
	imprimeuso="Uso CPU: $uso%"
	if [ $uso -ge 90 ]; then
		echo -e "${redColour}$imprimeuso${endColour}\n"
	else
		echo -e "${blueColour}$imprimeuso${endColour}\n"
	fi # Según el procentaje lo imprime de distintos colores
	echo -e "${greenColour}Procesos que mas cpu consume de cada usuario:${endColour}"
	echo -e "${turquoiseColour}$(ps aux | head -1)${endColour}" # Muestra la primera linea para entender los datos que proporciona el script
	echo -e "${yellowColour}$(ps aux --sort=-%cpu | awk '$1=="root" {print;exit}')${endColour}"
	users=$(who | awk '{printf "%s ", $1}') # Usuarios conectados
	if [ "$users" ]; then
		for user in $users; do 
			proces=$(ps aux --sort=-%cpu| awk -v user="$user" '$1==user {print;exit}')
			echo -e "${yellowColour}$proces${endColour}"
		done
	fi # Itera usuarios con el proceso que mas consume de cada uno de ellos
	salto
}

function showparti(){
	df -h | while read -r filesystem size used avail use mounted; do # Lee linea por linea guardando valores en esas variables
		uso=$(echo "$use" | tr -d "\%") # Quita el porcentaje
		if [[ $uso -ge 90 ]] ; then
			# Hacemos una tabla sin bordes para imprimir de manera mas legible los datos
			printf "${redColour}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \ 
				"$size" "$used" "$avail" "$use" "$mounted"
		else
			if [ "$filesystem" == "Filesystem" ]; then
				printf "${turquoiseColour}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \
                                        	"$size" "$used" "$avail" "$use" "$mounted"
			else
				printf "${blueColour}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \
                                        	"$size" "$used" "$avail" "$use" "$mounted"
			fi # Imprime la primera linea de otro color
		fi
	done # Según el porcentaje lo imprime de una con un color u otro
	salto
}

# Servicios del sistemas fallidos
function servicefailed(){
	echo -e "${turquoiseColour}Servicios fallidos:${endColour}\n"
	systemctl --failed
	salto
}

# Errores del systemd
function jerrors(){
	if [[ ! $1 =~ ^[0-9] ]] || [[ ${#1} == 3 ]] && [[ ! "$1" =~ [\-] ]] ; then # Valida formato del getopt proporcionado
		echo -e "${redColour}[!] Argumento invalido${endColour}"
		helpanel
		return 1
	fi
	n1=$(echo "$1" | sed 's/-/ /g' | awk '{print $1}')
	n2=$(echo "$1" | sed 's/-/ /g' | awk '{print $2}') # Divide los datos
	if [[ $n1 -gt 7 ]] || [[ $n2 -gt 7 ]]; then # Valida otra vez el getopt proporcionado
		echo -e "${redColour}[!] Argumento invalido${endColour}"
		helpanel
		return 1
	fi
	if [ -z "$n2" ]; then
		n2="$n1"
	fi
	echo -e "${redColour}[!] Desde el último boot${endColour}"
	for (( i=n1;i<=n2;i++ )); do
		if [ $i -eq 1 ]; then
			echo -e "${turquoiseColour}Errores de acción inmediata${endColour}"
			journalctl -p $i -xb
		elif [ $i -eq 2 ]; then
			echo -e "${turquoiseColour}Errores críticos${endColour}"
			journalctl -p $i -xb
		elif [ $i -eq 3 ]; then
			echo -e "${turquoiseColour}Errores no críticos${endColour}"
			journalctl -p $i -xb
		else
			echo -e "${turquoiseColour}Errores de nivel $i (menos severos) ${endColour}"
			journalctl -p $i -xb
		fi
	done # Itera por los niveles detectando en cual está y proporcionando la información
	salto
}

# Monitorear interfaces de red
function checkint(){
	interfaces=$(ip -br addr | awk '{printf "%s ", $1}') # Detecta las interfaces disponibles
	for int in $interfaces; do
		RX=$(($(cat /sys/class/net/"$int"/statistics/rx_bytes) / 1024)) # directorio con los B de descarga y calculo a MB
		TX=$(($(cat /sys/class/net/"$int"/statistics/tx_bytes) / 1024)) # directorio con los B de subida y calculo a MB
		echo -e "${turquoiseColour}Int: ${greenColour}$int${turquoiseColour} IP: ${greenColour}$(ip a s "$int" | awk '/inet/ {printf "%s ", $2}')${turquoiseColour}MAC: ${greenColour}$(ip a s "$int" | awk '/link\// {printf "%s ", $2}')${endColour}"
		echo -e "${yellowColour}$(ip -s link show dev "$int" | tail -n +3)${endColour}"
		echo -e "\n${blueColour}Mas legible:${endColour}"
		echo -e "${turquoiseColour}RX: ${greenColour}$RX MB${turquoiseColour} TX: ${greenColour}$TX MB${endColour}\n"
	done # Las itera proporcionando datos
	echo -e "${purpleColour}[+] RX= recibido TX= enviado${endColour}"
	salto
}

# Getopts (opciones del script)
while getopts "p:j:s:o:dcmfirh*" arg; do
        case $arg in
			p)
				services="$OPTARG"
				checkser=1
				;;
			s)
				IP="$OPTARG"
				scanhcont=1
				;;
			o) 
				IPh="$OPTARG"
				scanother=1
				;;
			d) showparti ;;
			c) showcpu ;;
			m) showmemory ;;
			f) servicefailed ;;
			j) jerrors "$OPTARG" ;;
			i) checkint ;;
			r) requeriments;;
            h) helpanel ;;
			*) helpanel ;;
        esac
done

# Requerimentos de paquetes
if [[ $scanhcont -eq 1 ]] || [[ $scanother -eq 1 ]]; then # Si algún getopt es pronunciado
	if ! dpkg -s nmap net-tools &>/dev/null; then # Detecta si existen los paquetes necesarios para instalarlos en caso necesario
		echo -e "${redColour}[!] No esta instalado nmap y/o net-tools ¿Quieres instalarlo? [S/n]${endColour}"
		read -r conf
		if [[ $conf =~ ^[Ss] ]]; then
			echo -e "${blueColour}[+] Instalando...${endColour}"
            sudo apt update &>/dev/null && sudo apt install nmap net-tools -y &>/dev/null
			echo -e "${blueColour}[+] Instalado${endColour}"
		else
			echo -e "${redColour}[!] No se instalará${endColour}"
			exit 1
		fi
	fi
fi

# Escaneo de hosts activos
function scanhost(){
	printf "${turquoiseColour}%-15s %-15s %-17s %-50s\n${endColour}" "" "IP" "MAC" "PORT" # Damos formato a la tabla
	while read -r IP MAC; do # Recorre linea por linea del comando *, que guarda en IP y MAC los valores ordenados, osea IP el primer argumento MAC el segundo
		while [ "$(jobs -rp | wc -l)" -ge 20 ]; do
    		sleep 0.2
  		done # Si superamos los 20 jobs hace sleep para que no pueda hacer mas
		{
		PORT=$(nmap -Pn --top-ports 1000 --max-retries 2 -T3 -sV "$IP" 2>/dev/null | awk '/^[0-9]+\/tcp/ {for(i=1;i<=NF;i++){ if(i!=2){printf "%s ", $i}}}')
		if [ -z "$PORT" ]; then 
			PORT=$(echo -e "${blueColour}No hay puertos activos${endColour}")
		fi
		printf "${turquoiseColour}%-15s ${yellowColour}%-15s %-17s %-50s\n${endColour}" "Activo:" "$IP" "$MAC" "$PORT"
		} & # Por cada IP escanea los 1000 puertos mas frecuentes y lo guarda en una variable que luego usamos, lo ejecuta en jobs (background)
	done < <(nmap -sn 192.168.1.0/24 | awk '/Nmap scan report for/ {ip=$5} /MAC Address:/ {print ip, $3}') # * Este es el comando que se recorre linea por line
	wait # Espera a que los jobs terminen
	salto
}

if [[ $scanhcont == 1 ]]; then
	if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then # Valido el formato de la variable
		scanhost
	else
		echo -e "${redColour}[!] El formato de la IP no es válido...${endColour}"
		helpanel
		exit 1
	fi
fi

# Escaneo de un único host
function scanotherhost(){
	all=$(nmap -sV -p- -T3 "$IPh" | awk '/MAC Address:/ {print $3} /^[1-9]/ {printf "%s %s ", $1, $3}') # MAC y los puertos acivos con su versión
	mac=$(echo "$all" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9a-zA-Z]+:/) print $i; exit}') # Detecta solo la MAC según la variable anterior
	latencia=$(ping "$IPh" -c1 | awk -F 'time=' '/time=/ {print $2}') # Coge latencia por ICMP
	ports=$(nmap -sV -p- -T3 "$IPh" | awk '/^[0-9]+\/tcp/ {for (i=1;i<=NF;i++) if(i!=2) printf "%s ", $i; print ""}')
    if [[ -z "$ports" ]]; then
        ports="No hay puertos activos"
    fi
    echo -e "${blueColour}IP: $IPh MAC: $mac${endColour}\n${yellowColour}Ports: $ports ${endColour}"
	echo -e "${turquoiseColour}Latencia ICMP: $latencia ${endColour}"
	salto
}

if [[ "$scanother" -eq 1 ]]; then
	if [[ $IPh =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then # Valida el formato proporcionado
		scanotherhost
	else
		echo -e "${redColour}[!] El formato de la IP no es válido...${endColour}"
		helpanel
		exit 1
	fi
fi

#Checkeo de múltiples servicios
function checkservices(){
	for service in ${services//,/ }; do
		if [[ $(systemctl is-active "$service") == "active" ]]; then # Detecta si el servicio esta activo
			echo -e "${blueColour}El servicio ${yellowColour}$service${blueColour} está activo"
		else
			echo -en "${redColour}El servicio ${yellowColour}$service${redColour} está inactivo; "
			err=$(journalctl -u "$service" | tail -4 | awk '/systemd\[1\]/ {for (i=7;i<=NF;i++) printf "%s ", $i}')
			if [[ -z $err ]]; then # Si no hay contenido en la variable
				if ! systemctl status &>/dev/null "$service"; then # detecta si el servicio existe
				echo -e "${redColour}[!] No exixte${endColour}"
				fi
			else
				echo -e "${redColour}$err${endColour}" # Si existe imprime un log del error
			fi
		fi
	done
	salto
}
if [[ "$checkser" -eq 1 ]]; then
		checkservices "$services"
fi
