#!/tmp/script/busybox sh

alias bb=/tmp/script/busybox
CURDIR=$PWD
cd /tmp

get_prop() {
    str="$1="
    len=${#str}
    prop="/system/build.prop"
    ret=$(cat $prop | grep -m 1 "$str" | dd bs=1 skip=$len 2>/dev/null)
    echo $ret
}

find_boot_image() {
    for PARTITION in kern-a KERN-A android_boot ANDROID_BOOT kernel KERNEL boot BOOT lnx LNX; do
      BOOTIMAGE=$(readlink /dev/block/by-name/$PARTITION || readlink /dev/block/platform/*/by-name/$PARTITION || readlink /dev/block/platform/*/*/by-name/$PARTITION)
      if [ ! -z "$BOOTIMAGE" ]; then break; fi
    done
}

CARRIER=`getprop ro.bootloader|bb awk '{print tolower($0)}'`
MODEL=${device_name:0:4}
CM_DEVICE=$( get_prop ro.cm.device )
find_boot_image

echo " "
if [ -z $CM_DEVICE ]; then
    device="g850tw"
    echo "OS: TOUCHWIZ"
    echo "FILE  : $device-boot.img"
else
    device="g850cm"
    echo "OS: CyanogenMod"
    echo "FILE  : $device-boot.img"
fi
echo " "
bb tar -Jxf /tmp/bootimg.tar.xz $device-boot.img
if [ ! -z "$BOOTIMAGE" ]; then
    bb dd of=$BOOTIMAGE if=/tmp/$device-boot.img
else
    bb dd of=/dev/block/mmcblk0p9 if=/tmp/$device-boot.img
fi
rm bootimg.tar.xz

sync

cd $CURDIR
