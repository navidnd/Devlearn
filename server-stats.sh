#!/bin/bash

# server-stats.sh - Server Performance Analysis Script

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo -e "\n${CYAN}=== $1 ===${NC}"
}

# Function to print separator
print_separator() {
    echo -e "${BLUE}------------------------------------------------${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}Warning: Running as root user${NC}"
    fi
}

# Get OS information
get_os_info() {
    print_header "SYSTEM INFORMATION"
    
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo -e "${GREEN}OS:${NC} $PRETTY_NAME"
    else
        echo -e "${GREEN}OS:${NC} $(uname -s)"
    fi
    
    echo -e "${GREEN}Kernel:${NC} $(uname -r)"
    echo -e "${GREEN}Hostname:${NC} $(hostname)"
    echo -e "${GREEN}Uptime:${NC} $(uptime -p | sed 's/up //')"
    echo -e "${GREEN}Current Time:${NC} $(date)"
}

# Get CPU usage
get_cpu_usage() {
    print_header "CPU USAGE"
    
    # Method 1: Using /proc/stat (more accurate)
    local cpu_line=$(grep '^cpu ' /proc/stat)
    local idle=$(echo $cpu_line | awk '{print $5}')
    local total=0
    
    for val in $cpu_line; do
        total=$((total + val))
    done
    
    local diff_idle=$idle
    local diff_total=$total
    local diff_usage=$((100 * (diff_total - diff_idle) / diff_total))
    
    echo -e "${GREEN}Total CPU Usage:${NC} $diff_usage%"
    
    # Alternative method using mpstat if available
    if command -v mpstat &> /dev/null; then
        local cpu_usage=$(mpstat 1 1 | awk '/Average:/ {printf "%.1f%%", 100 - $12}')
        echo -e "${GREEN}CPU Usage (mpstat):${NC} $cpu_usage"
    fi
    
    echo -e "${GREEN}CPU Cores:${NC} $(nproc)"
    echo -e "${GREEN}Load Average:${NC} $(uptime | awk -F'load average:' '{print $2}')"
}

# Get memory usage
get_memory_usage() {
    print_header "MEMORY USAGE"
    
    local mem_info=$(grep -E 'MemTotal|MemFree|MemAvailable|Buffers|Cached' /proc/meminfo)
    
    local mem_total=$(echo "$mem_info" | grep MemTotal | awk '{print $2}')
    local mem_free=$(echo "$mem_info" | grep MemFree | awk '{print $2}')
    local mem_available=$(echo "$mem_info" | grep MemAvailable | awk '{print $2}')
    local buffers=$(echo "$mem_info" | grep Buffers | awk '{print $2}')
    local cached=$(echo "$mem_info" | grep Cached | awk '{print $2}')
    
    local mem_used=$((mem_total - mem_available))
    local mem_used_percent=$((mem_used * 100 / mem_total))
    local mem_free_percent=$((mem_available * 100 / mem_total))
    
    # Convert to MB for readability
    local mem_total_mb=$((mem_total / 1024))
    local mem_used_mb=$((mem_used / 1024))
    local mem_available_mb=$((mem_available / 1024))
    
    echo -e "${GREEN}Total Memory:${NC} $mem_total_mb MB"
    echo -e "${GREEN}Used Memory:${NC} $mem_used_mb MB ($mem_used_percent%)"
    echo -e "${GREEN}Available Memory:${NC} $mem_available_mb MB ($mem_free_percent%)"
    echo -e "${GREEN}Free Memory:${NC} $((mem_free / 1024)) MB"
    
    # Swap information
    if grep -q 'SwapTotal' /proc/meminfo; then
        local swap_total=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
        local swap_free=$(grep SwapFree /proc/meminfo | awk '{print $2}')
        local swap_used=$((swap_total - swap_free))
        local swap_used_percent=0
        
        if [ $swap_total -gt 0 ]; then
            swap_used_percent=$((swap_used * 100 / swap_total))
        fi
        
        echo -e "${GREEN}Swap Used:${NC} $((swap_used / 1024)) MB / $((swap_total / 1024)) MB ($swap_used_percent%)"
    fi
}

# Get disk usage
get_disk_usage() {
    print_header "DISK USAGE"
    
    # Use df to get disk usage, excluding tmpfs, squashfs, etc.
    echo -e "${GREEN}Filesystem Usage:${NC}"
    df -h | grep -E '^/dev/' | awk '{printf "%-30s %-10s %-10s %-10s %s\n", $1, $2, $3, $4, $5}' | \
    while read line; do
        echo -e "  $line"
    done
    
    # Overall disk usage summary
    local total_space=$(df -k --total | grep total | awk '{print $2}')
    local used_space=$(df -k --total | grep total | awk '{print $3}')
    local available_space=$(df -k --total | grep total | awk '{print $4}')
    local used_percent=$(df -k --total | grep total | awk '{print $5}')
    
    echo -e "\n${GREEN}Total Disk Summary:${NC}"
    echo -e "  Total: $((total_space / 1024 / 1024)) GB"
    echo -e "  Used: $((used_space / 1024 / 1024)) GB"
    echo -e "  Available: $((available_space / 1024 / 1024)) GB"
    echo -e "  Usage: $used_percent"
}

# Get top processes by CPU
get_top_cpu_processes() {
    print_header "TOP 5 PROCESSES BY CPU USAGE"
    
    if command -v ps &> /dev/null; then
        ps aux --sort=-%cpu | head -n 6 | awk 'NR==1 {printf "%-20s %-10s %-10s %-10s %s\n", "USER", "PID", "%CPU", "%MEM", "COMMAND"} NR>1 {printf "%-20s %-10s %-10s %-10s %s\n", $1, $2, $3, $4, $11}' | \
        while read line; do
            echo -e "  $line"
        done
    else
        echo -e "${RED}Error: ps command not available${NC}"
    fi
}

# Get top processes by memory
get_top_memory_processes() {
    print_header "TOP 5 PROCESSES BY MEMORY USAGE"
    
    if command -v ps &> /dev/null; then
        ps aux --sort=-%mem | head -n 6 | awk 'NR==1 {printf "%-20s %-10s %-10s %-10s %s\n", "USER", "PID", "%CPU", "%MEM", "COMMAND"} NR>1 {printf "%-20s %-10s %-10s %-10s %s\n", $1, $2, $3, $4, $11}' | \
        while read line; do
            echo -e "  $line"
        done
    else
        echo -e "${RED}Error: ps command not available${NC}"
    fi
}

# Get logged in users
get_logged_in_users() {
    print_header "LOGGED IN USERS"
    
    if command -v who &> /dev/null; then
        local users=$(who | awk '{print $1}' | sort | uniq | tr '\n' ' ')
        echo -e "${GREEN}Currently logged in users:${NC} $users"
        
        echo -e "\n${GREEN}User sessions:${NC}"
        who | head -n 10
    else
        echo -e "${RED}Error: who command not available${NC}"
    fi
}

# Get failed login attempts
get_failed_logins() {
    print_header "FAILED LOGIN ATTEMPTS (Last 24 hours)"
    
    if [ -f /var/log/auth.log ]; then
        local failed_count=$(grep "Failed password" /var/log/auth.log 2>/dev/null | grep "$(date -d '24 hours ago' '+%b %e')" | wc -l)
        echo -e "${GREEN}Failed login attempts:${NC} $failed_count"
        
        if [ $failed_count -gt 0 ]; then
            echo -e "\n${GREEN}Recent failed attempts:${NC}"
            grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 5
        fi
    elif [ -f /var/log/secure ]; then
        local failed_count=$(grep "Failed password" /var/log/secure 2>/dev/null | grep "$(date -d '24 hours ago' '+%b %e')" | wc -l)
        echo -e "${GREEN}Failed login attempts:${NC} $failed_count"
    else
        echo -e "${YELLOW}Warning: Could not access auth logs (permission denied or file not found)${NC}"
    fi
}

# Get network information
get_network_info() {
    print_header "NETWORK INFORMATION"
    
    echo -e "${GREEN}IP Addresses:${NC}"
    ip addr show | grep -E 'inet (192\.168|10\.|172\.)' | awk '{print "  " $2}'
    
    echo -e "\n${GREEN}Network Connections:${NC}"
    if command -v netstat &> /dev/null; then
        netstat -tunl | grep LISTEN | head -n 10
    elif command -v ss &> /dev/null; then
        ss -tunl | head -n 10
    else
        echo -e "${YELLOW}Network tools not available${NC}"
    fi
}

# Main function
main() {
    clear
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}               SERVER PERFORMANCE STATISTICS                 ${NC}"
    echo -e "${PURPLE}══════════════════════════════════════════════════════════════${NC}"
    
    check_root
    get_os_info
    print_separator
    get_cpu_usage
    print_separator
    get_memory_usage
    print_separator
    get_disk_usage
    print_separator
    get_top_cpu_processes
    print_separator
    get_top_memory_processes
    print_separator
    get_logged_in_users
    print_separator
    get_failed_logins
    print_separator
    get_network_info
    
    echo -e "\n${GREEN}Script completed at: $(date)${NC}"
}

# Run main function
main
