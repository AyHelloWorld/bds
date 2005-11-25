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

alloc () {
    ### return an unused global name for bdsm data
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
    #now that we have the new index, generate the global name
    REPLY=__bdsm_data
    for i in ${__bdsm_index}; do
        REPLY="${REPLY}_$i"
    done
}


object () {
    local loc=$1
    local cmd=$2
    shift
    shift
    case $cmd in
        class)
            # XXX - use ${!var} expansion?
            eval "REPLY=\$${loc}_class"
            return
            ;;
        new)
            alloc
            eval "${REPLY}_class=object"
            return
            ;;
        getattr)
            #attr name in $1
            eval "REPLY=\$${loc}_attr_$1"
            return
            ;;
        setattr)
            #value in $1
            eval "${loc}_attr_$1=\$1"
            unset -v REPLY
            return
            ;;
    esac
}


getclass () {
    ### return the class of the given object
    object "$1" class
}

getattr () {
    ### return the value of the attribute for an object
    object "$1" class
    #RETURN holds the name of the class function
    "$RETURN" "$1" getattr "$2"
}

setattr () {
    ### set the attribute value for an object
    object "$1" class
    #RETURN holds the name of the class function
    "$RETURN" "$1" setattr "$2"
}

native () {
    ### native class (for bash native scalars)
    local loc=$1
    local cmd=$2
    local parent=object
    shift
    shift
    case $cmd in
        new)
            alloc
            eval "${REPLY}_class=native"
            eval "${REPLY}=\$1"
            return
            ;;
        set)
            eval "${loc}=\$1"
            unset -v REPLY
            return
            ;;
        value)
            eval "REPLY=\$${loc}"
            return
            ;;
        *)
            #defer to parent
            $parent $loc $cmd "$@"
            return
            ;;
    esac
}

string () {
    ### string class
    local loc=$1
    local cmd=$2
    local parent=native
    shift
    shift
    case $cmd in
        new)
            alloc
            eval "${REPLY}_class=native"
            #initialize value from $1
            eval "${REPLY}=\$1"
            return
            ;;
        *)
            #defer to parent
            $parent $loc $cmd "$@"
            return
            ;;
    esac
}




