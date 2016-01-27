#!/system/bin/sh

alias bb=/res/bin/busybox

bb mount -t rootfs -o rw,remount rootfs
bb mount -o rw,remount /system
bb mount -o rw,remount /system /system

echo "" >> /data/PRIME-Kernel/kernel.log
echo ---- start postboot script ---- >> /data/PRIME-Kernel/kernel.log
echo "" >> /data/PRIME-Kernel/kernel.log

echo init.d-postboot script is end >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log

# Init.d
if [ ! -e /system/etc/init.d-postboot ]; then
  bb mkdir /system/etc/init.d-postboot
  bb chown -R root.root /system/etc/init.d-postboot
  bb chmod -R 755 /system/etc/init.d-postboot
fi;

echo init.d-postboot script is start >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log

for i in $(ls /system/etc/init.d-postboot); do
    echo init.d-postboot @ /system/etc/init.d-postboot/$i
    sh /system/etc/init.d-postboot/$i
done

/res/bin/busybox mount -t rootfs -o ro,remount rootfs
/res/bin/busybox mount -o remount,ro /system
/res/bin/busybox mount -o remount,ro /system /system

