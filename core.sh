#!/bin/bash

# Bash Data Structure Methods

# Written by Mike McLean (mikem.rtp@gmail.com)


#
# Some generic functions to facilitate indirect references
#

assign () {
    eval "$1=\$2"
}

copyvar () {
    eval "$2=\${$1}"
}

assign_array () {
    #by using the volatile global REPLY, we avoid name collisions
    REPLY=$1
    shift
    eval "$REPLY"='("$@")'
}

copyvar_array () {
    eval "$2=(\"\${$1[@]}\")"
}

assigned () {
    #eval "[ -n \"\${$1+x}\" ]"
    [ -n "${!1+x}" ]
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
    local var="${1}_class"
    REPLY=${!var}
}

getattr () {
    local var="${1}_attr_$2"
    REPLY=${!var}
}

setattr () {
    eval "${1}_attr_$2=\$3"
    unset -v REPLY
}

callobject () {
    local self=$1
    local methodname=$2
    shift
    shift
    # read class
    local _temp_varname="${self}_class"
    local _temp_funcname=''
    classname=${!_temp_varname}
    # search inheritance chain for method
    while true; do
        _temp_varname=__bdsm_class_${classname}_method_${methodname}
        if assigned $_temp_varname; then
            _temp_funcname=${!_temp_varname}
            if [ -z "$_temp_funcname" ]; then
                echo 1>&2 "Error: Method disabled: $methodname (object $self)"
                unset -v REPLY
                return 1
            fi
            eval "$_temp_funcname \"\$@\""
            return
        fi
        #else try parent
        _temp_varname=__bdsm_class_${class}_parent
        if ! assigned $_temp_varname; then
            echo 1>&2 "Error: Method not implemented: $methodname (object $self)"
            unset -v REPLY
            return 1
        fi
        classname=${!_temp_varname}
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
    if callobject "$self" init "$@"; then
        #if call succeeds return object
        REPLY="callobject $self"
        #the idea here is that the return value can be used
        #like a command with the methodname as the first arg
        #see examples later
    fi
    #(otherwise we let callobject's return propagate)
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

## class list
# (bash arrays with a few minor enhancements)
# hmm, need to do more performance testing:
#   bash arrays vs dynamic names with embedded indices
setparent list object
list_init () {
    #value is a bash array
    eval "${self}_attr_value"='("$@")'
}
list_value () {
    eval REPLY="(\"\${${self}_attr_value[@]}\")"
}
list_repr () {
    eval "declare -p ${self}_attr_value"
}
setmethod list init 'list_init'
setmethod list value 'list_value'
setmethod list repr 'list_repr'


#demo
new string "This is a test"
x=$REPLY
$x print
#echo $REPLY


new list "one (or 1)" "two (or 2)" "three (or 3)"
y=$REPLY
$y repr


