#!/tmp/script/busybox sh
alias bb=/tmp/script/busybox

device=`getprop ro.bootloader`
BL=${device:0:4}


if [[ $BL != "N910" ]] && [[ $BL != "N915" ]] && [[ $BL != "N916" ]]; then
	echo "detect=error" > /tmp/script/device-name.prop
	return 1
else
   echo "device=$BL" > /tmp/script/device-name.prop
   echo "detect=yes" >> /tmp/script/device-name.prop
fi
