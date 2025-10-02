#!/bin/bash

# Simple Assetfinder Scanner - Shows ALL results without filtering
# Just runs assetfinder and displays everything it finds

# Colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
TARGET_FILE="hp-target-2025.txt"
PROBE_DOMAINS=true
SCAN_ADMIN=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-probe)
            PROBE_DOMAINS=false
            shift
            ;;
        --no-admin)
            SCAN_ADMIN=false
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--no-probe] [--no-admin]"
            echo "  --no-probe    Skip httpx probing"
            echo "  --no-admin    Skip admin panel scanning"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Check if assetfinder exists
if ! command -v assetfinder &> /dev/null; then
    echo -e "${RED}Error: assetfinder not found!${NC}"
    echo "Install it with: go install github.com/tomnomnom/assetfinder@latest"
    exit 1
fi

# Check target file
if [[ ! -f "$TARGET_FILE" ]]; then
    echo -e "${RED}Error: Target file $TARGET_FILE not found!${NC}"
    exit 1
fi

# Read domains
mapfile -t domains < "$TARGET_FILE"
total_domains=${#domains[@]}

if [[ $total_domains -eq 0 ]]; then
    echo -e "${RED}Error: No domains in $TARGET_FILE${NC}"
    exit 1
fi

echo -e "${GREEN}=== Simple Assetfinder Scanner ===${NC}"
echo -e "${CYAN}Found $total_domains domains to scan${NC}"
echo ""

# Process each domain
for ((i=0; i<total_domains; i++)); do
    domain="${domains[i]}"
    
    # Skip empty lines
    [[ -z "$domain" ]] && continue
    
    echo -e "${YELLOW}[$((i+1))/$total_domains] Scanning: $domain${NC}"
    
    # Create domain directory
    domain_dir="./$domain"
    mkdir -p "$domain_dir"
    
    # Run assetfinder and show ALL results
    echo -e "${CYAN}Running assetfinder...${NC}"
    
    if assetfinder "$domain" | sort -u > "$domain_dir/all-domains.txt"; then
        domain_count=$(wc -l < "$domain_dir/all-domains.txt")
        
        if [[ $domain_count -gt 0 ]]; then
            echo -e "${GREEN}Found $domain_count domains:${NC}"
            
            # Show ALL domains in terminal
            while IFS= read -r found_domain; do
                echo -e "  ${CYAN}$found_domain${NC}"
            done < "$domain_dir/all-domains.txt"
            
            # Probe domains if enabled
            if [[ "$PROBE_DOMAINS" == "true" ]] && command -v httpx &> /dev/null; then
                echo -e "${YELLOW}Probing alive domains...${NC}"
                
                if httpx -l "$domain_dir/all-domains.txt" -silent -status-code -title > "$domain_dir/alive-domains.txt" 2>/dev/null; then
                    alive_count=$(wc -l < "$domain_dir/alive-domains.txt")
                    
                    if [[ $alive_count -gt 0 ]]; then
                        echo -e "${GREEN}Found $alive_count alive domains:${NC}"
                        
                        # Show ALL alive domains
                        while IFS= read -r alive_domain; do
                            echo -e "  ${GREEN}✓ $alive_domain${NC}"
                        done < "$domain_dir/alive-domains.txt"
                    else
                        echo -e "${RED}No alive domains found${NC}"
                    fi
                fi
            fi
            
            # Scan for admin panels if enabled
            if [[ "$SCAN_ADMIN" == "true" ]] && [[ -f "$domain_dir/alive-domains.txt" ]]; then
                echo -e "${YELLOW}Scanning for admin panels...${NC}"
                
                # Admin paths
                admin_paths=(
                    "/admin"
                    "/administrator" 
                    "/wp-admin"
                    "/panel"
                    "/dashboard"
                    "/login"
                    "/portal"
                    "/console"
                    "/manager"
                    "/cpanel"
                    "/api"
                )
                
                > "$domain_dir/admin-panels.txt"
                
                # Extract base URLs and test admin paths
                awk '{print $1}' "$domain_dir/alive-domains.txt" | while IFS= read -r base_url; do
                    [[ -z "$base_url" ]] && continue
                    
                    for path in "${admin_paths[@]}"; do
                        test_url="${base_url}${path}"
                        
                        if command -v httpx &> /dev/null; then
                            if timeout 15 httpx -target "$test_url" -silent -status-code -mc 200,401,403 2>/dev/null | grep -E "(200|401|403)" > /dev/null; then
                                echo "$test_url" >> "$domain_dir/admin-panels.txt"
                                echo -e "  ${RED}🚪 $test_url${NC}"
                            fi
                        fi
                        
                        sleep 0.1
                    done
                done
                
                if [[ -f "$domain_dir/admin-panels.txt" ]] && [[ -s "$domain_dir/admin-panels.txt" ]]; then
                    admin_count=$(wc -l < "$domain_dir/admin-panels.txt")
                    echo -e "${RED}Found $admin_count admin panels!${NC}"
                else
                    echo -e "${YELLOW}No admin panels found${NC}"
                fi
            fi
            
        else
            echo -e "${RED}No domains found for $domain${NC}"
        fi
        
    else
        echo -e "${RED}Assetfinder failed for $domain${NC}"
    fi
    
    echo ""
    echo "Results saved to: $domain_dir/"
    echo "  - all-domains.txt (all assetfinder results)"
    [[ -f "$domain_dir/alive-domains.txt" ]] && echo "  - alive-domains.txt (alive domains with status)"
    [[ -f "$domain_dir/admin-panels.txt" ]] && echo "  - admin-panels.txt (admin panels found)"
    echo ""
    
    # Small delay between domains
    sleep 2
done

echo -e "${GREEN}=== Scan Complete ===${NC}"
echo -e "${CYAN}Processed $total_domains domains${NC}"
echo ""
echo -e "${YELLOW}All results are saved in individual domain directories${NC}"
echo -e "${YELLOW}Check each domain folder for:${NC}"
echo -e "${YELLOW}  - all-domains.txt (complete assetfinder output)${NC}"
echo -e "${YELLOW}  - alive-domains.txt (httpx results)${NC}"
echo -e "${YELLOW}  - admin-panels.txt (admin panel discoveries)${NC}"