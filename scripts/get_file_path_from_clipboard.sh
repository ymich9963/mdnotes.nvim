#!/bin/bash

if [ $XDG_SESSION_TYPE = x11 ]; then
    xclip -selection clipboard -t text/uri-list -o | sed 's|file://||'
else 
    if [ $XDG_SESSION_TYPE = wayland ]; then
        wl-paste --type text/uri-list | sed 's|file://||'
    fi
fi

