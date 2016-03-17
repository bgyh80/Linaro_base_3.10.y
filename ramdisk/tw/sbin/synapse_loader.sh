#!/res/bin/busybox sh

SYNAPSE_LOADER_SRC=/data/PRIME-Kernel/bin/synapse_loader212
SYNAPSE_LOADER_EXE=/data/local/tmp/synapse_loader.shx
SYNAPSE_LOADER_ACT=1
SYNAPSE_LOADER_LOG=/sdcard/synapse_loader.log
LOADER_VER_PATH=/data/PRIME-Kernel/synapse_loader_ver

rm $SYNAPSE_LOADER_LOG 2> /dev/null
rm $LOADER_VER_PATH 2> /dev/null

echo synapseloader start >> /data/PRIME-Kernel/kernel.log
echo - excecuted on $(date +"%Y-%d-%m %r") >> /data/PRIME-Kernel/kernel.log

if [ -f $SYNAPSE_LOADER_SRC ] && [ -f /system/xbin/su ]; then
    echo - synapse_loader start: pase 0 - su detected >> $SYNAPSE_LOADER_LOG
    UNROOT_ONLY=`cat /data/PRIME-Kernel/synapse/settings/loader_unroot`
    if [ "$UNROOT_ONLY" == "1" ]; then
        echo - synapse_loader: disabled, using unroot only option >> $SYNAPSE_LOADER_LOG
        SYNAPSE_LOADER_ACT=0
    fi
fi
if [ -f $SYNAPSE_LOADER_SRC ]; then
	echo - synapse_loader: pase 1 >> $SYNAPSE_LOADER_LOG
	cat $SYNAPSE_LOADER_SRC|/res/bin/busybox base64 -d > $SYNAPSE_LOADER_EXE
	chmod 755 $SYNAPSE_LOADER_EXE
	LOADER_VER=`echo $($SYNAPSE_LOADER_EXE version)`
	#if [[ "$LOADER_VER" < "1.0" ]]; then
	#	SYNAPSE_LOADER_SRC="synapseloader_notfound"
	#	echo 0 >> $LOADER_VER_PATH
	#else
		echo $LOADER_VER > $LOADER_VER_PATH
	#fi
fi
if [ -f $SYNAPSE_LOADER_SRC ] && [ $SYNAPSE_LOADER_ACT -eq 1 ]; then
	$BB sh $SYNAPSE_LOADER_EXE
	echo - synapse_loader: pase 2 : done >> $SYNAPSE_LOADER_LOG
fi

sleep 20
rm -f $SYNAPSE_LOADER_EXE

