#!/bin/bash

# ==================================================================
# Linux Admin Toolkit v3.0                                         |
# Created by: Sahan Samidhu Saluwadana                             |
# Description: A menu-driven system monitor and maintenance tool.  |
# ==================================================================

#configs
DISK_THRESHOLD=90   # Alert if disk usage > 90%
MEM_THRESHOLD=90    # Alert if memory usage > 90%
SERVICES=("ssh" "docker" "nginx" "apache2" "mysql" "postgresql")

#color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#helper functions
print_header() {
    echo -e "${BLUE}----------------------------------------${NC}"
    echo -e "${YELLOW}  $1 ${NC}"
    echo -e "${BLUE}----------------------------------------${NC}"
}

pause() {
    echo ""
    read -p "Press Enter to return..."
}

confirm() {
    read -p "Are you sure? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Action cancelled.${NC}"
        return 1
    fi
    return 0
}

#read only functions
show_system_info() {
    print_header "SYSTEM INFORMATION"
    echo "Hostname   : $(hostname)"
    if [ -f /etc/os-release ]; then
        echo "OS         : $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    else
        echo "OS         : Unknown"
    fi
    echo "Kernel     : $(uname -r)"
    echo "Uptime     : $(uptime -p)"
    echo "Architecture: $(uname -m)"
}

show_resources() {
    print_header "RESOURCE USAGE"
    echo -e "${YELLOW}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"
    echo ""
    echo -e "${YELLOW}Memory Usage:${NC}"
    free -h | grep -E 'Mem|Swap'
    echo ""
    echo -e "${YELLOW}Disk Usage:${NC}"
    df -h / | grep -v Filesystem
}

show_network() {
    print_header "NETWORK INFORMATION"
    echo "Private IP : $(hostname -I | awk '{print $1}')"
    echo "Public IP  : $(curl -s --max-time 3 ifconfig.me || echo "Unavailable")" 
    echo ""
    echo -e "${YELLOW}Active Listening Ports:${NC}"
    if command -v ss &> /dev/null; then
        sudo ss -tulpn | grep LISTEN | head -5 | awk '{print $1, $5, $7}' 
    else
        sudo netstat -tulpn | grep LISTEN | head -5
    fi
}

show_logs() {
    print_header "RECENT SYSTEM LOGS (Last 10)"
    sudo journalctl -p 3 -xb -n 10 --no-pager || sudo journalctl -n 10 --no-pager
}

show_users() {
    print_header "LOGGED IN USERS"
    printf "%-10s %-10s %-15s\n" "USER" "TTY" "LOGIN TIME"
    who | awk '{printf "%-10s %-10s %-15s %s\n", $1, $2, $3, $4}'
}

check_health() {
    print_header "SYSTEM HEALTH CHECK"
    
    DISK_USAGE=$(df / | grep / | awk '{print $5}' | sed 's/%//')
    if [ "$DISK_USAGE" -gt "$DISK_THRESHOLD" ]; then
        echo -e "[ ${RED}DANGER${NC} ] Disk Usage is at ${DISK_USAGE}% (Threshold: $DISK_THRESHOLD%)"
    else
        echo -e "[ ${GREEN}OK${NC} ] Disk Usage: ${DISK_USAGE}%"
    fi

    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED=$(free | grep Mem | awk '{print $3}')
    MEM_PERCENT=$(( 100 * MEM_USED / MEM_TOTAL ))
    
    if [ "$MEM_PERCENT" -gt "$MEM_THRESHOLD" ]; then
        echo -e "[ ${RED}DANGER${NC} ] Memory Usage is at ${MEM_PERCENT}%"
    else
        echo -e "[ ${GREEN}OK${NC} ] Memory Usage: ${MEM_PERCENT}%"
    fi

    FAILED_SERVICES=$(systemctl --failed --no-legend | wc -l)
    if [ "$FAILED_SERVICES" -gt 0 ]; then
        echo -e "[ ${RED}WARN${NC} ] Found $FAILED_SERVICES failed systemd units."
    else
        echo -e "[ ${GREEN}OK${NC} ] No failed system services found."
    fi
}

check_services() {
    print_header "SERVICE STATUS MONITOR"
    printf "%-20s %-15s\n" "SERVICE" "STATUS"
    echo "-----------------------------------"

    for service in "${SERVICES[@]}"; do
        if systemctl is-active --quiet "$service"; then
            printf "%-20s ${GREEN}%-15s${NC}\n" "$service" "RUNNING"
        elif systemctl list-unit-files | grep -q "^$service"; then
            printf "%-20s ${RED}%-15s${NC}\n" "$service" "STOPPED"
        else
            printf "%-20s ${YELLOW}%-15s${NC}\n" "$service" "NOT INSTALLED"
        fi
    done
}

#maintanance functions
run_updates() {
    print_header "SYSTEM UPDATES"
    echo "Detecting package manager..."
    if command -v apt &> /dev/null; then
        echo "Updating APT repositories..."
        sudo apt update
        echo ""
        read -p "Do you want to run 'apt upgrade'? (y/n): " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo apt upgrade -y
        fi
    elif command -v dnf &> /dev/null; then
        sudo dnf check-update
        read -p "Do you want to run 'dnf upgrade'? (y/n): " -n 1 -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo dnf upgrade -y
        fi
    else
        echo -e "${RED}No supported package manager found (apt/dnf).${NC}"
    fi
}

clean_system() {
    print_header "SYSTEM CLEANUP"
    echo -e "${YELLOW}Targets: APT cache, Unused dependencies, Old Journal logs${NC}"
    confirm || return
    
    echo "Cleaning package cache..."
    if command -v apt &> /dev/null; then
        sudo apt autoremove -y
        sudo apt clean
    fi
    
    echo "Vacuuming system logs (older than 3 days)..."
    sudo journalctl --vacuum-time=3d
    
    echo -e "${GREEN}Cleanup Complete!${NC}"
}

flush_ram() {
    print_header "MEMORY FLUSH"
    echo -e "${RED}WARNING: This forces the kernel to drop cached data.${NC}"
    echo "Only use this if system is lagging due to high cache usage."
    confirm || return
    
    echo "Syncing filesystem..."
    sync
    echo "Dropping caches..."
    # Using sudo bash -c to handle the redirection correctly
    sudo bash -c "echo 3 > /proc/sys/vm/drop_caches"
    
    echo -e "${GREEN}RAM Buffers Flushed.${NC}"
}

maintenance_menu() {
    while true; do
        clear
        print_header "ACTIVE MAINTENANCE MENU"
        echo "1. Run System Updates"
        echo "2. Clean Disk Space (Cache & Logs)"
        echo "3. Flush RAM (Drop Caches)"
        echo "4. Back to Main Menu"
        echo ""
        read -p "Select option [1-4]: " m_choice
        
        case $m_choice in
            1) run_updates; pause ;;
            2) clean_system; pause ;;
            3) flush_ram; pause ;;
            4) break ;;
            *) echo -e "${RED}Invalid option${NC}"; sleep 1 ;;
        esac
    done
}

#MAIN MENU
while true; do
    clear
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}   LINUX ADMIN TOOLKIT v3.0${NC}"
    echo -e "${GREEN}================================${NC}"
    echo "1. System Information"
    echo "2. Resource Usage"
    echo "3. Network Information"
    echo "4. User Management"
    echo "5. Recent Error Logs"
    echo "--------------------------------"
    echo -e "6. ${YELLOW}Run Health Check${NC}"
    echo -e "7. ${YELLOW}Check Critical Services${NC}"
    echo "--------------------------------"
    echo -e "8. ${RED}Maintenance Menu (Active)${NC}"
    echo "9. Exit"
    echo ""
    read -p "Select option [1-9]: " choice
    echo ""

    case $choice in
        1) show_system_info; pause ;;
        2) show_resources; pause ;;
        3) show_network; pause ;;
        4) show_users; pause ;;
        5) show_logs; pause ;;
        6) check_health; pause ;;
        7) check_services; pause ;;
        8) maintenance_menu ;;
        9) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option!${NC}"; sleep 1 ;;
    esac
done