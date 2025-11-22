#!/usr/bin/env sh
LRC=/Volumes/pfast/Stacks/Stacks.lrcat

if [ ! -f $LRC ]; then
    echo "Hey I could not find the LR catalog! I expected it at $LRC"
fi

open $LRC
