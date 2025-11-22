#!/usr/bin/env bash

INC=""

for a in /Volumes/*; do
    ## echo "checking $a"
    if [ -d "$a/stack.incoming" ]; then
        if [ ! -z "$INC" ]; then
            echo "Found INC on $a and $INC" 1>&2
            exit 1
        fi
        INC="$a/stack.incoming"
        VOL=$a
    fi
done

if [ -z "$INC" ]; then
    echo "no stack.incoming found"
    exit 1
fi

for a in ${INC}/202*-*; do
    if [ -d $a ]; then
        if [ -f $a/meta.csv ]; then
            echo "$a meta.csv exists"
        else
            echo "$a generating meta.csv"
            (cd $a; exiftool -r -csv -SerialNumber -SubSecCreateDate DCIM > meta.csv)
        fi
    fi
done


