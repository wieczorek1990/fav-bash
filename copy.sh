#!/bin/bash
# Prints out location value from xspf generated with fav.sh.
# e.g. usage ./copy.sh /media/data/Music/Ulubione.xspf /media/luke/uSD/Music
if [ $# -ne 2 ]; then
	echo -e 'Wrong number of arguments\n\t./copy.sh xspf-file destination'
	exit 1
fi
SRC="$1"
DEST="$2"

FILES=`xmlstarlet sel -N ns=http://xspf.org/ns/0/ -t -m //ns:location -v . -n "$SRC" | xmlstarlet unesc`
COUNT=`echo "$FILES" | wc -l | cut -d' ' -f1`
CUR=1
while IFS= read
do
	echo -n -e "\r$CUR/$COUNT"
	cp -u "$REPLY" "$DEST"
	((CUR++))
done <<< "$FILES"
