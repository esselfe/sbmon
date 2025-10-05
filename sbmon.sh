#!/bin/bash

# 20251005
# System usage monitor first intended for use in the sway status bar.
# Currently there's cpu, disk and networking usage.
# Written by Stephane Fontaine (esselfe) under the GPLv3.

ITEM_WIDTH=20

CELL_BUSY='#'
CELL_IDLE='='
echo "$LANG" | grep -q -i "utf" && {
    CELL_BUSY='█'
    CELL_IDLE='▒'
}

CPU_USER_HZ=100
CPU_CORES=$(nproc)
CPU_PERCENT=0

CPU_TICKS_BUSY=$(head -n1 /proc/stat |
  awk '{ print ( $2 + $3 + $4 + $6 + $7 + $8 + $9 + $10 ) * 100 }')
CPU_TICKS_BUSY_PREV=$CPU_TICKS_BUSY
CPU_TICKS_BUSY_DIFF=0

CPU_TICKS_IDLE=$(head -n1 /proc/stat | awk '{ print $5 * 100 }')
CPU_TICKS_IDLE_PREV=$CPU_TICKS_IDLE
CPU_TICKS_IDLE_DIFF=0

CPU_TICKS_TOTAL=$((CPU_TICKS_BUSY + CPU_TICKS_IDLE))
CPU_TICKS_TOTAL_PREV=$CPU_TICKS_TOTAL
CPU_TICKS_TOTAL_DIFF=0

CPU_PERCENT_PER_CELL=$((100 / $ITEM_WIDTH))

DISK_DEVICE=sda
#DISK_DEVICE=nvme0n1
DISK_IO_MSEC=$(awk '{ print $10 }' /sys/block/$DISK_DEVICE/stat)
DISK_IO_MSEC_PREV=$DISK_IO_MSEC
DISK_IO_MSEC_DIFF=0
DISK_IO_MSEC_PER_CELL=$((1000 / ITEM_WIDTH))

# See your available devices in /sys/class/net
# Autodetect based on the configured route.
NET_DEVICE="$(ip route show default | grep -Eo ' dev [a-z0-9]+ ' | sed 's/ dev //;s/ //g' | tr -d '\n')"
#NET_DEVICE=eth0
#NET_DEVICE=wlan0
#NET_DEVICE=enp3s0
#NET_DEVICE=wlp12s0

NET_RXTX_MAX=1500000
NET_RX_BYTES=0
NET_TX_BYTES=0
NET_TOTAL_BYTES=0
NET_BYTES_PREV=0
NET_BYTES_DIFF=0
NET_BYTES_PER_CELL=$((NET_RXTX_MAX / ITEM_WIDTH))

update_cpu() {
	CPU_TICKS_BUSY=$(head -n1 /proc/stat |
	  awk '{ print ( $2 + $3 + $4 + $6 + $7 + $8 + $9 + $10 ) * 100 }')
	CPU_TICKS_BUSY_DIFF=$((CPU_TICKS_BUSY - CPU_TICKS_BUSY_PREV))
	CPU_TICKS_BUSY_PREV=$CPU_TICKS_BUSY

	CPU_TICKS_IDLE=$(head -n1 /proc/stat | awk '{ print $5 * 100 }')
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

update_net() {
	NET_RX_BYTES=`cat /sys/class/net/$NET_DEVICE/statistics/rx_bytes`
	NET_TX_BYTES=`cat /sys/class/net/$NET_DEVICE/statistics/tx_bytes`
	NET_TOTAL_BYTES=$((NET_RX_BYTES + NET_TX_BYTES))
	NET_BYTES_DIFF=$((NET_TOTAL_BYTES - NET_BYTES_PREV))
	NET_BYTES_PREV=$NET_TOTAL_BYTES
}
update_net

while true; do
	CURRENT_TIME="$(date +'%A %Y-%m-%d %H:%M:%S')"

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

	update_net
	NET_STR=""
	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * NET_BYTES_PER_CELL)) -gt $NET_BYTES_DIFF ]] && break;
		NET_STR+="$CELL_BUSY"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		NET_STR+="$CELL_IDLE"
		((++cnt))
	done

	printf "CPU: $CPU_STR Disk: $DISK_STR Net: $NET_STR $CURRENT_TIME\n"

	sleep 1
done

