#!/bin/bash

# Loop through each directory in the current folder
for dir in */; do
    # Check if it's a directory and has a subs-domain.txt file but no nuclei-results.txt file
    if [ -d "$dir" ] && [ -f "$dir/subs-domain.txt" ] && [ ! -f "$dir/nuclei-results.txt" ]; then
        echo "Running nuclei on $dir/subs-domain.txt..."
        
        # Run nuclei on the subs-domain.txt file
        nuclei -rl 50 -l "$dir/subs-domain.txt" -o "$dir/nuclei-results.txt"
        
        echo "Nuclei scan completed for $dir. Results saved in $dir/nuclei-results.txt."
    else
        echo "Skipping $dir (either no subs-domain.txt found or already scanned)"
    fi
done