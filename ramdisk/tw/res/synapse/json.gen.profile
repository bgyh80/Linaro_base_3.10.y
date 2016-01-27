#!/res/bin/busybox sh

cat << CTAG
{
    name:{en:"BACKUP & RESTORE",ko:"백업 & 리스토어"},
    elements:[
	{ SDescription:{
		description:"<참고!> 새로 생성된 백업 프로파일과 커널 이미지는 '시냅스 재시작' 버튼을 누르거나 디바이스를 재시작 하면 목록에 나옵니다."
	}},
	{ SDescription:{
		description:""
	}},
	{ SPane:{
		title:"설정 프로파일"
	}},
	{ SDescription:{
		description:""
	}},
	{ SGeneric:{
		title:"프로파일 이름",
		default:"None",
		action:"generic $STR/settings/backup_profile",
	}},
	{ SDescription:{
		description:""
	}},
	{ SDescription:{
		description:" 프로파일 이름을 입력하고 앱 상단의 확인(체크) 버튼을 누른 후 '프로파일 백업 버튼'을 눌러 저장하세요. <참고!> 프로파일 이름을 입력 할 때는 반드시 키보드의 <엔터> 키를 누르셔야 인식됩니다."
	}},
	{ SDescription:{
		description:""
	}},
	{ SButton:{
		label:"프로파일 백업",
		action:"restorebackup keepconfig",
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, APPLY ],
				to:"generic $STR/settings/backup_profile"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
	{ SOptionList:{
		title:"프로파일 선택",
		description:" 원하는 프로파일을 목록에서 선택 후 상단의 확인(체크) 버튼을 눌러야 적용(인식)됩니다.",
		action:"restorebackup pickconfig",
		default:"None",
		values:[ "None",
			`for BAK in \`$STR/actions/restorebackup listconfig\`; do
				echo "\"$BAK\","
			done`
		],
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, APPLY ],
				to:"generic $STR/settings/backup_profile"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
	{ SDescription:{
		description:"<참고!> 새로운 설정 프로파일을 불러오려면 '선택된 프로파일 복구' 버튼을 눌러 시냅스가 재시작 된 후 상단의 취소(x) 버튼을 누르세요."
	}},
	{ SDescription:{
		description:""
	}},
	{ SButton:{
		label:"선택된 프로파일 복구",
		action:"restorebackup applyconfig",
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, APPLY ],
				to:"restorebackup pickconfig"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
	{ SButton:{
		label:"시냅스 재시작",
		action:"devtools restart"
	}},
	{ SDescription:{
		description:""
	}},
	{ SButton:{
		label:"선택된 프로파일 삭제",
		action:"restorebackup delconfig",
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, APPLY ],
				to:"restorebackup pickconfig"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
	{ SPane:{
		title:"커널 이미지"
	}},
	{ SDescription:{
		description:""
	}},
	{ SGeneric:{
		title:"커널 이름",
		default:"None",
		action:"generic $STR/settings/backup_kernel",
	}},
	{ SDescription:{
		description:""
	}},
	{ SDescription:{
		description:" 커널 이름을 입력하고 앱 상단의 확인(체크) 버튼을 누른 후 '현재 커널 백업' 버튼을 눌러 백업하세요."
	}},
	{ SDescription:{
		description:""
	}},
	{ SButton:{
		label:"현재 커널 백업",
		action:"restorebackup keepboot /dev/block/platform/15540000.dwmmc0/by-name/BOOT",
		notify:[
			{
				on:APPLY,
				do:[ REFRESH, APPLY ],
				to:"generic $STR/settings/backup_kernel"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
	{ SOptionList:{
		title:"커널 이미지 선택",
        	description:" 원하는 이미지를 목록에서 선택 후 앱 상단의 확인(체크) 버튼을 눌러야 적용(인식)됩니다.",
		action:"restorebackup pickboot",
       		default:"None",
		values:[ "None",
`
			for IMG in \`$STR/actions/restorebackup listboot\`; do
			  echo "\"$IMG\","
			done
`
		]
	}},
	{ SDescription:{
		description:""
	}},
    	{ SButton:{
		label:"선택된 커널로 복구",
		action:"restorebackup flashboot /dev/block/platform/15540000.dwmmc0/by-name/BOOT"
	}},
	{ SDescription:{
		description:""
	}},
    	{ SButton:{
		label:"선택된 커널 삭제",
		action:"restorebackup delboot",
		notify:[
			{
				on:APPLY,
				do:[ RESET, REFRESH, ],
				to:"restorebackup pickboot"
			}
		]
	}},
	{ SDescription:{
		description:""
	}},
    ]
}
CTAG
