#!/bin/bash

source ./set_env.sh

rm $TMPDIR/* 2> /dev/null
#make clean

echo ""
rm .version 2>/dev/null

if [ $BUILD_G850_TW -eq 1 ]; then
	cleardir $RAMDISK_TW
    echo ""
    echo "------------------------ SM-G850x TW ----------------------------"
    mtp_sec && make -j4
    ./utility/mkbootfs $RAMDISK_TW | $COMPRESS > $TMPDIR/ramdisk.img
    ./utility/mkbootimg --base 0x10000000 --pagesize 2048 --kernel ./arch/arm/boot/zImage --ramdisk $TMPDIR/ramdisk.img --dt ./utility/$DTB -o $TMPDIR/g850tw-boot.img
    echo -n "SEANDROIDENFORCE" >> $TMPDIR/g850tw-boot.img
fi

if [ $BUILD_G850_CM -eq 1 ]; then
	cleardir $RAMDISK_CM
    echo ""
    echo "------------------------ SM-G850x CM ----------------------------"
    mtp_nosec && make -j4
    ./utility/mkbootfs $RAMDISK_CM | $COMPRESS > $TMPDIR/ramdisk.img
    ./utility/mkbootimg --base 0x10000000 --pagesize 2048 --kernel ./arch/arm/boot/zImage --ramdisk $TMPDIR/ramdisk.img --dt ./utility/$DTB -o $TMPDIR/g850cm-boot.img
    echo -n "SEANDROIDENFORCE" >> $TMPDIR/g850cm-boot.img
fi

if [ $BUILD_G850_TWRP -eq 1 ]; then
    TWRP=./twrp
	cleardir $TWRP
    echo ""
    echo "---------------------- build TWRP -----------------------"
    mtp_nosec && make -j4
    ./utility/mkbootfs $TWRP | $COMPRESS > $TMPDIR/ramdisk.img
    ./utility/mkbootimg --base 0x10000000 --pagesize 2048 --kernel ./arch/arm/boot/zImage --ramdisk $TMPDIR/ramdisk.img --dt ./utility/$DTB -o $TMPDIR/recovery.img
    echo -n "SEANDROIDENFORCE" >> $TMPDIR/recovery.img
    cd $TMPDIR && tar -cvf twrp-2.8.7.0-$CDATE-slte.tar recovery.img >/dev/null 2>&1 && cd $CDIR
    mv -f $TMPDIR/twrp-2.8.7.0-$CDATE-slte.tar ../HostPC/Kernel/
    mtp_sec
fi

cd $TMPDIR
tar -cvf bootimg.tar g850*-boot.img
xz -z -9 bootimg.tar
mv -f bootimg.tar.xz ../kernel-zip/bootimg.tar.xz
cd ../kernel-zip
rm $KERNEL_NAME
rm ../../../HostPC/Kernel/out/$KERNEL_NAME
7z a -mx9 $KERNEL_NAME *
zipalign -v 4 $KERNEL_NAME ../../../HostPC/Kernel/out/$KERNEL_NAME
rm bootimg.tar.xz
rm $KERNEL_NAME
cd $CDIR
rm $TMPDIR/* 2> /dev/null
echo ""
echo "------------------------   DONE!!   ----------------------------"
echo ""

