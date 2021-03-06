#!/bin/bash
# Author: grigruss@ya.ru (vk.com/grigruss)
# Group in VK vk.com/nixscript
# Группа в ВК vk.com/nixscript
# Github: github.com/interactive-dd/interactive-dd
# Interactive shell for dd.
# Интерактивная обёртка для команды dd
# Упростит использование команды,
# поможет выбрать устройство и другие параметры.
# Лицензия MIT, читайте файл LICENSE.md

# Global vars
# Глобальные переменные
idev=      # Источник (Input device)
odev=      #	Приёмник (Output device)
blockSize= #	Размер блока (BlockSize)
d=         # Под всякую чушь (Temporary var)
list=      # Для списков файлов/дисков (For lists of files/disks)

idd_header=
idd_target=
idd_target1=
idd_thankfulness=
idd_author_lic=
idd_choise_source=
idd_choise_f=
idd_choise_d=
idd_choise_source1=
idd_choise_source2=
idd_read_source_dest=
idd_read_source_dest1=
idd_type_filename=
idd_type_filename1=
idd_file_exists=
idd_file_not_found=
idd_source=
idd_choise_destination=
idd_file_exists_exit=
idd_destination=
idd_filelist=
idd_type_from_kbd=
idd_partitions=
idd_umount=
idd_mount=
idd_source_choised=
idd_dest_choised=
idd_blocksize=
idd_command=
idd_check_cmd=
idd_ready_to_write=
idd_umount_dev=
idd_process=
idd_done=
idd_alldone=

# echo errors not to generic stout but to stderr для феншуя
function echoerr() { echo -e "$@" 1>&2; }

# Load locales
IFS=$'\n'
# load localization from the folder where the idd script is located, for easifying of running it in development purposes
# get the path of the script itself, where it is located (https://stackoverflow.com/questions/4774054/reliable-way-for-a-bash-script-to-get-the-full-path-to-itself))
script_path=$(dirname "$(realpath -s "$0")")
if cat "$script_path/translations/*.trans" >/dev/null
	then
		locales_directory="$script_path/translations"
	else
		locales_directory="/usr/share/idd/translations"
fi
# check if a locale for the current system language is available
if [ -f "$locales_directory/${LANG:0:2}.trans" ]
	then
		translations_file="$locales_directory/${LANG:0:2}.trans"
	else
		echoerr "The localization of interactive-dd for your language is not available; we will use an English locale; however, you can contribute localsation to https://github.com/nixscript/interactive-dd/"
		translations_file="$locales_directory/en.trans"
fi
# check if the localization file is available
idd_localization_file_not_found=
if [ ! -f $translations_file ]
	then
		echoerr "$translations_file: $idd_localization_file_not_found "
fi
while IFS= read -r line; do
    if [[ ! $line ]]; then continue; fi
    nm=${line%%=*}
    if [[ ${nm:0:3} != "idd" ]]; then continue; fi
    var=${line##*=}
    export "$nm"="$var"
done <"$translations_file"

# Check root
if [[ $(whoami) != "root" ]]; then
    echo -e "\\n\\t\\e[33;5mRun as root! You have no rights.\\e[0m\\n"
    exit 2
fi

# check if we will be able to work, e.g. /proc/partitions may be not available in chroot, in a container etc.
idd_proc_partions_not_found=
if [ ! -f /proc/partitions ]
	then
		i=
		echoerr "/proc/partitions $idd_proc_partions_not_found /proc, /dev, /sys (for i in proc sys dev; do mount --bind /$i chroot_dir/$i)"
fi

# Show header
# Рисует шапку/заголовок
showHeader() {
    echo -e "\\e[37;45m\\e[2J\\e[1;0H"
    echo -e "$idd_header dd (v0.4.3)\\e[0m\\e[37;45;1m"
    echo -e "$idd_target"
    echo -e "$idd_target1"
    echo -e "$idd_thankfulness"
    echo -e "$idd_author_lic"
}

# Choise 1, device from
# Выбор устройства, с которого читать
choiseDeviceFrom() {
    showHeader
    echo -e "$idd_choise_source"
    read -r -n 1 c
    case "$c" in
    f)
        d="$idd_choise_f"
        echo -e "$idd_choise_source1"
        ;;
    d)
        d="$idd_choise_d"
        echo -e "$idd_choise_source2"
        ;;
    *) choiseDeviceFrom ;;
    esac
    if [[ $d == "$idd_choise_f" ]]; then
        showFiles
    else
        showDevices
    fi
    echo -e "$idd_read_source_dest $d$idd_read_source_dest1"
    read -r file
    sl="${#list[*]}"
    if [[ $d == "$idd_choise_f" && $file == "$sl" ]]; then
        echo -e "$idd_type_filename $d$idd_type_filename1"
        read -r ff
        if [[ -e "$ff" ]]; then
            echo -e "$idd_file_exists"
            list[$sl]="$ff"
        else
            echoerr -e "$idd_file_not_found"
            exit 2
        fi
    fi
    showHeader
    echo -e "$idd_source $d ${list[$file]}\\e[30;47m\\e[13H\\e[0J"
    idev="${list[$file]}"
    echo -e "\\e[30B\\e[0m\\n"
}

# Choise device to
# Выбор устройства на которое пишем
choiseDeviceTo() {
    showHeader
    echo -e "$idd_choise_destination"
    read -r -n 1 c
    case "$c" in
    f)
        d="$idd_choise_f"
        echo -e "$idd_choise_source1"
        ;;
    d)
        d="$idd_choise_d"
        echo -e "$idd_choise_source2"
        ;;
    *) choiseDeviceTo ;;
    esac
    if [[ $d == "$idd_choise_d" ]]; then
        showDevices
        echo -e "$idd_read_source_dest $d$idd_read_source_dest1"
        read -r file
    else
        echo -e "$idd_type_filename $d$idd_type_filename1"
        read -r ff
        if [[ -e "$ff" && $ff != "/dev/null" ]]; then
            echo -e "$idd_file_exists_exit"
            exit 2
        fi
        file=0
        list=("$ff")
    fi
    showHeader
    echo -e "$idd_destination $d ${list[$file]}\\e[30;47m\\e[13H\\e[0J"
    odev="${list[$file]}"
    echo -e "\\e[30B\\e[0m\\n"
}

# Show numbered list of files from current directory
# Вывод нумерованного списка файлов в текущей директории
showFiles() {
    echo -e "$idd_filelist"
    count=1
    fileList=("$(ls ./*.i* 2>/dev/null)")
    for file in ${fileList[*]}; do
        echo -e "\\t\\t$count) $file"
        list[$count]=$file
        count=$((count + 1))
    done
    echo -e "\\t\\t$count$idd_type_from_kbd"
}

# Show numbered list of devices
# Вывод нумерованного списка устройств с разделами
showDevices() {
    count=1
    l=
    devList=$(fdisk -l | grep "\\/dev\\/")
    IFS=$'\n'
    for l in $devList; do
        if [[ ${l:1:3} == "dev" ]]; then
            echo -e "\\t$l"
        else
            IFS=" " read -r -a dev <<< "$l"
            devLength="${#dev[1]}"
            devLength=$((devLength - 1))
            list[$count]="${dev[1]:0:devLength}"
            IFS=$'\n'
            echo -e "$count)\\e[4m$l$idd_partitions "
            count=$((count + 1))
        fi
    done
}

# Get device block size
# Определение размера блока
getBlockSize() {
    if [[ ! -e "/sys/block${odev:4}/queue/logical_block_size" ]]; then
        blockSize=
        return
    fi
    logicalBlockSize=$(cat "/sys/block${odev:4}/queue/logical_block_size")
    range=$(cat "/sys/block${odev:4}/range")
    blockSize=$((logicalBlockSize * "$range"))
    blockSize=$((blockSize / 1024))
    if [[ ! $blockSize ]]; then
    	blockSize=
    else
    	blockSize="${blockSize}M"
    fi
}

# Show params, confirm and run dd
# Вывод собранных данных, подтверждение и выполнение dd
showData() {
    mdev=$(mount | grep "$odev")
    if [[ ! $mdev ]]; then mnt="$idd_umount"
    else
        IFS=$' '
        IFS=" " read -r -a m <<<"$mdev"
        mnt="$idd_mount ${m[2]}"
    fi
    showHeader
    echo -e "\\e[30;47m\\e[12H\\e[0J"
    echo -e "$idd_source_choised\\t$idev"
    echo -e "$idd_dest_choised\\t$odev\\t$mnt\\e[0m\\e[30;47m"
    echo -e "$idd_blocksize\\t$blockSize"
    if [[ ! $blockSize ]]; then pBlockSize=""; else pBlockSize="bs=$blockSize "; fi
    echo -e "$idd_command\\e[30;43m dd if=$idev of=$odev ${pBlockSize}status=progress \\e[0m\\e[30;47m"
    echo -e "$idd_check_cmd"
    echo -e "$idd_ready_to_write $idev -> $odev ? [y/N]"
    read -r y
    if [[ $y == "y" || $y == "Y" ]]; then
        if [[ $mdev ]]; then
            echo -e "$idd_umount_dev $odev? [y/N]"
            read -r -n 1 u
            if [[ $u == "y" || $u == "Y" ]]; then umount "$odev"; fi
        fi
        echo -e "$idd_process\\e[0m\\e[30;43m dd if=$idev of=$odev ${pBlockSize}status=progress \\e[0m\\e[30;47m\\e[0J"
        if [[ ! $blockSize ]]; then
            dd if="$idev" of="$odev" status=progress
        else
            dd if="$idev" of="$odev" bs="$blockSize" status=progress
        fi
        echo -e "$idd_done\\e[0m\\e[30;43m dd if=$idev of=$odev ${pBlockSize}status=progress \\e[0m\\e[30;47m"
        echo -e "$idd_alldone"
        read -r -n 1
    fi
}
showHeader
choiseDeviceFrom
choiseDeviceTo
getBlockSize
showData
echo -e "\\e[0m\\e[0J"
