#!/sbin/sh

BB=/tmp/script/busybox

wbuildprop() {
    if [ ! `$BB grep $1 /system/build.prop` ]
    then
        echo "" >> /system/build.prop
        echo "$1=$2" >> /system/build.prop
    else
        $BB sed -i -e "s/$1=.*/$1=$2/g" /system/build.prop
    fi
}

#wbuildprop ro.config.tima 0
#wbuildprop ro.build.selinux 0
#wbuildprop ro.config.knox 0
#wbuildprop ro.securestorage.support false
#wbuildprop ro.securestorage.knox false
#wbuildprop wlan.wfd.hdcp disable

if [ ! `$BB grep "SYSTEMLESS" /data/.supersu` ]; then
    echo SYSTEMLESS=false>>/data/.supersu
else
    $BB sed -i -e "s/SYSTEMLESS=.*/SYSTEMLESS=false/g" /data/.supersu
fi

mkdir /system/etc/init.d

$BB chmod -R 0755 /data/PRIME-Kernel/*
$BB chmod -R 0755 /system/etc/init.d
$BB chown -R root.root /system/etc/init.d
$BB chmod -R 0755 /system/etc/init.d-postboot
$BB chown -R root.root /system/etc/init.d-postboot

#if [ ! -e /system/xbin/busybox ]; then
#	cp /tmp/script/busybox /system/xbin/busybox
#	chmod 06755 /system/xbin/busybox;
#fi;
#for i in $(/system/xbin/busybox --list); do
#    $BB ln -sf /system/xbin/busybox /system/xbin/$i
#done

#$BB ln -sf /sbin/uci /system/xbin/uci

