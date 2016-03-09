#!/bin/bash

source ./set_env.sh
cleardir $RAMDISK_TW

rm $TMPDIR/* 2>/dev/null

if [ ! -e ./arch/arm/boot/zImage ]; then
    mtp_sec && make -j4
fi
./utility/mkbootfs $RAMDISK_TW | $COMPRESS > $TMPDIR/ramdisk.img
./utility/mkbootimg --base 0x10000000 --pagesize 2048 --kernel ./arch/arm/boot/zImage --ramdisk $TMPDIR/ramdisk.img --dt ./utility/$DTB -o $TMPDIR/boot.img
echo -n "SEANDROIDENFORCE" >> $TMPDIR/boot.img
cp -f  $TMPDIR/boot.img ../HostPC/Kernel/boot.img

echo ""
echo - wating device...
#adb wait-for-device
echo - push boot.img to /device/sdcard/ ...
adb shell "rm -f /data/local/tmp/boot.img"
adb push $TMPDIR/boot.img /data/local/tmp/boot.img
echo - flashing image...
adb shell "su -c dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p9"
adb shell "dd if=/data/local/tmp/boot.img of=/dev/block/mmcblk0p9"
adb shell "rm -f /data/local/tmp/boot.img && mount /system"
echo - flashing done. device reboot after 2s
rm $TMPDIR/* 2>/dev/null
sleep 2
adb reboot
echo ""

