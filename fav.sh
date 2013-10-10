#!/bin/bash
#	Script to create xspf playlist with location values from xspf playlist
#	containing title and creator values.
#	Copyright (C) 2011 Łukasz Wieczorek, mail: wieczorek1990@gmail.com
#	This program is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	(at your option) any later version.
#
#	This program is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty ofp
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	You should have received a copy of the GNU General Public License
#	along with this program.  If not, see <http://www.gnu.org/licenses/>.

usage() {
cat << EOF
This is a bash script that creates a music playlist in xspf format with location values from your lastfm loved tracks xspf file.
Formats supported: flac, mp3, ogg, wma.
Requirements:
	xmlstarlet for xspf support,
	python-mutagen containing mutagen-inspect for tags reading,
	[optional] xspf relaxing schema (xml version) for xspf validation (get it here - http://xspf.org/validation/).
Syntax:
	./fav.sh -d music-directory -p xspf-playlist [-e file-format-extension-iregex] [-o xspf-output-playlist] [-c xspf-relaxing-shema] [-v] [-q]
	d) specify where you want to search
	p) specify xspf playlist file location
	e) specify format extension, default is "mp3" (examples: "flac", "(mp3|flac|ogg|wma)")
	o) specify output file (useful with verbose), default is set to standard output
	c) specify xspf relaxing schema location
	v) set verbose on
	q) do not display progess information
Example usage:
$ ~/Skrypty/fav/fav.sh -d /media/luke/data/Muzyka -p ~/Dropbox/Dokumenty/Muzyka/wieczorek1990_lovedtracks.xspf -e "(mp3|flac|ogg)" -o ~/Dropbox/Dokumenty/Muzyka/Ulubione.xspf
Author: Łukasz Wieczorek
Contact: wieczorek1990 [at] gmail [dot] com
EOF
}

#dependencies check
if [ $(hash 'xmlstarlet' > /dev/null 2>&1; echo $?) = 1 ]; then
	echo "xmlstarlet is not installed."
	exit 1
fi
if [ $(hash 'mutagen-inspect' > /dev/null 2>&1; echo $?) = 1 ]; then
	echo "python-mutagen is not installed."
	exit 1
fi

VERBOSE=0
QUIET=0
out=0
relaxingSchema=0
format="mp3"
DIR="$( cd -P "$( dirname "$0" )" && pwd )"
date=$(date +"%d%m%y%H%m%s")

while getopts "hd:p:e:o:c:vq" OPTION
do
	case $OPTION in
	h)
		usage
		exit 1
		;;
	d)
		directory=$OPTARG
		;;
	p)
		playlist=$OPTARG
		;;
	o)
		out=$OPTARG
		;;
	e)
		format=$OPTARG
		;;
	c)
		relaxingSchema=$OPTARG
		;;
	v)
		VERBOSE=1
		;;
	q)	
		QUIET=1
		;;
	?)
		usage
		exit 1
		;;
	esac
	
done

#CHECK
#mandatory options
if [ -z "$directory" -o -z "$playlist" ]
then
	usage
	exit 1
fi

#directory existence check
if [ ! -d "$directory" ]; then
	echo "Argument music-directory must be a directory!"
	exit 1
fi

#xspf validation check
if [ "$relaxingSchema" != "0" ]; then
	xmlstarlet validate -q -e -r "$relaxingSchema" "$playlist"
	if [ $? = 1 ]; then
		echo "Argument xspf-playlist must be a valid xspf file!"
		exit 1
	fi
fi

#check for unsupported extension
echo $format | egrep -q "mp3|flac|ogg|wma"
if [ "$?" != "0" ]; then
	echo "Unsupported file extension: $format"
	exit 1
fi

#PREPARE
rm -rf "/tmp/fav$date"
mkdir "/tmp/fav$date"
#list of favourites from xspf | cut last empty line | unescape xml characters
xmlstarlet sel -N ns="http://xspf.org/ns/0/" -t -m "//ns:track" -v "ns:creator" -o " - " -v "ns:title" -n "$playlist" | head -n -1 | xmlstarlet unesc > "/tmp/fav$date/favlist"
if [ $VERBOSE = 1 ]; then
	echo "favlist created..."
fi

#litst of files in selected format(s) in given directory
find "$directory" -regextype posix-egrep -iregex ".*.$format" -type f > "/tmp/fav$date/filelist"
if [ $VERBOSE = 1 ]; then
	echo "filelist created..."
fi

#read favlist into hashmap (not found = 1, found = 2, 3+ = found many times, not in favlist = null)
unset favmap
declare -A favmap
while read favline; do
	key=$(echo $favline | sed 's/\[//g' | sed 's/\]//g')
	favmap+=(["$key"]="0")
done < "/tmp/fav$date/favlist"
if [ $VERBOSE = 1 ]; then
	echo "favlist hashmap created..."
fi

#SEARCH
favcount=$(wc -l < "/tmp/fav$date/favlist")
filecount=$(wc -l < "/tmp/fav$date/filelist")
if [ $VERBOSE = 1 ]; then
	echo "Found $favcount favourites."
	echo "Found $filecount music files in given directory."
	echo "This might take some time..."
fi
#new xspf document
echo -e '<?xml version="1.0" encoding="UTF-8"?>\n<playlist xmlns="http://xspf.org/ns/0/" version="1"></playlist>' > "/tmp/fav$date/out"
xmlstarlet ed -L -N "ns=http://xspf.org/ns/0/" -s "/ns:playlist" -t elem -n trackList -v "" "/tmp/fav$date/out"
#search for matches in hashmap
progress=0
while read fileline; do
	if [ $QUIET = 0 ]; then
		echo -n -e "\r$progress/$filecount"
	fi
	progress=$(($progress+1))
	extension=$(echo ${fileline##*.})
	if [ $extension = "mp3" ]; then
		creator=$(mutagen-inspect "$fileline" | grep "^TPE1=" | sed 's/TPE1=//')
		title=$(mutagen-inspect "$fileline" | grep "^TIT2=" | sed 's/TIT2=//')
	elif [ $extension = "flac" ]; then
		creator=$(mutagen-inspect "$fileline" | grep "^artist=" | sed 's/artist=//')
		title=$(mutagen-inspect "$fileline" | grep "^title=" | sed 's/title=//')
	elif [ $extension = "ogg" ]; then
		creator=$(mutagen-inspect "$fileline" | grep "^artist=" | sed 's/artist=//')
		title=$(mutagen-inspect "$fileline" | grep "^title=" | sed 's/title=//')
	elif [ $extension = "wma" ]; then
		creator=$(mutagen-inspect "$fileline" | grep "^Author=" | sed 's/Author=//')
		title=$(mutagen-inspect "$fileline" | grep "^Title=" | sed 's/Title=//')
	fi
	key=$(echo "$creator - $title" | sed 's/\[//g' | sed 's/\]//g')
	if [ -z "${favmap["$key"]}" ]; then
		continue
	else
			favmap["$key"]=$(( favmap["$key"]+1 ))
			#insert new track
			xmlstarlet ed -L -N ns="http://xspf.org/ns/0/" -s "/ns:playlist/ns:trackList" -t elem -n track -v "" "/tmp/fav$date/out"
			xmlstarlet ed -L -N ns="http://xspf.org/ns/0/" -s "/ns:playlist/ns:trackList/ns:track[last()]" -t elem -n location -v "$(echo "$fileline" | xmlstarlet esc)" "/tmp/fav$date/out"
			xmlstarlet ed -L -N ns="http://xspf.org/ns/0/" -s "/ns:playlist/ns:trackList/ns:track[last()]" -t elem -n title -v "$(echo "$title" | xmlstarlet esc)" "/tmp/fav$date/out"
	fi	
done < "/tmp/fav$date/filelist"
if [ $QUIET = 0 ]; then
	echo -n -e "\r"
fi

#EXIT
if [ "$out" = 0 ]; then
	cat "/tmp/fav$date/out"
else
	mv "/tmp/fav$date/out" "$out"
fi
if [ $VERBOSE = 1 ]; then
	foundcount=0
	for val in "${!favmap[@]}"; do
		if [ "${favmap["$val"]}" -ge 1 ]; then
			echo "Found (${favmap["$val"]}) $val" >> "/tmp/fav$date/found"
			foundcount=$(($foundcount+1))
		else
			echo "Couldn't find $val" >> "/tmp/fav$date/notfound"
		fi
	done
	cat "/tmp/fav$date/notfound" "/tmp/fav$date/found"
	echo "Found $foundcount of $favcount songs."
fi
rm -rf "/tmp/fav$date"
unset favmap
