#!/bin/bash
#create a short preview video from an input video

sourcefile=$1
destfile=$2

if [ ! -e "$sourcefile" ] 
then
	echo 'Please provide an existing input file.'
	exit
fi

if [ "$destfile" == "" ]
then
       echo 'Please provide an output preview file name.'
exit
fi

extension=${destfile#*.}
length=$(ffprobe $sourcefile -show_format 2>&1 | sed -n 's/duration=//p' | awk '{print int($0)}')

starttimeseconds=20
snippetlengthinseconds=4
desiredsnippets=5
minlength=$(($snippetlengthinseconds*$desiredsnippets))
dimensions=320:-1

tempdir=snippets
listfile=list.txt

echo 'Video length: '$length
if [ "$length" -lt "$minlength" ]
then
	echo 'Video is too short. Exiting.'
	exit
fi

mkdir $tempdir
interval=$((($length-$starttimeseconds)/$desiredsnippets))
for i in $(seq 1 $desiredsnippets)
do
	start=$(($(($i*$interval))+$starttimeseconds))
	formattedstart=$(printf "%02d:%02d:%02d\n" $(($start/3600)) $(($start%3600/60)) $(($start%60)))
	echo 'Generating preview part ' $i $formattedstart
	ffmpeg -i $sourcefile -vf scale=$dimensions -preset fast -qmin 1 -qmax 1 -ss $formattedstart -t $snippetlengthinseconds $tempdir/$i.$extension
done

echo 'Generating final preview file'

for f in $tempdir/*
do
	echo  "file '$f'" >> $listfile
done

ffmpeg -f concat -safe 0 -i $listfile -c copy $destfile

echo 'Done! Check ' $destfile '!'
rm -rf $tempdir $listfile
