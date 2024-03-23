#!/usr/bin/env sh

DEST=""

for a in /Volumes/*; do
    if [ -d "$a/stack.incoming" ]; then
        if [ ! -z "$DEST" ]; then
            echo "Found DEST on $a and $DEST" 1>&2
            exit 1
        fi
        DEST="$a/stack.incoming/"
    fi
done

echo "Copying files from $MEMCARD -> $DEST"
rsync -av --exclude="NC_FLLST.DAT" "$MEMCARD" "$DEST/" \
      1>> "$DEST/rsync.log" 2>> "$DEST/rsync.err" || \
    { echo "rsync exited with error.  see $DEST/rsync.err" 1>&2; exit 1 ;}

if [ -s "$DEST/rsync.err" ]; then
    echo "ERRORS in $DEST/rsync.err"
    exit 1
else
    echo "DONE log in $DEST/rsync.log"
fi



