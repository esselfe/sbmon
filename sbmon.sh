#!/bin/bash

# 20251005
# System usage monitor first intended for use in the sway status bar.
# Currently there's only networking usage.
# Written by Stephane Fontaine (esselfe) under the GPLv3.

ITEM_WIDTH=20

CELL_BUSY='#'
CELL_IDLE='='
echo "$LANG" | grep -q -i "utf" && {
    CELL_BUSY='█'
    CELL_IDLE='▒'
}

# See your available devices in /sys/class/net
# Autodetect based on the configured route.
NET_DEVICE="$(ip route show default | grep -Eo ' dev [a-z0-9]+ ' | sed 's/ dev //;s/ //g' | tr -d '\n')"
#NET_DEVICE=eth0
#NET_DEVICE=wlan0
#NET_DEVICE=enp3s0
#NET_DEVICE=wlp12s0

NET_RX_BYTES=0
NET_TX_BYTES=0
NET_TOTAL_BYTES=0
NET_RXTX_MAX=1500000
NET_BYTES_PER_CELL=$((NET_RXTX_MAX / ITEM_WIDTH))

update_net_bytes() {
	NET_RX_BYTES=`cat /sys/class/net/$NET_DEVICE/statistics/rx_bytes`
	NET_TX_BYTES=`cat /sys/class/net/$NET_DEVICE/statistics/tx_bytes`
	NET_TOTAL_BYTES=$((NET_RX_BYTES + NET_TX_BYTES))
}
update_net_bytes

NET_BYTES_PREV=$NET_TOTAL_BYTES
while true; do
	CURRENT_TIME="$(date +'%A %Y-%m-%d %H:%M:%S')"
	update_net_bytes
	NET_BYTES_DIFF=$((NET_TOTAL_BYTES - NET_BYTES_PREV))
	NET_BYTES_PREV=$NET_TOTAL_BYTES
	STR=""

	cnt=1
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		[[ $((cnt * NET_BYTES_PER_CELL)) -gt $NET_BYTES_DIFF ]] && break;
		STR+="$CELL_BUSY"
		((++cnt))
	done
	while [[ $cnt -le $ITEM_WIDTH ]]; do
		STR+="$CELL_IDLE"
		((++cnt))
	done

	printf "$STR $CURRENT_TIME\n"

	sleep 1
done

