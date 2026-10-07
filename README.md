# Server Health Check

A simple Bash script that prints a quick health report of a Linux server.

## Uses

- Get a one-shot view of CPU, memory, disk, and inode usage
- Spot resource issues early, before they turn into downtime
- Flag problems with colour-coded status (🟢 OK, 🟡 WARNING, 🔴 CRITICAL)
- Schedule it with cron to generate regular reports (output is plain text when not run in a terminal)

## What is monitored

| Check | What it measures | 🟢 OK | 🟡 WARNING | 🔴 CRITICAL |
|---|---|---|---|---|
| CPU usage | Whole system, sampled over 1 second | < 75% | 75% to < 90% | ≥ 90% |
| Memory usage | Used vs total (total minus available) | < 75% | 75% to < 90% | ≥ 90% |
| Disk usage | Each mounted filesystem | < 75% | 75% to < 90% | ≥ 90% |
| Inode usage | Each mounted filesystem | < 75% | 75% to < 90% | ≥ 90% |
| Top 5 processes | PID, process name, user, %CPU | Info only | Info only | Info only |
| System info | OS, kernel, hostname, uptime, date and time | Info only | Info only | Info only |

## Usage

```bash
chmod +x health_check.sh
./health_check.sh            # colour output in terminal
./health_check.sh --plain    # no colours (for cron / email)
```

## Sample output

Tested on Red Hat Enterprise Linux 10.1.

![Sample output](Bash-Health-Check/sample-output.png)
