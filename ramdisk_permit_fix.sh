#!/bin/bash

source ./set_env.sh

CDIR=$PWD

cd $RAMDISK

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
chmod 644 $RAMDISK/file_contexts
chmod 644 $RAMDISK/se*
chmod 644 $RAMDISK/*.rc
chmod 750 $RAMDISK/init*
chmod 640 $RAMDISK/fstab*
chmod 644 $RAMDISK/default.prop
chmod 771 $RAMDISK/data
chmod 755 $RAMDISK/dev
chmod 755 $RAMDISK/proc
chmod 750 $RAMDISK/sbin
chmod 750 $RAMDISK/sbin/*
chmod 755 $RAMDISK/res
chmod 755 $RAMDISK/res/*
chmod 755 $RAMDISK/sys
chmod 755 $RAMDISK/system

