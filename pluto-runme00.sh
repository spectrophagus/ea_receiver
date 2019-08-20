DIR="/root"
DEV="/sys/bus/iio/devices/iio:device1"

iio_show() {
	if [ -e "$DEV/$1" ]; then
		echo -n "$DEV/$1: "
		cat "$DEV/$1"
	fi
}

iio_set() {
	if [ -e "$DEV/$1" ]; then
		echo "$2" > "$DEV/$1"
		iio_show "$1"
	else
		echo "$0: invalid device/option $DEV/$1"
	fi
}


start_background_monitor() { (
	mkfifo "$1"
	cat "$1" | while ! read -t 0 command; do
		(	echo -en '\rgain:'
			cat "$DEV/in_voltage0_hardwaregain" 
			echo -e " rssi:-"
			cat "$DEV/in_voltage0_rssi"
		) | sed 's/\([^\.]\)0* /\1 /g;s/ dB/dB/g' | tr -d '\n'
		echo -n "    "
		usleep 100000
	done 
	#done | tr '\n' ' '
	dir="$(dirname "$1")"
	rm "$1"
	rmdir "$dir"
	echo
) & }

start_capture() {
	out="$1"
	echo "Capturing EA_LAN packetes into: $out"
	echo "Press enter to stop."
	iio_readdev -b 1048576 cf-ad9361-lpc | \
		"$DIR/ea_receiver.sc16.arm7l.static" -c 128 - | \
		tee -a "$out" &
}

iio_set out_altvoltage0_RX_LO_frequency 915000000
iio_set in_voltage_rf_bandwidth 28000000
iio_set in_voltage_sampling_frequency 51200000
iio_set in_voltage0_gain_control_mode fast_attack
iio_show rx_path_rates

monitor_dir="$(mktemp -dt rf_monitor.XXXXXX)"
monitor_fifo="$monitor_dir/fifo"
start_background_monitor "$monitor_fifo"
monitor_pid="$!"
start_capture "$DIR/ea.out"

read dummy
echo -n "Exiting..."
echo halt > "$monitor_fifo"
jobs -p | head -1 | xargs -n 1 kill -INT
wait
