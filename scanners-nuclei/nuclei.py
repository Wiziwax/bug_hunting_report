import os
import subprocess
import re
import datetime

# Log file to track the last scanned directory
LOG_FILE = "scan_progress.log"
# Directory to store all filtered results
ALL_RESULTS_DIR = "nuclei_filtered_results"

# Ensure the all_results directory exists
os.makedirs(ALL_RESULTS_DIR, exist_ok=True)

# Notify function
def notify(message, channel="discord-nuclei"):
    """Send a notification using notify tool."""
    try:
        subprocess.run(["notify", "-id", channel], input=message, text=True, check=True)
    except FileNotFoundError:
        print("Error: 'notify' command not found. Please install it to receive notifications.")
    except subprocess.CalledProcessError as e:
        print(f"Error sending notification: {e}")

# Get the last scanned directory index
def get_last_scanned_index():
    if not os.path.exists(LOG_FILE):
        with open(LOG_FILE, "w") as log:
            log.write("0")
        return 0
    try:
        with open(LOG_FILE, "r") as log:
            content = log.read().strip()
            # Handle potential multiple lines or corrupted content
            if '\n' in content:
                content = content.split('\n')[0] # Take only the first line
            return int(content)
    except (ValueError, FileNotFoundError) as e:
        print(f"Warning: Could not read {LOG_FILE} ({e}). Resetting progress.")
        with open(LOG_FILE, "w") as log:
            log.write("0")
        return 0

def update_last_scanned_index(index):
    with open(LOG_FILE, "w") as log:
        log.write(str(index))

last_scanned_index = get_last_scanned_index()

# Get a list of all directories
dirs = sorted([d for d in os.listdir() if os.path.isdir(d)])

# If all directories have been scanned, reset progress
if last_scanned_index >= len(dirs) and len(dirs) > 0:
    print("All directories have been scanned. Resetting progress.")
    update_last_scanned_index(0)
    last_scanned_index = 0
elif len(dirs) == 0:
    print("No directories found to scan.")
    exit()

print(f"Starting scan from directory index: {last_scanned_index}")

# Iterate through directories starting from the last scanned index
for i, dir_name in enumerate(dirs[last_scanned_index:], start=last_scanned_index):
    subs_file = os.path.join(dir_name, "subdomains", "subs-domain.txt")
    results_file = os.path.join(dir_name, "nuclei-results.txt")
    resume_file = os.path.join(dir_name, "resume.cfg")
    
    # Create subdomains directory if it doesn't exist within the target directory
    os.makedirs(os.path.join(dir_name, "subdomains"), exist_ok=True)

    if os.path.isfile(subs_file):
        if not os.path.isfile(results_file):
            print(f"Running nuclei on {subs_file} in directory {dir_name}...")
            
            # Run nuclei with the resume option and templates
            try:
                subprocess.run([
                    "nuclei",
                    "-l", subs_file,
                    "-o", results_file,
                    "-resume", resume_file,
                    "-s", "info,low,medium,high,critical", # Scan all severities
                    "-silent" # Suppress verbose output during scan
                ], check=True) # check=True will raise an exception for non-zero exit codes
                print(f"Nuclei scan completed for {dir_name}. Results saved in {results_file}.")

            except FileNotFoundError:
                print("Error: 'nuclei' command not found. Please ensure Nuclei is installed and in your PATH.")
                update_last_scanned_index(i) # Save current progress before exiting
                exit()
            except subprocess.CalledProcessError as e:
                print(f"Error running nuclei for {dir_name}: {e}")
                print(f"Nuclei output: {e.stdout.decode() if e.stdout else 'None'}")
                print(f"Nuclei error: {e.stderr.decode() if e.stderr else 'None'}")
                update_last_scanned_index(i) # Save current progress before exiting
                continue # Move to the next directory
        else:
            print(f"Skipping scan for {dir_name}: {results_file} already exists.")
        
        # Process results regardless if scanned now or previously existed
        if os.path.isfile(results_file):
            with open(results_file, "r") as results:
                findings = results.readlines()
                
                reportable_findings = []
                for line in findings:
                    # Filter out [info] and [ssl] findings
                    if re.search(r"\[info\]", line):
                        continue
                    
                    # Special handling for 'low' severity: only include if not an SSL finding
                    if re.search(r"\[low\]", line):
                        if not re.search(r"\[ssl\]", line, re.IGNORECASE):
                            reportable_findings.append(line.strip())
                    # Include critical, high, medium regardless of SSL
                    elif re.search(r"critical|high|medium", line, re.IGNORECASE):
                        reportable_findings.append(line.strip())

            if reportable_findings:
                domain_name = os.path.basename(dir_name) # Get the domain name from directory
                timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
                
                # Save filtered results to a dedicated file in ALL_RESULTS_DIR
                filtered_output_file = os.path.join(ALL_RESULTS_DIR, f"{domain_name}_nuclei_filtered_{timestamp}.txt")
                with open(filtered_output_file, "w") as f_out:
                    for finding in reportable_findings:
                        f_out.write(finding + "\n")
                
                print(f"Filtered reportable findings saved to {filtered_output_file}")
                
                # Send notification for reportable findings
                notify_message = f"Nuclei Findings for {domain_name}:\n" + "\n".join(reportable_findings)
                notify(notify_message)
            else:
                print(f"No reportable findings (critical, high, medium, or http-low) for {dir_name}.")
        else:
            print(f"Error: {results_file} not found after scan attempt for {dir_name}.")

    else:
        print(f"Skipping {dir_name}: 'subdomains/subs-domain.txt' not found.")
    
    # Update the log file with the current directory's index after processing
    update_last_scanned_index(i + 1)

# Final check: If all directories processed, reset log file for next run
if (last_scanned_index + 1) >= len(dirs): # Check if the last processed index was the actual last dir
    print("All directories have been scanned. Resetting progress for the next full cycle.")
    update_last_scanned_index(0)

print("Nuclei scanning script finished.")