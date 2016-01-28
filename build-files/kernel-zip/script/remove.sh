#!/sbin/sh

alias bb=/tmp/script/busybox

#bb rm -rf /cache/*
if [ ! -e /data/media/0/Synapse/.do_not_remove_data ]; then
    bb rm -rf /data/data/com.af.synapse
    bb rm -rf /data/data/com.af.synapse-*
    bb rm -rf /data/PRIME-Kernel/synapse/settings
fi
#bb rm -f /data/su.img
bb rm /system/xbin/uci

#if [ -e /system/xbin/busybox ]; then
#    for i in $(/system/xbin/busybox --list); do
#        bb rm /system/xbin/$i
#    done
#    rm /system/xbin/busybox
#fi;
