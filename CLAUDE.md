# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

sbmon is a Bash-based system usage monitor designed for the Sway window manager status bar. It provides real-time monitoring of CPU, memory, disk I/O, and network usage with configurable visual output using Unicode or ASCII characters.

**Version**: 0.1.2
**License**: GPLv3
**Author**: Stephane Fontaine (esselfe)

## Core Architecture

### Main Script: sbmon.sh

The monitor operates as a single-file Bash script with a continuous loop architecture:

1. **Initialization Phase** (lines 8-113): Loads configuration, sets defaults, initializes monitoring variables
2. **Update Functions** (lines 114-167): Four update functions that query system state from `/proc` and `/sys`:
   - `update_cpu()`: Reads `/proc/stat` and calculates CPU usage based on tick differences
   - `update_disk()`: Reads `/sys/block/$DISK_DEVICE/stat` for I/O milliseconds
   - `update_mem()`: Parses `/proc/meminfo` for memory statistics
   - `update_net()`: Reads `/sys/class/net/$NET_DEVICE/statistics/` for RX/TX bytes
3. **Main Loop** (lines 169-241): Continuously updates metrics, builds visual strings, and outputs formatted status

### Visual Representation Strategy

Each metric is rendered as a bar of configurable width (`ITEM_WIDTH`, default 20 characters):
- **CPU/Disk/Memory**: Uses `CELL_BUSY` (█) for active usage, `CELL_IDLE` (▒) for free
- **Memory**: Additionally uses `CELL_BUFFER` (▓) to show buffer/cache between used and free
- **Network**: Uses `CELL_READ` (◀) for RX traffic and `CELL_WRITE` (▶) for TX traffic

The script calculates how many cells to fill based on percentage of maximum for each metric.

### Configuration System

Configuration is loaded in a two-tier hierarchy:
1. System-wide config: `/etc/sway/sbmon.conf` (when installed as root)
2. User config: `$HOME/.config/sway/sbmon.conf` (overrides system config)

User config takes precedence over system config, which takes precedence over hardcoded defaults.

## Development Commands

### Installation
```bash
# Install to /usr/local (as root or user)
make install

# Install to custom prefix
make PREFIX=/opt install

# Uninstall
make uninstall
```

Installation behavior differs based on user privileges:
- As root: Installs to `$PREFIX/bin` and config to `/etc/sway/`
- As user: Installs to `$PREFIX/bin` or `$HOME/bin` and config to `$HOME/.config/sway/`

### Testing
```bash
# Run directly (no installation needed)
./sbmon.sh

# Test with custom config by sourcing it first
source ./sbmon.conf
./sbmon.sh

# Test version flag
./sbmon.sh --version
```

### Configuration Testing
```bash
# Test with different settings
ITEM_WIDTH=30 SLEEP_TIME=0.5 ./sbmon.sh
NO_UTF8=1 ./sbmon.sh  # ASCII-only mode
SHOW_LABELS=0 ./sbmon.sh  # Hide labels
```

## Key Configuration Variables

- `ITEM_WIDTH` (default: 20): Width of each metric bar in characters
- `SLEEP_TIME` (default: 1): Seconds between updates (accepts decimals)
- `SHOW_LABELS` (default: 1): Show "CPU:", "Mem:" labels (0 to hide)
- `SHOW_PERCENT` (default: 0): Show percentage values after bars (e.g., "CPU:████▒▒▒▒25%")
- `NO_UTF8` (default: 0): Use ASCII characters instead of Unicode
- `DISK_DEVICE` (default: sda): Block device to monitor (check `/sys/block/`)
- `NET_DEVICE` (auto-detected): Network interface (auto-detects from default route)
- `NET_RXTX_MAX` (default: 1500000): Max bytes/second for network scaling
- `TIMESTRFMT` (default: '%A %Y-%m-%d %H:%M:%S.%2N'): Date format string

## Important Implementation Details

### CPU Usage Calculation
CPU usage is calculated using tick differences from `/proc/stat`:
- Reads all CPU tick counters (user, nice, system, idle, iowait, irq, softirq, steal, guest)
- Calculates busy ticks as sum of all non-idle counters
- CPU percentage = (busy_diff / total_diff) * 100
- Uses `_SC_CLK_TCK` value of 100 (hardcoded as `CPU_USER_HZ`)

### Network Device Detection
If `NET_DEVICE` is not configured, the script auto-detects it by parsing the default route from `ip route show default` (lines 89-92).

### Timing and Precision
- `SLEEP_TIME` is converted to milliseconds and clamped to minimum 100ms (lines 40-41)
- Network max bytes are adjusted proportionally to sleep time (line 102)
- All calculations use integer arithmetic except for CPU percentage (uses `bc`)

### Memory Representation
Memory bars show three zones:
1. Used memory (busy cells)
2. Buffer/cache memory (buffer cells)
3. Free memory (idle cells)

The script uses `MemAvailable` from `/proc/meminfo` rather than `MemFree` for more accurate available memory calculation.

### Percentage Display
When `SHOW_PERCENT=1`, each metric displays its percentage after the visual bar:
- **CPU**: Percentage of busy CPU time (0-100%)
- **Memory**: Percentage of used memory (0-100%)
- **Disk**: Percentage of time spent on I/O operations, capped at 100% (time-based metric)
- **Network**: Percentage relative to `NET_RXTX_MAX` - can exceed 100% to indicate throughput above the configured baseline (useful for detecting LAN transfers that exceed typical limits)

## Common Modifications

When modifying the script:
- All metric calculations follow the pattern: read current value → calculate difference from previous → update previous
- Visual string building uses the same pattern: fill busy cells → fill buffer cells (if applicable) → fill idle cells
- Configuration variables should use the pattern: `[ -z "$VAR" ] && VAR=default_value`
- System paths use `/proc` for process/system stats and `/sys` for device stats
