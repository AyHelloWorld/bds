#!/bin/bash

# Bash Data Structure Methods

# Written by Mike McLean (mikem.rtp@gmail.com)

assign () {
    eval "$1=\$2"
}

assigned () {
    eval "[ -n \"\${$1+x}\" ]"
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

getclass () {
    eval "REPLY=\$${1}_class"
}

getattr () {
    eval "REPLY=\$${1}_attr_$2"
}

setattr () {
    eval "${1}_attr_$2=\$3"
    unset -v REPLY
}

callmethod () {
    local self=$1
    local method=$2
    shift
    shift
    # read class
    local class
    eval "class=\$${self}_class"
    # search inheritance chain for method
    local var func
    while true; do
        var=__bdsm_class_${class}_method_${method}
        if assigned $var; then
            eval "func=\$$var"
            if [ -z "$func" ]; then
                echo 1>&2 "Error: Method disabled: $method (object $self)"
                unset -v REPLY
                return 1
            fi
            eval "$func \"\$@\""
            return
        fi
        #else try parent
        var=__bdsm_class_${class}_parent
        if ! assigned $var; then
            echo 1>&2 "Error: Method not implemented: $method (object $self)"
            unset -v REPLY
            return 1
        fi
        eval "class=\$$var"
        continue
    done
}

setmethod () {
    #class=$1
    #method=$2
    #expression=$3
    eval "__bdsm_class_${1}_method_${2}=\$3"
    unset -v REPLY
}

setparent () {
    #class=$1
    #parent=$2
    eval "__bdsm_class_${1}_parent=\$2"
    unset -v REPLY
}

new () {
    local class=$1
    shift
    alloc
    local self=$REPLY
    eval "${self}_class=\$class"
    if callmethod "$self" init "$@"; then
        #if call succeeds return object
        REPLY=$self
    fi
    #(otherwise we return whatever callmethod returned)
}


## class object
setmethod object getattr 'getattr $self'
setmethod object setattr 'setattr $self'
setmethod object init ":"

## class string
setparent string object
setmethod string init 'setattr $self value'
setmethod string value 'getattr $self value'
string_print () {
    getattr $self value
    printf '%s\n' "$REPLY"
}
setmethod string print 'string_print'

#demo
new string "This is a test"
x=$REPLY
callmethod "$x" print
#echo $REPLY
