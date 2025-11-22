#!/usr/bin/env bash

export INCDIR=""

for a in /Volumes/*; do
    ## echo "checking $a"
    if [ -d "$a/stack.incoming" ]; then
        if [ ! -z "$INCDIR" ]; then
            echo "Found INCDIR on $a and $INCDIR" 1>&2
            exit 1
        fi
        INCDIR="$a/stack.incoming"
        VOL=$a
    fi
done

if [ -z "$INCDIR" ]; then
    echo "no stack.incoming found"
    exit 1
fi

export DESTDIR="/Volumes/pfast/LRStacks/0-Pending"

if [ ! -s "$DESTDIR" ]; then
    echo "Destination not found $DESTDIR"
    exit 1
fi

R --slave < runs.R


