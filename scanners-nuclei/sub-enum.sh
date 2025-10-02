#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
TARGET_FILE="hp-target-2025.txt"
LOG_FILE="auto_recon.log"
PROGRESS_FILE="recon_progress.log"

# Function to log messages
log_message() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log errors
log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to log warnings
log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Function to send notification
notify_progress() {
    if command -v notify &> /dev/null; then
        echo "$1" | notify -id "recon-progress" 2>/dev/null || true
    fi
}

# Function to load progress
load_progress() {
    if [[ -f "$PROGRESS_FILE" ]]; then
        cat "$PROGRESS_FILE" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to save progress
save_progress() {
    echo "$1" > "$PROGRESS_FILE"
}

# Function to create directory structure
create_directory() {
    local domain="$1"
    if mkdir -p "$domain/subdomains" "$domain/httpx" "$domain/nuclei"; then
        log_message "Created directory structure for $domain"
        return 0
    else
        log_error "Failed to create directory structure for $domain"
        return 1
    fi
}

# Function to run subfinder
run_subfinder() {
    local domain="$1"
    local output_file="$domain/subdomains/subs-domain.txt"
    
    log_message "Running subfinder for $domain..."
    
    if timeout 300 subfinder -d "$domain" -silent > "$output_file" 2>/dev/null; then
        local count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            log_message "Found $count subdomains for $domain"
            return 0
        else
            log_warning "No subdomains found for $domain"
            return 1
        fi
    else
        log_error "Subfinder failed or timed out for $domain"
        return 1
    fi
}

# Function to run httpx
run_httpx() {
    local domain="$1"
    local input_file="$domain/subdomains/subs-domain.txt"
    local output_file="$domain/httpx.txt"
    local clean_output="$domain/title_and_status.txt"
    
    if [[ ! -f "$input_file" ]] || [[ ! -s "$input_file" ]]; then
        log_warning "No subdomains file found for $domain, skipping httpx"
        return 1
    fi
    
    log_message "Running httpx for $domain..."
    
    if timeout 600 httpx -l "$input_file" -silent -title -status-code -follow-redirects -random-agent > "$output_file" 2>/dev/null; then
        # Process httpx output to extract URL, status, and title
        if [[ -f "$output_file" ]]; then
            # Better parsing of httpx output
            awk '{
                # Extract URL (first field)
                url = $1
                
                # Extract status code (look for [status] pattern)
                status = "unknown"
                for(i=1; i<=NF; i++) {
                    if($i ~ /^\[[0-9]+\]$/) {
                        status = $i
                        break
                    }
                }
                
                # Extract title (everything after [title])
                title = ""
                title_found = 0
                for(i=1; i<=NF; i++) {
                    if($i == "[" && $(i+1) ~ /^[Tt]itle/) {
                        title_found = 1
                        i += 2  # Skip "[ title"
                        continue
                    }
                    if(title_found && $i == "]") {
                        break
                    }
                    if(title_found) {
                        title = title " " $i
                    }
                }
                
                # Clean up title
                gsub(/^\s+|\s+$/, "", title)
                if(title == "") title = "No Title"
                
                print url, status, title
            }' "$output_file" > "$clean_output"
            
            local alive_count=$(wc -l < "$output_file" 2>/dev/null || echo "0")
            log_message "Found $alive_count alive endpoints for $domain"
            return 0
        else
            log_error "httpx output file not created for $domain"
            return 1
        fi
    else
        log_error "httpx failed or timed out for $domain"
        return 1
    fi
}

# Function to generate summary
generate_summary() {
    local domain="$1"
    local subs_file="$domain/subdomains/subs-domain.txt"
    local httpx_file="$domain/httpx.txt"
    local summary_file="$domain/summary.txt"
    
    {
        echo "=== Reconnaissance Summary for $domain ==="
        echo "Date: $(date)"
        echo ""
        
        if [[ -f "$subs_file" ]]; then
            echo "Subdomains found: $(wc -l < "$subs_file")"
        else
            echo "Subdomains found: 0"
        fi
        
        if [[ -f "$httpx_file" ]]; then
            echo "Alive endpoints: $(wc -l < "$httpx_file")"
            echo ""
            echo "Status code breakdown:"
            awk '{for(i=1;i<=NF;i++) if($i ~ /^\[[0-9]+\]$/) print $i}' "$httpx_file" | sort | uniq -c | sort -nr
        else
            echo "Alive endpoints: 0"
        fi
        
        echo ""
        echo "Files created:"
        echo "- $subs_file"
        echo "- $httpx_file" 
        echo "- $domain/title_and_status.txt"
        
    } > "$summary_file"
    
    log_message "Summary generated: $summary_file"
}

# Main execution
main() {
    log_message "Starting reconnaissance automation..."
    
    # Check if target file exists
    if [[ ! -f "$TARGET_FILE" ]]; then
        log_error "Target file $TARGET_FILE not found!"
        exit 1
    fi
    
    # Check required tools
    for tool in subfinder httpx; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "$tool is not installed or not in PATH"
            exit 1
        fi
    done
    
    # Read targets and get total count
    mapfile -t domains < "$TARGET_FILE"
    total_domains=${#domains[@]}
    
    if [[ $total_domains -eq 0 ]]; then
        log_error "No domains found in $TARGET_FILE"
        exit 1
    fi
    
    log_message "Found $total_domains domains to process"
    
    # Load progress
    last_processed=$(load_progress)
    log_message "Resuming from domain index: $last_processed"
    
    # Process each domain
    for ((i=last_processed; i<total_domains; i++)); do
        domain="${domains[i]}"
        
        # Skip empty lines
        [[ -z "$domain" ]] && continue
        
        log_message "Processing domain $((i+1))/$total_domains: $domain"
        notify_progress "🔍 Processing $domain ($((i+1))/$total_domains)"
        
        # Create directory structure
        if ! create_directory "$domain"; then
            log_error "Failed to create directories for $domain, skipping..."
            continue
        fi
        
        # Run subfinder
        if run_subfinder "$domain"; then
            # Run httpx only if subfinder succeeded
            if run_httpx "$domain"; then
                # Generate summary
                generate_summary "$domain"
                log_message "✅ Completed reconnaissance for $domain"
                notify_progress "✅ Completed $domain - Found subdomains and probed endpoints"
            else
                log_warning "httpx failed for $domain, but subfinder results are available"
            fi
        else
            log_warning "Subfinder failed for $domain, skipping httpx"
        fi
        
        # Save progress
        save_progress $((i+1))
        
        # Small delay to avoid overwhelming
        sleep 2
    done
    
    # Reset progress when all domains are processed
    if [[ $((last_processed)) -ge $total_domains ]]; then
        save_progress 0
        log_message "🎉 All domains processed! Resetting progress."
        notify_progress "🎉 Reconnaissance completed for all $total_domains domains!"
    fi
    
    log_message "Reconnaissance automation completed!"
}

# Handle interruption gracefully
trap 'log_warning "Script interrupted by user"; exit 130' INT TERM

# Run main function
main "$@"