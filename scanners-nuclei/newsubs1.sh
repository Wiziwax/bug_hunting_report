#!/bin/bash

find . -mindepth 1 -maxdepth 1 -type d | while read domain; do
    domain_name=$(basename "$domain")  # Extract domain name from folder
    subs_file="$domain/subs-domain.txt"
    old_subs_file="$domain/old_subs.txt"
    new_subs_file="$domain/new_subs.txt"
    temp_subs_file="$domain/temp-subs.txt"

    echo "[+] Running subfinder for $domain_name..."
    subfinder -d "$domain_name" -silent | sort -u > "$temp_subs_file"

    if [[ ! -f "$subs_file" ]]; then
        echo "[+] No previous subdomains found. Saving initial results..."
        mv "$temp_subs_file" "$subs_file"
        cp "$subs_file" "$old_subs_file"
        continue
    fi

    echo "[+] Checking new subdomains for $domain_name..."
    new_subs=$(comm -13 <(sort "$subs_file") <(sort "$temp_subs_file"))

    if [[ -n "$new_subs" ]]; then
        echo "[!] New subdomains found for $domain_name:"
        echo "$new_subs" | tee -a "$new_subs_file"

        # Append new subdomains to the main list
        cat "$temp_subs_file" > "$subs_file"
        cp "$subs_file" "$old_subs_file"
    else
        echo "[-] No new subdomains for $domain_name."
    fi

    rm -f "$temp_subs_file"  # Clean up temporary file
done
