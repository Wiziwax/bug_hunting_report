#!/bin/bash

# Enhanced New Subdomains Monitor for Bug Hunters
# Monitors for new subdomains and immediately tests them

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
LOG_FILE="newsubs_monitor.log"
SUMMARY_FILE="newsubs_summary.txt"
CONTINUOUS_MODE=false
SCAN_NEW=true
PROBE_NEW=true
NOTIFY_ENABLED=true

# Function to display usage
usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -c, --continuous    Run in continuous monitoring mode"
    echo "  -s, --scan          Scan new subdomains with nuclei (default: true)"
    echo "  -p, --probe         Probe new subdomains with httpx (default: true)"
    echo "  -n, --no-notify     Disable notifications"
    echo "  -h, --help          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                  # Run once with default settings"
    echo "  $0 -c               # Run in continuous mode"
    echo "  $0 --no-scan        # Skip nuclei scanning"
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -c|--continuous)
            CONTINUOUS_MODE=true
            shift
            ;;
        -s|--scan)
            SCAN_NEW=true
            shift
            ;;
        --no-scan)
            SCAN_NEW=false
            shift
            ;;
        -p|--probe)
            PROBE_NEW=true
            shift
            ;;
        --no-probe)
            PROBE_NEW=false
            shift
            ;;
        -n|--no-notify)
            NOTIFY_ENABLED=false
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Logging functions
log_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_new_finding() {
    echo -e "${CYAN}[$(date '+%Y-%m-%d %H:%M:%S')] NEW:${NC} $1" | tee -a "$LOG_FILE"
}

log_vuln() {
    echo -e "${PURPLE}[$(date '+%Y-%m-%d %H:%M:%S')] VULN:${NC} $1" | tee -a "$LOG_FILE"
}

# Notification function
notify() {
    if [[ "$NOTIFY_ENABLED" == "true" ]] && command -v notify &> /dev/null; then
        echo "$1" | notify -id "newsubs-monitor" 2>/dev/null || true
    fi
}

# Function to check if required tools are installed
check_tools() {
    local missing_tools=()
    
    if ! command -v subfinder &> /dev/null; then
        missing_tools+=("subfinder")
    fi
    
    if [[ "$PROBE_NEW" == "true" ]] && ! command -v httpx &> /dev/null; then
        missing_tools+=("httpx")
    fi
    
    if [[ "$SCAN_NEW" == "true" ]] && ! command -v nuclei &> /dev/null; then
        missing_tools+=("nuclei")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi
}

# Function to probe new subdomains with httpx
probe_subdomains() {
    local domain="$1"
    local new_subs_file="$2"
    
    if [[ ! -f "$new_subs_file" ]] || [[ ! -s "$new_subs_file" ]]; then
        return 0
    fi
    
    local alive_file="$domain/new_alive_$(date +%Y%m%d_%H%M%S).txt"
    
    log_message "🔍 Probing new subdomains for $domain..."
    
    if timeout 300 httpx -l "$new_subs_file" -silent -status-code -title -follow-redirects -random-agent > "$alive_file" 2>/dev/null; then
        if [[ -s "$alive_file" ]]; then
            local alive_count=$(wc -l < "$alive_file")
            log_new_finding "✅ Found $alive_count alive new endpoints for $domain"
            notify "🔍 Found $alive_count new alive endpoints for $domain"
            
            # Show the alive endpoints
            while IFS= read -r line; do
                log_new_finding "🌐 $line"
            done < "$alive_file"
            
            return 0
        else
            log_message "No new endpoints are alive for $domain"
            rm -f "$alive_file"
        fi
    else
        log_warning "httpx probing failed for $domain"
        rm -f "$alive_file"
    fi
    
    return 1
}

# Function to scan new subdomains with nuclei
scan_new_subdomains() {
    local domain="$1" 
    local new_subs_file="$2"
    
    if [[ ! -f "$new_subs_file" ]] || [[ ! -s "$new_subs_file" ]]; then
        return 0
    fi
    
    local scan_results="$domain/new_vulns_$(date +%Y%m%d_%H%M%S).txt"
    
    log_message "🎯 Scanning new subdomains for vulnerabilities..."
    
    # Scan each new subdomain individually for faster results
    while IFS= read -r subdomain; do
        [[ -z "$subdomain" ]] && continue
        
        local result
        if result=$(timeout 180 nuclei -target "$subdomain" -silent -no-color 2>/dev/null); then
            if [[ -n "$result" ]]; then
                echo "$result" >> "$scan_results"
                
                # Check for reportable findings
                while IFS= read -r finding; do
                    if [[ ! "$finding" =~ \[info\]|\[ssl\] ]] && [[ "$finding" =~ \[low\]|\[medium\]|\[high\]|\[critical\] ]]; then
                        log_vuln "🚨 NEW VULN: $finding"
                        notify "🚨 NEW VULNERABILITY in $domain: $finding"
                    fi
                done <<< "$result"
            fi
        fi
        
        # Small delay to avoid overwhelming
        sleep 0.5
    done < "$new_subs_file"
    
    if [[ -f "$scan_results" ]] && [[ -s "$scan_results" ]]; then
        local total_findings=$(wc -l < "$scan_results")
        log_message "✅ Nuclei scan completed: $total_findings findings"
        return 0
    else
        log_message "No vulnerabilities found in new subdomains"
        rm -f "$scan_results"
        return 1
    fi
}

# Function to process a single domain
process_domain() {
    local domain_path="$1"
    local domain_name=$(basename "$domain_path")
    
    # Use consistent file paths with existing scripts
    local subs_dir="$domain_path/subdomains"
    local subs_file="$subs_dir/subs-domain.txt"
    local old_subs_file="$subs_dir/old_subs.txt"
    local new_subs_file="$subs_dir/new_subs_$(date +%Y%m%d_%H%M%S).txt"
    local temp_subs_file="$subs_dir/temp-subs.txt"
    local history_file="$subs_dir/subdomain_history.txt"
    
    # Create subdirectories if they don't exist
    mkdir -p "$subs_dir"
    
    log_message "🔎 Checking $domain_name for new subdomains..."
    
    # Run subfinder with timeout
    if ! timeout 300 subfinder -d "$domain_name" -silent 2>/dev/null | sort -u > "$temp_subs_file"; then
        log_error "Subfinder failed for $domain_name"
        rm -f "$temp_subs_file"
        return 1
    fi
    
    # Validate subfinder results
    if [[ ! -s "$temp_subs_file" ]]; then
        log_warning "No subdomains found for $domain_name"
        rm -f "$temp_subs_file"
        return 1
    fi
    
    local current_count=$(wc -l < "$temp_subs_file")
    log_message "📊 Current scan found $current_count subdomains for $domain_name"
    
    # Handle first run
    if [[ ! -f "$subs_file" ]]; then
        log_message "🆕 First run for $domain_name - saving initial results"
        mv "$temp_subs_file" "$subs_file"
        cp "$subs_file" "$old_subs_file"
        
        # Record in history
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Initial scan: $current_count subdomains" >> "$history_file"
        
        notify "🆕 Initial scan for $domain_name: $current_count subdomains found"
        return 0
    fi
    
    # Find new subdomains
    local new_subs
    new_subs=$(comm -13 <(sort "$subs_file") <(sort "$temp_subs_file"))
    
    if [[ -n "$new_subs" ]]; then
        local new_count=$(echo "$new_subs" | wc -l)
        log_new_finding "🎉 Found $new_count NEW subdomains for $domain_name:"
        
        # Save new subdomains with timestamp
        echo "$new_subs" > "$new_subs_file"
        
        # Display new subdomains
        echo "$new_subs" | while IFS= read -r sub; do
            log_new_finding "  ➤ $sub"
        done
        
        # Update history
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] New subdomains found: $new_count" >> "$history_file"
        echo "$new_subs" | sed "s/^/  /" >> "$history_file"
        
        # Update main subdomain list
        cat "$temp_subs_file" > "$subs_file"
        cp "$subs_file" "$old_subs_file"
        
        # Send notification
        notify "🎉 $new_count new subdomains found for $domain_name!"
        
        # Probe new subdomains if enabled
        if [[ "$PROBE_NEW" == "true" ]]; then
            probe_subdomains "$domain_path" "$new_subs_file"
        fi
        
        # Scan new subdomains if enabled
        if [[ "$SCAN_NEW" == "true" ]]; then
            scan_new_subdomains "$domain_path" "$new_subs_file"
        fi
        
        # Update summary
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $domain_name: $new_count new subdomains" >> "$SUMMARY_FILE"
        
    else
        log_message "✓ No new subdomains found for $domain_name"
        
        # Update history
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] No new subdomains" >> "$history_file"
    fi
    
    # Cleanup
    rm -f "$temp_subs_file"
    
    return 0
}

# Main monitoring function
run_monitor() {
    log_message "🚀 Starting new subdomains monitor..."
    
    # Check for domain directories
    local domains=()
    while IFS= read -r -d '' dir; do
        if [[ -d "$dir" ]]; then
            domains+=("$dir")
        fi
    done < <(find . -mindepth 1 -maxdepth 1 -type d -print0)
    
    if [[ ${#domains[@]} -eq 0 ]]; then
        log_error "No domain directories found!"
        return 1
    fi
    
    log_message "📁 Found ${#domains[@]} domain directories to monitor"
    
    # Process each domain
    local new_findings=0
    for domain in "${domains[@]}"; do
        if process_domain "$domain"; then
            ((new_findings++))
        fi
        sleep 2  # Delay between domains
    done
    
    log_message "✅ Monitor cycle completed - processed ${#domains[@]} domains"
    
    return 0
}

# Continuous monitoring mode
run_continuous() {
    log_message "🔄 Starting continuous monitoring mode..."
    notify "🔄 Starting continuous subdomain monitoring"
    
    local cycle=1
    while true; do
        log_message "🔄 Starting monitoring cycle #$cycle"
        
        if run_monitor; then
            log_message "✅ Cycle #$cycle completed successfully"
        else
            log_error "❌ Cycle #$cycle failed"
        fi
        
        log_message "⏱️  Waiting 30 minutes before next cycle..."
        sleep 1800  # 30 minutes
        ((cycle++))
    done
}

# Main execution
main() {
    # Create log file header
    {
        echo "=========================="
        echo "New Subdomains Monitor Log"
        echo "Started: $(date)"
        echo "Continuous: $CONTINUOUS_MODE"
        echo "Probe: $PROBE_NEW"
        echo "Scan: $SCAN_NEW"
        echo "=========================="
    } >> "$LOG_FILE"
    
    # Check required tools
    check_tools
    
    # Run monitoring
    if [[ "$CONTINUOUS_MODE" == "true" ]]; then
        run_continuous
    else
        run_monitor
    fi
}

# Handle interruption gracefully
trap 'log_message "Monitor interrupted by user"; notify "🛑 Subdomain monitor stopped"; exit 130' INT TERM

# Run main function
main "$@"