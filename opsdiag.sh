#!/bin/bash
# Author: Antonio Madrid
# Description: Complete server diagnostics
# Date: 24/06/2025
# OS: Debian 12
# Version: 1.0.0

# Color palette
greenColor="\e[0;32m\033[1m"
endColor="\033[0m\e[0m"
redColor="\e[0;31m\033[1m"
blueColor="\e[0;34m\033[1m"
yellowColor="\e[0;33m\033[1m"
purpleColor="\e[0;35m\033[1m"
turquoiseColor="\e[0;36m\033[1m"
grayColor="\e[0;37m\033[1m"

# Root check
if [ $UID != 0 ]; then
	echo -e "${redColor}[!] Better to run as root"
fi

# Command requirements check
function requirements(){
	commands=("free" "echo" "exit" "date" "uptime" "uname" "top" "ps" "who" "df" "awk" "grep" "sed" "cut" "tr" "systemctl" "journalctl" "nmap" "ping" "jobs" "cat" "ip")
	for command in ${commands[@]}; do
		if ! command -v $command &>/dev/null; then
			echo -e "${redColor}[!] Command not found $command"	
		else
			echo -e "${blueColor}[+] Command found $command "
		fi
	done
	separator
}
# Farewell message
trap 'echo -e "${blueColor}We are done ${endColor}"' EXIT # When script ends, executes the echo

# Error detection
set -eo pipefail # -e: if any command returns non-zero code, script ends. -o pipefail: detects failures in pipelines
function error(){
	echo -e "{redColor}Error on line $1, $2"
	exit 1	
}
trap 'error "$LINENO" "$BASH_COMMAND"' ERR # When error is detected, executes function with line number and failed command

# Aesthetic function to execute after functions
function separator(){
	echo -e "\n"
	for i in {1..100}; do
		echo -ne "${grayColor}-${endColor}" # loop that prints dashes without line breaks thanks to -n
	done
	echo -e "\n"
}

# Capture Ctrl+C and exit
trap ctrl_c INT
function ctrl_c(){
	echo -e "${redColor}[!] Exiting...${endColor}"
	exit 1
}

# Help panel
function help_panel(){
	separator
	echo -e "\n"
	echo -e "\t${yellowColor}-p: multiple services check${endColor}"
		echo -e "\t\t${yellowColor}Provide me services \"ssh,docker\" or ssh,docker (BUT WITHOUT SPACES)${endColor}"
	echo -e "\t${yellowColor}-j: Systemd failures (since last boot)${endColor}"
		echo -e "\t\t${yellowColor}Provide levels you want to see (1-3) or (3), 7 is the last ${endColor}"
	echo -e "\t${yellowColor}-o: Scan a host${endColor}"
		echo -e "\t\t${yellowColor}Provide IP (192.168.10.0) [!] Scans all ports${endColor}"
	echo -e "\t${yellowColor}-s: scan local active hosts${endColor}"
		echo -e "\t\t${yellowColor}Provide IP/MASK (192.168.10.0/24) [!] Only scans top 1000 ports${endColor}"
	echo -e "\t${yellowColor}-d: View filesystems${endColor}"
	echo -e "\t${yellowColor}-c: View CPU usage${endColor}"
	echo -e "\t${yellowColor}-m: View memory usage${endColor}"
	echo -e "\t${yellowColor}-f: View failed system services${endColor}"
	echo -e "\t${yellowColor}-i: Network interfaces monitor${endColor}"
	echo -e "\t${yellowColor}-r: Check required commands existence${endColor}"
    echo -e "\t${yellowColor}-k  Check fails logins${endColour}"
	echo -e "\t${yellowColor}-h: Help panel${endColor}"
}

# If no arguments, show help panel and exit. Otherwise show date and system uptime
if [[ $# == 0 ]]; then
	help_panel
	exit 1
else
	clear
	date=$(date)
    uptime=$(uptime | xargs)
    kernel=$(uname -r)
	hostname=$(cat /etc/hostname)
	echo -e "${yellowColor}Date: ${purpleColor}$date\n${yellowColor}Uptime: ${purpleColor}$uptime${endColor}"
    echo -e "${yellowColor}Kernel version: ${purpleColor}$kernel${endColor}"
	echo -e "${yellowColor}Hostname: ${purpleColor}$hostname${endColor}"
	separator
fi

# Check used and total memory
function show_memory(){
	mem_used=$(free -h | awk '/Mem:/ {print $3}')
	mem_total=$(free -h | awk '/Mem:/ {print $2}') # Gets RAM values in human-readable format
	mem_used2=$(free | awk '/Mem:/ {print $3}') 
	mem_total2=$(free | awk '/Mem:/ {print $2}') # Gets RAM values in same unit of measure
	percentage=$(( mem_used2 * 100 / mem_total2 )) # RAM usage % calculation
	all_info="Memory used: $mem_used \tTotal memory: $mem_total \tUsage percentage: $percentage%"
	if [ $percentage -lt 90 ]; then
		echo -e "${blueColor}$all_info${endColor}\n"
	else
		echo -e "${redColor}$all_info${endColor}\n"
	fi # Prints in different colors based on percentage
	echo -e "${greenColor}Processes consuming most RAM per user:${endColor}"
	echo -e "${turquoiseColor}$(ps aux | head -1)${endColor}"
	echo -e "${yellowColor}$(ps aux --sort=-%mem | awk '$1=="root" {print;exit}')${endColor}"
	users=$(who | awk '{printf "%s ", $1}') # Connected users
	if [ "$users" ]; then
		for user in $users; do 
			process=$(ps aux --sort=-%mem | awk -v user="$user" '$1==user {print;exit}')
			echo -e "${yellowColor}$process${endColor}"
		done
	fi # Iterates users and prints most consuming process for each
	separator
}

# Check CPU usage
function show_cpu(){
	usage=$((100 - $(top -bn1 | awk '/Cpu/ gsub(/[.,]/, " "){ for(i=1;i<=NF;i++){ if($i=="id"){ printf "%s", $(i-2)}}}'))) # Calculates CPU usage % with top data
	print_usage="CPU Usage: $usage%"
	if [ $usage -ge 90 ]; then
		echo -e "${redColor}$print_usage${endColor}\n"
	else
		echo -e "${blueColor}$print_usage${endColor}\n"
	fi # Prints in different colors based on percentage
	echo -e "${greenColor}Processes consuming most CPU per user:${endColor}"
	echo -e "${turquoiseColor}$(ps aux | head -1)${endColor}" # Shows first line to understand script data
	echo -e "${yellowColor}$(ps aux --sort=-%cpu | awk '$1=="root" {print;exit}')${endColor}"
	users=$(who | awk '{printf "%s ", $1}') # Connected users
	if [ "$users" ]; then
		for user in $users; do 
			process=$(ps aux --sort=-%cpu| awk -v user="$user" '$1==user {print;exit}')
			echo -e "${yellowColor}$process${endColor}"
		done
	fi # Iterates users with most consuming process for each
	separator
}

function show_partitions(){
	df -h | while read -r filesystem size used avail use mounted; do # Reads line by line storing values in these variables
		usage=$(echo "$use" | tr -d "\%") # Removes percentage
		if [[ $usage -ge 90 ]] ; then
			# Create a borderless table to print data more readably
			printf "${redColor}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \ 
				"$size" "$used" "$avail" "$use" "$mounted"
		else
			if [ "$filesystem" == "Filesystem" ]; then
				printf "${turquoiseColor}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \
                                        	"$size" "$used" "$avail" "$use" "$mounted"
			else
				printf "${blueColor}%-15s %-15s %-15s %-15s %-15s %-15s\n" "$filesystem" \
                                        	"$size" "$used" "$avail" "$use" "$mounted"
			fi # Prints first line in different color
		fi
	done # Prints in different colors based on percentage
	separator
}

# Failed system services
function failed_services(){
	echo -e "${turquoiseColor}Failed services:${endColor}\n"
	systemctl --failed
	separator
}

# Systemd errors
function journal_errors(){
	if [[ ! $1 =~ ^[0-9] ]] || [[ ${#1} == 3 ]] && [[ ! "$1" =~ [\-] ]] ; then # Validates getopt format
		echo -e "${redColor}[!] Invalid argument${endColor}"
		help_panel
		return 1
	fi
	level1=$(echo "$1" | sed 's/-/ /g' | awk '{print $1}')
	level2=$(echo "$1" | sed 's/-/ /g' | awk '{print $2}') # Splits data
	if [[ $level1 -gt 7 ]] || [[ $level2 -gt 7 ]]; then # Validates getopt again
		echo -e "${redColor}[!] Invalid argument${endColor}"
		help_panel
		return 1
	fi
	if [ -z "$level2" ]; then
		level2="$level1"
	fi
	echo -e "${redColor}[!] Since last boot${endColor}"
	for (( i=level1;i<=level2;i++ )); do
		if [ $i -eq 1 ]; then
			echo -e "${turquoiseColor}Immediate action errors${endColor}"
			journalctl -p $i -xb
		elif [ $i -eq 2 ]; then
			echo -e "${turquoiseColor}Critical errors${endColor}"
			journalctl -p $i -xb
		elif [ $i -eq 3 ]; then
			echo -e "${turquoiseColor}Non-critical errors${endColor}"
			journalctl -p $i -xb
		else
			echo -e "${turquoiseColor}Level $i errors (less severe) ${endColor}"
			journalctl -p $i -xb
		fi
	done # Iterates through levels detecting which one it's in and providing information
	separator
}

# Monitor network interfaces
function check_interfaces(){
	interfaces=$(ip -br addr | awk '{printf "%s ", $1}') # Detects available interfaces
	for int in $interfaces; do
		RX=$(($(cat /sys/class/net/"$int"/statistics/rx_bytes) / 1024)) # directory with download bytes converted to MB
		TX=$(($(cat /sys/class/net/"$int"/statistics/tx_bytes) / 1024)) # directory with upload bytes converted to MB
		echo -e "${turquoiseColor}Int: ${greenColor}$int${turquoiseColor} IP: ${greenColor}$(ip a s "$int" | awk '/inet/ {printf "%s ", $2}')${turquoiseColor}MAC: ${greenColor}$(ip a s "$int" | awk '/link\// {printf "%s ", $2}')${endColor}"
		echo -e "${yellowColor}$(ip -s link show dev "$int" | tail -n +3)${endColor}"
		echo -e "\n${blueColor}More readable:${endColor}"
		echo -e "${turquoiseColor}RX: ${greenColor}$RX MB${turquoiseColor} TX: ${greenColor}$TX MB${endColor}\n"
	done # Iterates them providing data
	echo -e "${purpleColor}[+] RX= received TX= sent${endColor}"
	separator
}

authentication-failure(){
    echo -e "$(journalctl | grep "authentication failure" | tail -30)"
    separator
}
# Getopts (script options)
while getopts "p:j:s:o:dcmfkirh*" arg; do
        case $arg in
			p)
				services="$OPTARG"
				check_services_flag=1
				;;
			s)
				IP="$OPTARG"
				scan_hosts_flag=1
				;;
			o) 
				IP_host="$OPTARG"
				scan_other_flag=1
				;;
			d) show_partitions ;;
			c) show_cpu ;;
			m) show_memory ;;
			f) failed_services ;;
			j) journal_errors "$OPTARG" ;;
			i) check_interfaces ;;
			r) requirements;;
            k) authentication-failure;;
            h) help_panel ;;
			*) help_panel ;;
        esac
done

# Package requirements
if [[ $scan_hosts_flag -eq 1 ]] || [[ $scan_other_flag -eq 1 ]]; then # If any getopt is used
	if ! dpkg -s nmap net-tools &>/dev/null; then # Detects if required packages are installed to install them if needed
		echo -e "${redColor}[!] nmap and/or net-tools not installed. Do you want to install them? [Y/n]${endColor}"
		read -r confirmation
		if [[ $confirmation =~ ^[Yy] ]]; then
			echo -e "${blueColor}[+] Installing...${endColor}"
            sudo apt update &>/dev/null && sudo apt install nmap net-tools -y &>/dev/null
			echo -e "${blueColor}[+] Installed${endColor}"
		else
			echo -e "${redColor}[!] Won't be installed${endColor}"
			exit 1
		fi
	fi
fi

# Active hosts scan
function scan_hosts(){
	printf "${turquoiseColor}%-15s %-15s %-17s %-50s\n${endColor}" "" "IP" "MAC" "PORT" # Format the table
	while read -r IP MAC; do # Reads line by line from command *, storing ordered values in IP and MAC
		while [ "$(jobs -rp | wc -l)" -ge 20 ]; do
    		sleep 0.2
  		done # If we exceed 20 jobs, sleeps so no more can be created
		{
		PORT=$(nmap -Pn --top-ports 1000 --max-retries 2 -T3 -sV "$IP" 2>/dev/null | awk '/^[0-9]+\/tcp/ {for(i=1;i<=NF;i++){ if(i!=2){printf "%s ", $i}}}')
		if [ -z "$PORT" ]; then 
			PORT=$(echo -e "${blueColor}No active ports${endColor}")
		fi
		printf "${turquoiseColor}%-15s ${yellowColor}%-15s %-17s %-50s\n${endColor}" "Active:" "$IP" "$MAC" "$PORT"
		} & # For each IP scans top 1000 ports and stores in variable, executes in jobs (background)
	done < <(nmap -sn 192.168.1.0/24 | awk '/Nmap scan report for/ {ip=$5} /MAC Address:/ {print ip, $3}') # * This is the command read line by line
	wait # Waits for jobs to finish
	separator
}

if [[ $scan_hosts_flag == 1 ]]; then
	if [[ $IP =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then # Validates variable format
		scan_hosts
	else
		echo -e "${redColor}[!] IP format is invalid...${endColor}"
		help_panel
		exit 1
	fi
fi

# Single host scan
function scan_other_host(){
	all=$(nmap -sV -p- -T3 "$IP_host" | awk '/MAC Address:/ {print $3} /^[1-9]/ {printf "%s %s ", $1, $3}') # MAC and active ports with their version
	mac=$(echo "$all" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[0-9a-zA-Z]+:/) print $i; exit}') # Detects only MAC from previous variable
	latency=$(ping "$IP_host" -c1 | awk -F 'time=' '/time=/ {print $2}') # Gets ICMP latency
	ports=$(nmap -sV -p- -T3 "$IP_host" | awk '/^[0-9]+\/tcp/ {for (i=1;i<=NF;i++) if(i!=2) printf "%s ", $i; print ""}')
    if [[ -z "$ports" ]]; then
        ports="No active ports"
    fi
    echo -e "${blueColor}IP: $IP_host MAC: $mac${endColor}\n${yellowColor}Ports: $ports ${endColor}"
	echo -e "${turquoiseColor}ICMP latency: $latency ${endColor}"
	separator
}

if [[ "$scan_other_flag" -eq 1 ]]; then
	if [[ $IP_host =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then # Validates provided format
		scan_other_host
	else
		echo -e "${redColor}[!] IP format is invalid...${endColor}"
		help_panel
		exit 1
	fi
fi

# Multiple services check
function check_services(){
	for service in ${services//,/ }; do
		if [[ $(systemctl is-active "$service") == "active" ]]; then # Detects if service is active
			echo -e "${blueColor}Service ${yellowColor}$service${blueColor} is active"
		else
			echo -en "${redColor}Service ${yellowColor}$service${redColor} is inactive; "
			error=$(journalctl -u "$service" | tail -4 | awk '/systemd\[1\]/ {for (i=7;i<=NF;i++) printf "%s ", $i}')
			if [[ -z $error ]]; then # If variable is empty
				if ! systemctl status &>/dev/null "$service"; then # detects if service exists
				echo -e "${redColor}[!] Doesn't exist${endColor}"
				fi
			else
				echo -e "${redColor}$error${endColor}" # If exists, prints error log
			fi
		fi
	done
	separator
}
if [[ "$check_services_flag" -eq 1 ]]; then
		check_services "$services"
fi
