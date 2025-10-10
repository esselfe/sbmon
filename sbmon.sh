#!/bin/bash

# 20251005
# System usage monitor first intended for use in the sway status bar.
# Currently there's cpu, disk, memory and networking usage.
# Written by Stephane Fontaine (esselfe) under the GPLv3.

SBMON_VERSION="0.1.2"
if [ "$1" = "-V" -o "$1" = "--version" ]; then
    echo "sbmon $SBMON_VERSION"
    exit 0
fi

SBMON_SYS_CONFIG_FILE="/etc/sway/sbmon.conf"
[ -f "$SBMON_SYS_CONFIG_FILE" ] && source "$SBMON_SYS_CONFIG_FILE"

SBMON_USR_CONFIG_FILE="$HOME/.config/sway/sbmon.conf"
[ -f "$SBMON_USR_CONFIG_FILE" ] && source "$SBMON_USR_CONFIG_FILE"

[ -z "$ITEM_WIDTH" ] && ITEM_WIDTH=20
[ -z "$SHOW_LABELS" ] && SHOW_LABELS="1"
if [ -z "$NO_UTF8" ]; then
    [ -z "$CELL_BUSY" ] && CELL_BUSY='█'
    [ -z "$CELL_BUFFER" ] && CELL_BUFFER='▓'
    [ -z "$CELL_IDLE" ] && CELL_IDLE='▒'
    [ -z "$CELL_READ" ] && CELL_READ='◀'
    [ -z "$CELL_WRITE" ] && CELL_WRITE='▶'
else
    [ -z "$CELL_BUSY" ] && CELL_BUSY='#'
    [ -z "$CELL_BUFFER" ] && CELL_BUFFER='@'
    [ -z "$CELL_IDLE" ] && CELL_IDLE='='
    [ -z "$CELL_READ" ] && CELL_READ='<'
    [ -z "$CELL_WRITE" ] && CELL_WRITE='>'
fi
[ -z "$TIMESTRFMT" ] && TIMESTRFMT='%A %Y-%m-%d %H:%M:%S.%2N'

# SLEEP_TIME controls for how long to wait before the next loop iteration
# Other potential sleep times are 10, 3, 0.5 or 0.2
[ -z "$SLEEP_TIME" ] && SLEEP_TIME=1
SLEEP_MSEC=$(echo "$SLEEP_TIME * 1000" | bc | sed "s/\.[0-9]*//")
SLEEP_MSEC=$(( (SLEEP_MSEC > 0 ? SLEEP_MSEC : 100) ))

# See 'man 3 sysconf' for the _SC_CLK_TCK system spec.
CPU_USER_HZ=100
CPU_CORES=$(nproc)

CPU_PERCENT=0
CPU_PERCENT_PER_CELL=$((100 / $ITEM_WIDTH))

CPU_STAT_LINE="$(head -n1 /proc/stat)"

CPU_TICKS_BUSY=$(echo "$CPU_STAT_LINE" |
  awk '{ print ( $2 + $3 + $4 + $6 + $7 + $8 + $9 + $10 ) * 100 }')
CPU_TICKS_BUSY_PREV=$CPU_TICKS_BUSY
CPU_TICKS_BUSY_DIFF=0

CPU_TICKS_IDLE=$(echo "$CPU_STAT_LINE" | awk '{ print $5 * 100 }')
CPU_TICKS_IDLE_PREV=$CPU_TICKS_IDLE
CPU_TICKS_IDLE_DIFF=0

CPU_TICKS_TOTAL=$((CPU_TICKS_BUSY + CPU_TICKS_IDLE))
CPU_TICKS_TOTAL_PREV=$CPU_TICKS_TOTAL
CPU_TICKS_TOTAL_DIFF=0

[ -z "$DISK_DEVICE" ] && DISK_DEVICE=sda
#[ -z "$DISK_DEVICE" ] && DISK_DEVICE=nvme0n1
DISK_IO_MSEC=$(awk '{ print $10 }' /sys/block/$DISK_DEVICE/stat)
DISK_IO_MSEC_PREV=$DISK_IO_MSEC
DISK_IO_MSEC_DIFF=0
DISK_IO_MSEC_PER_CELL=$((SLEEP_MSEC / ITEM_WIDTH))

MEM_KB_TOTAL=$(awk '/^MemTotal:/ { print $2 }' /proc/meminfo)
MEM_MB_TOTAL=$((MEM_KB_TOTAL / 1024))

MEM_KB_FREE=$(awk '/^MemAvailable:/ { print $2 }' /proc/meminfo)
MEM_MB_FREE=$((MEM_KB_FREE / 1024))

MEM_KB_BUFFER=$(awk '/^Buffers:/ { print $2 }' /proc/meminfo)
MEM_MB_BUFFER=$((MEM_KB_BUFFER / 1024))

MEM_KB_CACHED=$(awk '/^Cached:/ { print $2 }' /proc/meminfo)
MEM_MB_CACHED=$((MEM_KB_CACHED / 1024))

MEM_MB_USED=$((MEM_MB_TOTAL - MEM_MB_FREE))
MEM_MB_PER_CELL=$((MEM_MB_TOTAL / ITEM_WIDTH))

# See your available devices in /sys/class/net
# Autodetect based on the configured route.
[ -z "$NET_DEVICE" ] &&
	NET_DEVICE="$(ip route show default |
	  grep -Eo '[[:space:]]+dev[[:space:]]+[a-zA-Z0-9@-_.:]+[[:space:]]+' |
	    sed 's/ dev //;s/[[:space:]]//g' | tr -d '\n')"
#NET_DEVICE=lo
#NET_DEVICE=eth0
#NET_DEVICE=wlan0
#NET_DEVICE=enp3s0
#NET_DEVICE=wlp12s0

[ -z "$NET_RXTX_MAX" ] && NET_RXTX_MAX=1500000
NET_BYTES_PER_CELL=$((NET_RXTX_MAX / ITEM_WIDTH))
NET_RX_BYTES=$(cat /sys/class/net/$NET_DEVICE/statistics/rx_bytes)
NET_TX_BYTES=$(cat /sys/class/net/$NET_DEVICE/statistics/tx_bytes)
NET_RX_PREV=$NET_RX_BYTES
NET_TX_PREV=$NET_TX_BYTES
NET_RX_DIFF=0
NET_TX_DIFF=0
NET_TOTAL_BYTES=$((NET_RX_BYTES + NET_TX_BYTES))
NET_TOTAL_PREV=$NET_TOTAL_BYTES
NET_TOTAL_DIFF=0

update_cpu() {
	CPU_STAT_LINE="$(head -n1 /proc/stat)"

	CPU_TICKS_BUSY=$(echo "$CPU_STAT_LINE" |
	  awk '{ print ( $2 + $3 + $4 + $6 + $7 + $8 + $9 + $10 ) * 100 }')
	CPU_TICKS_BUSY_DIFF=$((CPU_TICKS_BUSY - CPU_TICKS_BUSY_PREV))
	CPU_TICKS_BUSY_PREV=$CPU_TICKS_BUSY

	CPU_TICKS_IDLE=$(echo "$CPU_STAT_LINE" | awk '{ print $5 * 100 }')
	CPU_TICKS_IDLE_DIFF=$((CPU_TICKS_IDLE - CPU_TICKS_IDLE_PREV))
	CPU_TICKS_IDLE_PREV=$CPU_TICKS_IDLE

	CPU_TICKS_TOTAL=$((CPU_TICKS_BUSY + CPU_TICKS_IDLE))
	CPU_TICKS_TOTAL_DIFF=$((CPU_TICKS_TOTAL - CPU_TICKS_TOTAL_PREV))
	CPU_TICKS_TOTAL_PREV=$CPU_TICKS_TOTAL

	CPU_PERCENT=$((CPU_TICKS_BUSY_DIFF / CPU_USER_HZ / CPU_CORES))
}
update_cpu

update_disk() {
	DISK_IO_MSEC=$(awk '{ print $10 }' /sys/block/$DISK_DEVICE/stat)
	DISK_IO_MSEC_DIFF=$((DISK_IO_MSEC - DISK_IO_MSEC_PREV))
	DISK_IO_MSEC_PREV=$DISK_IO_MSEC
}
update_disk

update_mem() {
	MEM_INFO="$(cat /proc/meminfo)"
	MEM_KB_TOTAL=$(echo "$MEM_INFO" | awk '/^MemTotal:/ { print $2 }')
	MEM_MB_TOTAL=$((MEM_KB_TOTAL / 1024))
	MEM_KB_FREE=$(echo "$MEM_INFO" | awk '/^MemAvailable:/ { print $2 }')
	MEM_MB_FREE=$((MEM_KB_FREE / 1024))
	MEM_KB_BUFFER=$(echo "$MEM_INFO" | awk '/^Buffers:/ { print $2 }')
	MEM_MB_BUFFER=$((MEM_KB_BUFFER / 1024))
	MEM_KB_CACHED=$(echo "$MEM_INFO" | awk '/^Cached:/ { print $2 }')
	MEM_MB_CACHED=$((MEM_KB_CACHED / 1024))
	MEM_MB_USED=$((MEM_MB_TOTAL - MEM_MB_FREE))
}
update_mem

update_net() {
	NET_RX_BYTES=$(cat /sys/class/net/$NET_DEVICE/statistics/rx_bytes)
	NET_TX_BYTES=$(cat /sys/class/net/$NET_DEVICE/statistics/tx_bytes)
	NET_RX_DIFF=$((NET_RX_BYTES - NET_RX_PREV))
	NET_TX_DIFF=$((NET_TX_BYTES - NET_TX_PREV))
	NET_RX_PREV=$NET_RX_BYTES
	NET_TX_PREV=$NET_TX_BYTES

	NET_TOTAL_BYTES=$((NET_RX_BYTES + NET_TX_BYTES))
	NET_TOTAL_DIFF=$((NET_TOTAL_BYTES - NET_TOTAL_PREV))
	NET_TOTAL_PREV=$NET_TOTAL_BYTES
}
update_net

while true; do
	CURRENT_TIME=$(date +"$TIMESTRFMT")

	update_cpu
	CPU_STR=""
	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * CPU_PERCENT_PER_CELL)) -gt $CPU_PERCENT ]] && break;
		CPU_STR+="$CELL_BUSY"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		CPU_STR+="$CELL_IDLE"
		((++cnt))
	done

	update_disk
	DISK_STR=""
	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * DISK_IO_MSEC_PER_CELL)) -gt $DISK_IO_MSEC_DIFF ]] && break;
		DISK_STR+="$CELL_BUSY"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		DISK_STR+="$CELL_IDLE"
		((++cnt))
	done

	update_mem
	MEM_STR=""
	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * MEM_MB_PER_CELL)) -gt $MEM_MB_USED ]] && break;
		MEM_STR+="$CELL_BUSY"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * MEM_MB_PER_CELL)) -gt $((MEM_MB_USED + MEM_MB_BUFFER + MEM_MB_CACHED)) ]] && break;
		MEM_STR+="$CELL_BUFFER"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		MEM_STR+="$CELL_IDLE"
		((++cnt))
	done

	update_net
	NET_STR=""
	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * NET_BYTES_PER_CELL)) -gt $NET_RX_DIFF ]] && break;
		NET_STR+="$CELL_READ"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * NET_BYTES_PER_CELL)) -gt $((NET_RX_DIFF + NET_TX_DIFF)) ]] && break;
		NET_STR+="$CELL_WRITE"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		NET_STR+="$CELL_IDLE"
		((++cnt))
	done

	if [[ "$SHOW_LABELS" == "1" ]]; then
		printf "CPU:$CPU_STR Mem:$MEM_STR Disk:$DISK_STR Net:$NET_STR $CURRENT_TIME\n"
	else
		printf "$CPU_STR $MEM_STR $DISK_STR $NET_STR $CURRENT_TIME\n"
	fi

	sleep $SLEEP_TIME
done

