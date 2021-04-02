#!/bin/bash

clear

#Get Hostname
hostname=$(cat /etc/hostname)

#Get System Model
model=$(/usr/sbin/dmidecode -s system-product-name)

while read -r arg1 _
do
	if [[ $arg1 == System ]]
	then
		model=None
	fi
done < <(echo $model)

#Get System Manufacturer
manufacturer=$(/usr/sbin/dmidecode -s system-manufacturer)

while read -r arg1 _
do
	if [[ $arg1 == System ]]
	then
		manufacturer=None
	fi
done < <(echo $manufacturer)

#Get System Serial Number
serial=$(/usr/sbin/dmidecode -s system-serial-number)

while read -r arg1 _
do
	if [[ $arg1 == System ]]
	then
		serial=None
	fi
done < <(echo $serial)

#Get Operating System / Distribution
osver=$(echo $(cat /etc/*-release | grep PRETTY_NAME) | cut -c 13-)

#Get installed Network Card
while read -r _ _ _ arg1
do
	nic=$arg1
done < <(lspci | grep Ethernet)

#Get IP Address
ipaddress=$(hostname -I)

if [ -z $ipaddress ]
then
	ipaddress=$(hostname --ip-addresses)
fi

#Get Total Memory and Amount of Free RAM
while read -r val1 val2 _
do
	if [[ $val1 == MemTotal: ]]
	then
		totalMem=$val2
	fi
	if [[ $val1 == MemFree: ]]
	then
		freeMem=$val2
	fi
	if [[ $val1 == Cached: ]]
	then
		cachedMem=$val2
	fi
done </proc/meminfo
freeMem=$(($freeMem + $cachedMem))

#Get CPU Type
while read -r arg1 arg2 arg3 arg4
do
	if [[ $arg1 == model ]]
	then
		if [[ $arg2 == name ]]
		then
			cpuname=$arg4
		fi
	fi
done </proc/cpuinfo

#Get installed Video Card
while read -r _ _ _ _ arg
do
	gpu=$arg
done < <(lspci | grep VGA)

#Import Data into MySQL Database
sqlip=192.168.1.6
sqluser=rick
sqlpass=michelob

mysql -h $sqlip -u $sqluser -p$sqlpass << EOF

	use application;

	CREATE TABLE IF NOT EXISTS inventory(
	hostname VARCHAR(128),
	model VARCHAR(128),
	manufacturer VARCHAR(128),
	serial VARCHAR(128),
	os_ver VARCHAR(128),
	nic_type VARCHAR(128),
	ip_addr VARCHAR(128),
	cpu_type VARCHAR(128),
	gpu_type VARCHAR(128),
	mem_total VARCHAR(32),
	mem_free VARCHAR(32),
	disk_total VARCHAR(32),
	disk_used VARCHAR(32),
	disk_name VARCHAR(32),
	the_time VARCHAR(32));

	DELETE FROM inventory
	WHERE hostname='$hostname';

	INSERT INTO inventory(
	hostname,model,manufacturer,
	serial,os_ver,nic_type,ip_addr,
	cpu_type,gpu_type,mem_total,
	mem_free,the_time) VALUES (
	'$hostname','$model','$manufacturer',
	'$serial','$osver','$nic','$ipaddress',
	'$cpuname','$gpu','$totalMem','$freeMem',
	'$(date)');

EOF

#Get Total Disk Size and Amount Used
while read -r arg1 arg2 arg3 _ _ arg4
do
	if [[ $arg1 != tmpfs ]]
	then
		diskSize=$(echo $arg2 | rev | cut -c 2- | rev)
		diskUsed=$(echo $arg3 | rev | cut -c 2- | rev)
		diskMount=$arg4
		mysql -h $sqlip -u $sqluser -p$sqlpass -e "USE application;INSERT INTO inventory(hostname,disk_total,disk_used,disk_name) VALUES ('$hostname','$diskSize','$diskUsed','$diskMount');"
	fi
done < <(df -h | grep /dev/)

