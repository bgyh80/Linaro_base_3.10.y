#!/bin/bash

export ARCH=arm
#export CROSS_COMPILE=/home/dq/dev/UBERTC-arm-eabi/bin/arm-eabi-
export CROSS_COMPILE=/home/dq/dev/UBERTC-arm-eabi-6.0/bin/arm-eabi-
export CROSS_COMPILE=/home/dq/dev/UBERTC-arm-linux-androideabi-5.3/bin/arm-linux-androideabi-

TMPDIR=./build-files/tmp
CDATE=$(date +"%Y%m%d")
CDIR=$PWD
KERNEL_VERSION=$(cat .config | grep -m 1 "CONFIG_LOCALVERSION" | sed s/[^0-9.]//g)
KERNEL_NAME="G850-PRIME_Kernel-v$KERNEL_VERSION.zip"
COMPRESS="lzop -9"

DTB=g850s-boot.img-dtb
RAMDISK_TW=./ramdisk/tw
RAMDISK_CM=./ramdisk/cm12
BUILD_G850_TW=1
BUILD_G850_CM=1
BUILD_G850_TWRP=1

# echo "RAMDISK: $RAMDISK"

function mtp_sec() {
    sed -i -e "s/# CONFIG_USB_ANDROID_SAMSUNG_MTP is not set/CONFIG_USB_ANDROID_SAMSUNG_MTP=y/g" .config
}
function mtp_nosec() {
    sed -i -e "s/CONFIG_USB_ANDROID_SAMSUNG_MTP=y/# CONFIG_USB_ANDROID_SAMSUNG_MTP is not set/g" .config
}

function clean(){
	find ./drivers/sensorhub -name '*.o' -exec rm {} \;
	find ./drivers/misc/modem_v1 -name '*.o' -exec rm {} \;
}

function cleardir() {
    CDIR=$PWD
    cd $1

    find . -type f \( -iname \*.rej \
                    -o -iname \*.orig \
                    -o -iname \*.bkp \
                    -o -iname \*.ko \
                    -o -iname \*.c.BACKUP.[0-9]*.c \
                    -o -iname \*.c.BASE.[0-9]*.c \
                    -o -iname \*.c.LOCAL.[0-9]*.c \
                    -o -iname \*.c.REMOTE.[0-9]*.c \
                    -o -iname \*.org \
                    -o -iname \*.old \) \
                        | parallel --no-notice rm -fv {};

    rm -rf tmp/* > /dev/null 2>&1
    rm Module.symvers > /dev/null 2>&1
    rm .version > /dev/null 2>&1
    rm -R ./include/config > /dev/null 2>&1
    rm -R ./include/generated > /dev/null 2>&1
    rm -R ./arch/arm/include/generated > /dev/null 2>&1

    cd $CDIR
    chmod 644 $1/file_contexts > /dev/null 2>&1
    chmod 644 $1/se* > /dev/null 2>&1
    chmod 644 $1/*.rc > /dev/null 2>&1
    chmod 750 $1/init* > /dev/null 2>&1
    chmod 640 $1/fstab* > /dev/null 2>&1
    chmod 644 $1/default.prop > /dev/null 2>&1
    chmod 771 $1/data > /dev/null 2>&1
    chmod 755 $1/dev > /dev/null 2>&1
    chmod 755 $1/proc > /dev/null 2>&1
    chmod 750 $1/sbin > /dev/null 2>&1
    chmod 750 $1/sbin/* > /dev/null 2>&1
    chmod 755 $1/res > /dev/null 2>&1
    chmod 755 $1/res/* > /dev/null 2>&1
    chmod 755 $1/res/bin > /dev/null 2>&1
    chmod 755 $1/res/bin/* > /dev/null 2>&1
    chmod 755 $1/sys > /dev/null 2>&1
    chmod 755 $1/system > /dev/null 2>&1
}
