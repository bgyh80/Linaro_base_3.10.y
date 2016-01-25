#!/res/bin/busybox sh

cat << CTAG
{
    name:{en:"Storage", ko:"저장소"},
    elements:[
	{ SPane:{
		title:"SPI CRC Settings",
		description:{en:" Enabling software CRCs on the data blocks can be a significant (30%) performance cost, and for other reasons may not always be desired. CRC is a mechanism aiming to prevent data corruption when enabled (reduce the performance around 30%). So if you disable it (improve the performance), there may be a chance you run into problems. Use it at your risk. Default is Enabled.", ko:" CRC는 데이터 손상 방지를 목표로 하는 매커니즘입니다.\n데이터 블록에 소프트웨어 방식의 CRC가 사용되면 약 30%의 성능이 저하됩니다.\n안정성을 추구한다면 Enabled로 설정하세요."},
	}},
        { SOptionList:{
		default:`cat /sys/module/mmc_core/parameters/use_spi_crc`,
		action:"generic /sys/module/mmc_core/parameters/use_spi_crc",
		values:{
			"N":"Disabled",
			"Y":"Enabled",
		}
	}},
   { SDescription:{description:""} },

    { SPane:{
		title:{en:"I/O schedulers", ko:"I/O 스케줄러"},
		description:{en:"Set the active I/O elevator algorithm. The scheduler decides how to handle I/O requests and how to handle them.", ko:" 스케줄러는 I/O 요청을 처리하는 알고리즘을 결정하며 각각 다른 특성을 가집니다.\n* 미리읽기 값이 크다고 해서 반드시 더 빠른 것은 아닙니다."}
    }},
	{ SOptionList:{
		title:{en:"Internal storage scheduler", ko:"내부 저장소 스케줄러"},
		default:`cat /sys/block/mmcblk0/queue/scheduler | /res/bin/busybox awk 'NR>1{print $1}' RS=[ FS=]`,
		action:"scheduler /sys/block/mmcblk0/queue/scheduler",
		values:[`while read values; do /res/bin/busybox printf "%s, \n" $values | /res/bin/busybox tr -d '[]'; done < /sys/block/mmcblk0/queue/scheduler`]
	}},
	{ SSeekBar:{
		title:{en:"Internal storage read-ahead", ko:"내부 저장소 미리읽기 크기"},
		max:4096,
		min:128,
		unit:" kB",
		step:128,
		default:`cat /sys/block/mmcblk0/queue/read_ahead_kb`,
		action:"generic /sys/block/mmcblk0/queue/read_ahead_kb"
	}},
	{ SDescription:{
		description:" "
	}},
   `if [ -e "/sys/block/mmcblk1" ]; then
        $STR/json.gen.io2
    else
        echo '{ SDescription:{
        description:" 외장 SD카드를 장착했음에도 이 메세지가 나온다면 재부팅하거나 재시작 메뉴에서 '시냅스 재시작'을 눌러주세요."}},
        { SDescription:{
            description:" "
        }},
        '
    fi`

	{ SPane:{
		title:{en:"Dynamic FSync",ko:"Dynamic FSync (동적 파일 동기화)"}
	}},
	{ SCheckBox:{
		description:{en:" While screen is on file sync is disabled, when screen is off a file sync is called to flush all outstanding writes and restore file sync operation as normal. Increases speed, but a possible decrease in data integrity, also could create reboot and kernel panic. Default is Enabled.", ko:"화면이 켜져있는 동안에는 파일 동기화를 비동기식으로 처리하고 화면이 꺼졌을 때는 동기식으로 처리하여 성능을 향상시킵니다.\n<경고!> 예상되지 않은 재부팅 또는 커널 패닉 시 동기화 되지 않은 앱 데이터가 손상(초기화)될 수 있습니다.\n기기가 불안정하다면 해제하는 것이 안전하며, 일반적으로는 사용하는 것을 추천합니다."},
		label:{en:"Enable Dynamic FSync", ko:"Dynamic FSync 사용"},
		default:`cat /sys/kernel/dyn_fsync/Dyn_fsync_active`,
		action:"generic /sys/kernel/dyn_fsync/Dyn_fsync_active"
	}},
	{ SDescription:{
		description:" "
	}},
	{ SPane:{
		title:"General I/O Tunables",
		description:" Set the internal storage general tunables"
	}},
	{ SDescription:{
		description:" "
	}},
	{ SCheckBox:{
		description:" Maintain I/O statistics for this storage device. Disabling will break I/O monitoring apps. Default is Enabled.",
		label:"I/O Stats",
		default:`cat /sys/block/mmcblk0/queue/iostats`,
		action:"ioset queue iostats"
	}},
	{ SDescription:{
		description:" "
	}},
	{ SCheckBox:{
		description:" Treat device as rotational storage. Default is Disabled",
		label:"Rotational",
		default:`cat /sys/block/mmcblk0/queue/rotational`,
		action:"ioset queue rotational"
	}},
	{ SDescription:{
		description:" "
	}},
    { SOptionList:{
        title:"No Merges",
        description:"Types of merges (prioritization) the scheduler queue for this storage device allows.",
        default:`cat /sys/block/mmcblk0/queue/nomerges`,
        action:"generic /sys/block/mmcblk0/queue/nomerges",
        values:{
            0:"All", 1:"Simple Only", 2:"None"
        }
    }},
    { SOptionList:{
        title:"RQ Affinity",
        description:"Try to have scheduler requests complete on the CPU core they were made from. Higher is more aggressive.",
        default:`cat /sys/block/mmcblk0/queue/rq_affinity`,
        action:"generic /sys/block/mmcblk0/queue/rq_affinity",
        values:{
            0:"Disabled", 1:"Enabled", 2:"Aggressive"
        }
    }},
    { SDescription:{
		description:" "
	}},
	{ SPane:{
		title:"I/O Scheduler Tunables"
	}},
	{ SDescription:{
		description:""
	}},
	{ STreeDescriptor:{
		path:"/sys/block/mmcblk0/queue/iosched",
		generic: {
			directory: {},
			element: {
				SGeneric: { title:"@BASENAME" }
			}
		},
		exclude: [ "weights", "wr_max_time" ]
	}},
    ]
}
CTAG
