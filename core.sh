#!/bin/bash

# Bash Data Structure Methods

# Written by Mike McLean (mikem.rtp@gmail.com)

assign () {
    eval "$1=\$2"
}


# Methodology
#   data structures are stored in carefully named global variables
#   they are passed to functions by reference (i.e. by name).
#   a function returns data by reference also, storing the name
#   in the global variable 'REPLY'.
#
#   It is best to think of these global variable names as memory
#   addresses.
#
#   The global naming scheme is as follows:
#
#       __bdsm_data_<TYPE>_<INTEGER>_<INTEGER>...
#


# system variables
__bdsm_index=0
__bdsm_maxindex=2147483647


foo () {
    local x=$1
    let x=x+1
    if (( x < 32 )); then
        foo $x
        echo ": $REPLY"
    fi
    echo $x
    REPLY=$x
}


alloc () {
    local valtype=$1
    local value=$2

    #increment the index, which is a *list* of numbers.
    #we increment with overflow.
    local incr=1
    local newindex=''
    for i in ${__bdsm_index}; do
        if (( incr > 0 )); then
            if (( i < __bdsm_maxindex )); then
                (( i=i+incr ))
                incr=0
            else
                i=0
            fi
        fi
        newindex="$newindex $i"
    done
    if ((incr > 0)); then
        newindex="$newindex 0"
    fi

    __bdsm_index=$newindex
    REPLY=__bdsm_data_$valtype
    for i in ${__bdsm_index}; do
        REPLY="${REPLY}_$i"
    done
    eval "$REPLY=\$value"
}


str () {
    ### return a new string object
    alloc str "$1"
}

int () {
    ### return a new int object
    alloc int "$1"
}

whattype () {
    ### return the type of the given data
    local t
    case $1 in
        __bdsm_data_*)
            t=${1#__bdsm_data_}
            t=${t%%_*}
            alloc str "$t"
            return
            ;;
        *)
            return 1
            ;;
    esac
}


