# Bug Bounty Reconnaissance Automation Toolkit

## Overview

This article documents a complete reconnaissance automation setup designed for bug bounty hunters working with multiple programs. The toolkit automates subdomain enumeration, alive host detection, vulnerability scanning, and continuous monitoring for new attack surfaces.

## Quick Setup

For rapid deployment on a new machine, I use [nahamsec's bbht (Bug Bounty Hunting Tools)](https://github.com/nahamsec/bbht) which provides automated installation of essential reconnaissance tools.

## Toolkit Architecture

### Core Components

1. **Subdomain Enumeration** - `sub-enum.sh`
2. **New Subdomain Monitor** - `newsubs.sh`
3. **Vulnerability Scanner** - `nuclei.py`
4. **Panel Detector** - `pannel-detector.sh`

### Tool Dependencies

- **subfinder**: Passive subdomain enumeration
- **httpx**: Fast HTTP probe with status codes and titles
- **nuclei**: Automated vulnerability scanner
- **assetfinder**: Additional subdomain discovery
- **notify**: Push notifications for findings

## Setup Instructions

### 1. Initial Setup

```bash
# Clone the bbht setup (one-time setup on new machines)
git clone https://github.com/nahamsec/bbht
cd bbht
./install.sh

# Create your working directory
mkdir ~/scanners-nuclei
cd ~/scanners-nuclei
```

### 2. Target Configuration

Create `hp-target-2025.txt` with your domains (one per line):

```
example.com
target.io
bugbounty.com
```

### 3. Tool Configuration

All scripts use this target file and create organized directory structures:

```
domain.com/
├── subdomains/
│   ├── subs-domain.txt          # All discovered subdomains
│   ├── old_subs.txt              # Previous scan results
│   ├── new_subs_TIMESTAMP.txt    # Newly found subdomains
│   └── subdomain_history.txt     # Historical tracking
├── httpx.txt                     # Alive endpoints with details
├── title_and_status.txt          # Cleaned HTTP response data
├── nuclei-results.txt            # Vulnerability scan results
└── summary.txt                   # Recon summary
```

## Tool Deep Dive

### 1. Primary Reconnaissance: `sub-enum.sh`

**Purpose**: Automated subdomain enumeration and HTTP probing for all targets

**Features**:
- Progress tracking (resume from interruption)
- Parallel processing with rate limiting
- Automatic directory structure creation
- Status code and title extraction
- Summary report generation

**Usage**:

```bash
chmod +x sub-enum.sh
./sub-enum.sh
```

**Key Features**:
- Saves progress in `recon_progress.log`
- Creates detailed summaries per domain
- 300s timeout for subfinder, 600s for httpx
- Automatic retry on failure
- Notification support via `notify` tool

**Output Example**:
```
[2025-09-07 03:08:16] Processing domain 1/139: rtreefinance.com
[2025-09-07 03:08:22] Created directory structure for rtreefinance.com
[2025-09-07 03:08:39] Found 5 subdomains for rtreefinance.com
[2025-09-07 03:08:47] Found 5 alive endpoints for rtreefinance.com
```

### 2. Continuous Monitoring: `newsubs.sh`

**Purpose**: Monitor for new subdomains and immediately test them

**Features**:
- Differential scanning (only new subdomains)
- Immediate httpx probing of new discoveries
- Automatic nuclei scanning of new assets
- Historical tracking with timestamps
- Continuous or one-time mode

**Usage**:

```bash
chmod +x newsubs.sh

# One-time scan
./newsubs.sh

# Continuous monitoring (runs every 30 minutes)
./newsubs.sh --continuous

# Skip vulnerability scanning
./newsubs.sh --no-scan

# Skip probing
./newsubs.sh --no-probe
```

**Real Output Example**:
```
[2025-09-14 20:24:35] NEW: 🎉 Found 1 NEW subdomains for 1inch.dev:
[2025-09-14 20:24:35] NEW:   ➤ api.1inch.dev
[2025-09-14 20:26:35] NEW: 🌐 https://api.1inch.dev [401]
```

**Notifications**:
The script sends real-time notifications for:
- New subdomain discoveries
- Alive endpoints found
- Critical/High vulnerabilities detected

**Historical Tracking**:
Each domain maintains a `subdomain_history.txt`:
```
[2025-09-14 20:24:35] New subdomains found: 1
  api.1inch.dev
[2025-09-14 22:01:05] New subdomains found: 18
  airdrop.latoken.com
  exchange.latoken.com
  wallet.latoken.com
  ...
```

### 3. Vulnerability Scanning: `nuclei.py`

**Purpose**: Automated vulnerability scanning with intelligent filtering

**Features**:
- Resume capability for large scans
- Filters out noise (info, SSL findings)
- Saves only reportable findings
- Progress tracking
- Automatic notifications for critical findings

**Usage**:

```bash
python3 nuclei.py
```

**Filtering Logic**:
- ❌ **Excluded**: `[info]` and `[ssl]` findings
- ✅ **Included**: `[low]` (non-SSL), `[medium]`, `[high]`, `[critical]`

**Output Structure**:
```
nuclei_filtered_results/
├── domain1_nuclei_filtered_20250914_203845.txt
├── domain2_nuclei_filtered_20250914_215620.txt
└── domain3_nuclei_filtered_20250914_223012.txt
```

**Progress Tracking**:
- Saves current position in `scan_progress.log`
- Automatically resumes from last scanned domain
- Resets to 0 after completing all domains

### 4. Admin Panel Discovery: `pannel-detector.sh`

**Purpose**: Discover administrative interfaces and login panels

**Features**:
- Uses assetfinder for additional subdomain discovery
- Tests common admin paths
- Shows ALL results (no filtering)
- Optional httpx probing
- Admin panel specific scanning

**Usage**:

```bash
chmod +x pannel-detector.sh

# Full scan with probing and admin detection
./pannel-detector.sh

# Skip HTTP probing
./pannel-detector.sh --no-probe

# Skip admin panel scanning
./pannel-detector.sh --no-admin
```

**Admin Paths Tested**:
```
/admin
/administrator
/wp-admin
/panel
/dashboard
/login
/portal
/console
/manager
/cpanel
/api
```

**Output**:
```
domain.com/
├── all-domains.txt       # All assetfinder results
├── alive-domains.txt     # HTTP probed domains
└── admin-panels.txt      # Discovered admin interfaces
```

## The Secret Sauce: Continuous Monitoring Strategy

### Why New Subdomain Monitoring Works

**The Reality of Bug Bounty Hunting:**
- Most hunters scan once and move on
- Companies constantly deploy new infrastructure
- New subdomains = untested attack surface = vulnerabilities
- **First to find = First to report = Bounty paid**

### My Proven Schedule

I run `newsubs.sh` on this schedule based on program activity:

```bash
# Active programs (frequent deployments): Every 1-3 days
./newsubs.sh

# Stable programs: Once a week
./newsubs.sh

# High-value targets: Daily monitoring
./newsubs.sh --continuous  # Runs every 30 minutes
```

### Real Success Stories

This methodology has directly resulted in **multiple paid bounties**:

1. **New API endpoints discovered** → Authentication bypass found → Bounty paid
2. **Staging subdomains appeared** → Exposed credentials → Bounty paid  
3. **New admin panels detected** → Weak authentication → Bounty paid
4. **Dev environments discovered** → SQL injection → Bounty paid

### The Timeline That Matters

```
Day 0:  Company deploys new feature (new subdomain created)
Day 1:  Your script finds it, httpx probes it, nuclei scans it
Day 2:  You report the vulnerability
Day 3:  Other hunters find it (too late!)
```

**Speed is everything.** This toolkit keeps you ahead of the competition.

### What the Data Shows

From monitoring 139 programs over one scan cycle:

- **14 domains** had new subdomains appear
- **39 new subdomains** discovered total
- **Multiple** had live services running
- **Several** had immediate security issues

**Example from real logs:**
```
[2025-09-14 22:01:05] latoken.com: 18 new subdomains
  ➤ exchange.latoken.com - Live
  ➤ api.latoken.com - Live  
  ➤ wallet.latoken.com - Live
```

Each of these is a potential vulnerability waiting to be found.

### After Initial Scan

```bash
# Resume nuclei scanning if interrupted
python3 nuclei.py

# Check progress
cat scan_progress.log
```

## Real-World Results

From the log files, here are actual results from a recent scan:

### New Subdomain Discoveries

**September 14, 2025 - 14 domains had new subdomains:**

- `1inch.dev`: 1 new subdomain (api.1inch.dev)
- `latoken.com`: 18 new subdomains (airdrop, exchange, wallet, etc.)
- `hacken.io`: 3 new subdomains (audits, email, extractor)
- `machinefi.com`: 2 new subdomains (ai, docs)
- `bingx.com`: 3 new subdomains (api-base, general, open-api-swap)
- `toobit.com`: 1 new subdomain (api-vv)

### Vulnerability Findings

The nuclei scanner found reportable vulnerabilities across multiple targets:
- `1inch.dev`: 16 findings
- `bitdelta.com`: 11 findings
- `bitexen.com`: 19 findings
- `toobit.com`: 26 findings
- `white.market`: 20 findings

### Scale

The toolkit processed:
- **139 domains** from bug bounty programs
- **10,000+ subdomains** discovered
- **6,000+ alive endpoints** probed
- **200+ new subdomains** found during monitoring

## Tips & Best Practices

### 1. Rate Limiting

```bash
# Modify sleep timers in scripts to avoid rate limits
sleep 2  # Between domains
sleep 0.1  # Between admin path tests
```

### 2. Notification Setup

Configure `notify` for Discord/Slack/Telegram:

```bash
# Install notify
go install -v github.com/projectdiscovery/notify/cmd/notify@latest

# Configure providers
notify -provider-config
```

### 3. Continuous Monitoring

Use systemd or cron for automated runs:

```bash
# Add to crontab for hourly new subdomain checks
0 * * * * cd /path/to/scanners-nuclei && ./newsubs.sh >> /var/log/newsubs.log 2>&1
```

### 4. Resource Management

```bash
# Monitor resource usage
htop

# Limit concurrent processes in scripts
ulimit -u 50
```

### 5. Data Management

```bash
# Archive old results monthly
tar -czf results_$(date +%Y%m).tar.gz */*.txt

# Clean up old temporary files
find . -name "temp-*.txt" -mtime +7 -delete
```

## Troubleshooting

### Common Issues

**1. Subfinder returns no results:**
```bash
# Update subfinder
go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest

# Check API keys in ~/.config/subfinder/provider-config.yaml
```

**2. Script interrupted during scan:**
```bash
# Check progress logs
cat recon_progress.log
cat scan_progress.log

# Resume is automatic on next run
./sub-enum.sh  # Continues from last position
```

**3. Nuclei scan hangs:**
```bash
# Check if nuclei templates are updated
nuclei -update-templates

# Reduce rate limit
nuclei -rl 30 -l targets.txt
```

**4. Too many open files error:**
```bash
# Increase file descriptor limit
ulimit -n 4096
```

## Advanced Customization

### Modify Subfinder Sources

Edit scripts to add/remove sources:

```bash
subfinder -d "$domain" -sources censys,securitytrails,virustotal -silent
```

### Custom Nuclei Templates

```bash
# Scan with specific templates
nuclei -l targets.txt -t ~/nuclei-templates/exposures/ -o results.txt

# Scan with custom severity
nuclei -l targets.txt -s critical,high -o results.txt
```

### Custom Admin Paths

Edit `pannel-detector.sh`:

```bash
admin_paths=(
    "/admin"
    "/api/v1"
    "/graphql"
    "/your-custom-path"
)
```

## Security Considerations

1. **Never commit sensitive data**: Add `.gitignore` for results
2. **Respect rate limits**: Avoid aggressive scanning
3. **Follow scope**: Only scan authorized targets
4. **Secure storage**: Encrypt sensitive findings
5. **API keys**: Store in environment variables, not scripts

## Performance Metrics

From production use:

- **Average scan time per domain**: 2-5 minutes
- **Full 139-domain scan**: ~5-6 hours
- **New subdomain check**: 2-3 hours
- **Nuclei full scan**: 8-10 hours
- **Memory usage**: ~500MB peak
- **Disk usage**: ~100MB per domain

## Conclusion

This toolkit provides a complete automated reconnaissance solution for bug bounty hunters managing multiple programs. Key benefits:

✅ **Automation**: Set it and forget it  
✅ **Continuous monitoring**: Never miss new assets  
✅ **Smart filtering**: Only see what matters  
✅ **Resume capability**: Never lose progress  
✅ **Scalable**: Handles 100+ programs  
✅ **Notification support**: Real-time alerts  

## Resources

- [nahamsec/bbht](https://github.com/nahamsec/bbht) - Initial setup
- [ProjectDiscovery Tools](https://github.com/projectdiscovery) - Core tools
- [HackenProof](https://hackenproof.com/) - Bug bounty platform

## Contributing

Contributions welcome! Areas for improvement:
- Additional reconnaissance tools integration
- Better notification templates
- Performance optimizations
- Error handling improvements

---

**Author**: Security Researcher  
**Platform**: HackenProof Community  
**Last Updated**: January 2025

*Remember: Always obtain proper authorization before scanning targets. This toolkit is for authorized security testing only.*
