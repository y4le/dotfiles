#!/bin/bash

if [ -z "$*" ]
then
function gen_workspaces()
{
    i3-msg -t get_workspaces | tr ',' '\n' | grep "name" | sed 's/"name":"\(.*\)"/\1/g' | sort -n
}


echo empty; gen_workspaces
else
    WORKSPACE="$*"

    if [ x"empty" = x"${WORKSPACE}" ]
    then
        # Find the first unused workspace number (1-10)
        USED=$(i3-msg -t get_workspaces | tr ',' '\n' | grep '"num"' | sed 's/.*:\([0-9]*\)/\1/g')
        for i in $(seq 1 10); do
            if ! echo "${USED}" | grep -qx "${i}"; then
                i3-msg workspace "${i}" >/dev/null
                break
            fi
        done
    elif [ -n "${WORKSPACE}" ]
    then
        i3-msg workspace "${WORKSPACE}" >/dev/null
    fi
fi
