#!/res/bin/busybox sh

alias bb=/res/bin/busybox

[ ! -e /data/PRIME-Kernel ] && bb mkdir -p /data/PRIME-Kernel
echo "" > /data/PRIME-Kernel/kernel.log

echo "FSTrim Excute" >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log
bb fstrim /system
bb fstrim /data
bb fstrim /cache
bb mount -t rootfs -o remount,rw rootfs
bb mount -o rw,remount /system
bb mount -o rw,remount /system /system

# bb --install -s /res/bin/
bb chmod -R 0755 /res/bin

# Support LGU-IWLAN
device=`getprop ro.bootloader`
carrier=${device:4:1}
if [ $carrier == "L" ]; then
	setprop sys.lgt.mobicoredaemon.enable true
fi

# Configure interactive
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/io_is_busy

# Configure cafactive
echo cafactive > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo cafactive > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/timer_rate
echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/timer_slack
echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/min_sample_time
echo 900000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/hispeed_freq
echo 85 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/go_hispeed_load
echo 75 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/target_loads
echo 19000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/above_hispeed_delay
echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/boostpulse_duration
echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/timer_rate
echo 80000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/timer_slack
echo 80000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/min_sample_time
echo 1200000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/hispeed_freq
echo 75 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/go_hispeed_load
echo "90" > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/target_loads
echo "20000" > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/above_hispeed_delay
echo 80000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/boostpulse_duration
echo 100000 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/max_freq_hysteresis
echo 100000 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/max_freq_hysteresis

#echo interactive > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
#echo interactive > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor

# io_is_busy
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/cafactive/io_is_busy
echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/cafactive/io_is_busy
echo 1 > /sys/devices/virtual/sec/sec_slow/io_is_busy

# fix some kernel value

for i in /sys/block/*/queue/scheduler; do echo fiops > $i; done
for i in /sys/block/*/queue/add_random; do echo 0 > $i; done
for i in /sys/block/*/queue/rq_affinity; do echo 2 > $i; done

echo Y > /sys/module/mmc_core/parameters/use_spi_crc
echo 0 > /proc/sys/kernel/randomize_va_space
echo 0 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk
echo 1 > /sys/kernel/logger_mode/logger_mode
echo 720 > /sys/kernel/hmp/up_perf_threshold
echo 500000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 1300000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 800000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
echo 1800000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq

echo 30 > /sys/module/zswap/parameters/max_pool_percent

echo "1 1200000 1200000 0 0 1" > /sys/class/input_booster/key/freq
echo "1 0 500 0" > /sys/class/input_booster/key/time
echo "2 0 1200000 0 0 0" > /sys/class/input_booster/touch/freq
echo "3 0 800000 0 0 0" > /sys/class/input_booster/touch/freq
echo "1 0 0 0" > /sys/class/input_booster/touch/time
echo "2 130 500 0" > /sys/class/input_booster/touch/time
echo "3 0 500 0" > /sys/class/input_booster/touch/time

if [ ! -f /system/.knox_removed ]; then
    bb rm -rf /system/app/Bridge
    bb rm -rf /system/app/KnoxAttestationAgent
    bb rm -rf /system/app/KnoxFolderContainer
    bb rm -rf /system/app/KnoxSetupWizardClient
    bb rm -rf /system/app/SwitchKnoxI
    bb rm -rf /system/app/SwitchKnoxII
    bb rm -rf /system/app/SPDClient
    bb rm -rf /system/app/AASAservice
    bb rm -rf /system/app/bbCAgent
    bb rm -rf /system/priv-app/SPDClient
    bb rm -rf /system/priv-app/KLMSAgent
    bb rm -rf /system/container
    
    touch /system/.knox_removed
fi

bb chmod -R 0755 /res/bin

echo init.d script start >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log
if [ -d /system/etc/init.d ]; then
    for i in $(ls /system/etc/init.d); do
        echo init.d-postboot @ /system/etc/init.d/$i
        sh /system/etc/init.d/$i
    done
fi;
echo init.d script is end >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log

bb mount -t rootfs -o remount,ro rootfs
bb mount -o remount,ro /system
bb mount -o remount,ro /system /system

