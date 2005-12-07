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
    local i
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
    local _temp_funcname=''
    # read class
    local _temp_varname="${self}_class"
    local classname=${!_temp_varname}
    # search inheritance chain for method
    while true; do
        _temp_varname=__bdsm_class_${classname}_method___${methodname}
        #XXX - potential name collisions
        #   __bdsm_class_foo_method___method___bar could refer to:
        #       method bar for class foo_method__
        #       method method___bar for class foo
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
        _temp_varname=__bdsm_class_${classname}_parent
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
    eval "__bdsm_class_${1}_method___${2}=\$3"
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
    if callobject "$self" __init__ "$@"; then
        #if call succeeds, declare access function and return object
        eval "function $self () { callobject $self \"\$@\"; }"
        REPLY="$self"
    fi
    #(otherwise we let callobject's return propagate)
}

del () {
    local self=$1
    # call objects delete method
    $self __del__ || return
    # remove access function
    unset -f $self
}

## class object
object_del () {
    local v vars
    eval "vars=\${!${self}*}"
    for v in $vars; do
        unset -v $v
    done
    unset -v REPLY
}
setmethod object getattr 'getattr $self'
setmethod object setattr 'setattr $self'
setmethod object __init__ ":"
setmethod object __del__ "object_del"

## class string
setparent string object
setmethod string __init__ 'setattr $self value'
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
    eval "${self}_attr_origin=0"
    eval "${self}_attr_end=$#"
}
list_length () {
    local var_a="${self}_attr_origin"
    local var_b="${self}_attr_end"
    (( REPLY=${!var_b}-${!var_a} ))
}
list_append () {
    local var_end="${self}_attr_end"
    local end=${!var_end}
    eval "${self}_attr_value[$end]=\$1"
    ((end=end+1))
    eval "$var_end=\$end"
    unset -v REPLY
}
list_pop () {
    local var_origin="${self}_attr_origin"
    local origin=${!var_origin}
    local var_end="${self}_attr_end"
    local end=${!var_end}
    if ! ((origin < end)); then
        unset -v REPLY
        return 1
    fi
    ((end=end-1))
    eval "REPLY=\${${self}_attr_value[$end]}"
    #XXX, do I need the eval on the unset?
    eval "unset -v ${self}_attr_value[$end]"
    eval "$var_end=\$end"
}
list_shift () {
    local var_origin="${self}_attr_origin"
    local origin=${!var_origin}
    local var_end="${self}_attr_end"
    local end=${!var_end}
    if ! ((origin < end)); then
        unset -v REPLY
        return 1
    fi
    eval "REPLY=\${${self}_attr_value[$origin]}"
    #XXX, do I need the eval on the unset?
    eval "unset -v ${self}_attr_value[$origin]"
    ((origin=origin+1))
    eval "$var_origin=\$origin"
}
list_get_single () {
    local var_origin="${self}_attr_origin"
    local origin=${!var_origin}
    local var_end="${self}_attr_end"
    local end=${!var_end}
    local ofs=$1
    if (( ofs < 0 )); then
        (( ofs = ofs + end - origin ))
    else
        (( ofs=ofs+origin))
    fi
    if (( ofs < end )) && (( ofs >= origin )); then
        # valid offset
        eval "REPLY=\${${self}_attr_value[$ofs]}"
    else
        echo 1>&2 "Error: list index out of range"
        unset -v REPLY
        return 1
    fi
}
list_get_slice () {
    #accepts slices i:j:k as first arg
    local ifs=$IFS
    IFS=:
    set -- $1
    local i=$1
    local j=$2
    local k=$3
    IFS=$ifs
    local var_origin="${self}_attr_origin"
    local origin=${!var_origin}
    local var_end="${self}_attr_end"
    local end=${!var_end}
    [ -z "$k" ] && k=1
    if (( k > 0 )); then
        [ -z "$i" ] && i=0
        [ -z "$j" ] && (( j=end-origin ))
    elif (( k < 0 )); then
        [ -z "$i" ] && (( i=end-origin-1 ))
        [ -z "$j" ] && j=0
        #ugh this seems tricky, note the asymmetry
        #also note the while i>=j for this case below
    else
        echo 1>&2 "Error: slice step cannot be zero"
        unset -v REPLY
        return 1
    fi
    #offset i and j
    if (( i >= 0 )); then
        (( i=i+origin ))
        (( i > end )) && i=end
    else
        (( i=i+end ))
        (( i < origin )) && i=origin
    fi
    if (( j >= 0 )); then
        (( j=j+origin ))
        (( j > end )) && j=end
    else
        (( j=j+end ))
        (( j < origin )) && j=origin
    fi
    local n=0
    new list            #new list to return
    local ret=${REPLY#* }     #get base varname
    if (( k > 0 )); then
        while (( i < j )); do
            #we directly set the array values for performance
            eval "${ret}_attr_value[$n]=\${${self}_attr_value[$i]}"
            (( i=i+k ))
            (( n=n+1 ))
        done
    else
        #reverse step
        while (( i >= j )); do
            #we directly set the array values for performance
            eval "${ret}_attr_value[$n]=\${${self}_attr_value[$i]}"
            (( i=i+k ))
            (( n=n+1 ))
        done
    fi
    eval "${ret}_attr_end=$n"
    #REPLY was set by 'new list'
}
list_get () {
    case $1 in
        *:*)
            list_get_slice "$@"
            ;;
        *)
            list_get_single "$@"
            ;;
    esac
}
list_value () {
    eval REPLY="(\"\${${self}_attr_value[@]}\")"
}
list_print () {
    #XXX - this could be better
    eval "printf '%s\n' \"\${${self}_attr_value[*]}\""
}
list_repr () {
    eval "declare -p ${self}_attr_value"
}
setmethod list __init__ 'list_init'
setmethod list length 'list_length'
setmethod list append 'list_append'
setmethod list pop 'list_pop'
setmethod list shift 'list_shift'
setmethod list get 'list_get'
setmethod list print 'list_print'
setmethod list value 'list_value'
setmethod list repr 'list_repr'


## class dict
setparent dict object
# storage
#   for each key, the corresponding value is stored:
#     ${self}_keys_${hash}[$n]
#     ${self}_values_${hash}[$n]
dict_init () {
    #XXX - need an init function
    :
}
dict_get () {
    # $1 = key
    local hash=${1%%[!a-zA-Z0-9_]*}
    #search for key in bin
    local keyarray="${self}_keys_${hash}"
    local len key
    eval "len=\${#$keyarray[@]}"
    for ((i=0; i<len; i=i+1)); do
        eval "key=\${$keyarray[$i]}"
        if [ ".$key" = ".$1" ]; then
            eval "REPLY=\${${self}_values_${hash}[$i]}"
            return
        fi
    done
    #don't got it
    unset -v REPLY
    return 1
}
dict_set () {
    # $1 = key
    # $2 = value
    local hash=${1%%[!a-zA-Z0-9_]*}
    #search for key in bin
    local keyarray="${self}_keys_${hash}"
    local len key i
    #look to see if we already have this key
    eval "len=\${#$keyarray[@]}"
    for ((i=0; i<len; i=i+1)); do
        eval "key=\${$keyarray[$i]}"
        if [ ".$key" = ".$1" ]; then
            eval "${self}_values_${hash}[$i]=\$2"
            unset -v REPLY
            return
        fi
    done
    #new key
    eval "${self}_keys_${hash}[$len]=\$1"
    eval "${self}_values_${hash}[$len]=\$2"
    unset -v REPLY
}
dict_del () {
    # $1 = key
    # $2 = value
    unset -v REPLY      # no return value
    local hash=${1%%[!a-zA-Z0-9_]*}
    #search for key in bin
    local keyarray="${self}_keys_${hash}"
    local len key i
    #look to see if we already have this key
    eval "len=\${#$keyarray[@]}"
    for ((i=0; i<len; i=i+1)); do
        eval "key=\${$keyarray[$i]}"
        if [ ".$key" = ".$1" ]; then
            # XXX - over time, this could lead to very long
            # sparse arrays, if a key were set and unset
            # repeatedly.
            # We should track this and clean up if it gets too
            # sparse.
            unset -v "${self}_keys_${hash}[$i]"
            unset -v "${self}_values_${hash}[$i]"
            return
        fi
    done
    #don't got it
    return 1
}
dict_print () {
    unset -v REPLY      # no return value
    local len bins hash key value i keyarray
    eval "bins=\${!${self}_keys_*}"
    #XXX - need to verify that the above expansion is sufficiently
    #    broadly available.  (Can be worked around by keeping an array
    #    of hashes used).
    for keyarray in $bins; do
        hash=${keyarray#${self}_keys_}
        eval "len=\${#$keyarray[@]}"
        for ((i=0; i<len; i=i+1)); do
            eval "key=\${$keyarray[$i]}"
            eval "value=\${${self}_values_${hash}[$i]}"
            printf "%q => %q\n" "$key" "$value"
        done
    done
}
setmethod dict get 'dict_get'
setmethod dict set 'dict_set'
setmethod dict del 'dict_del'
setmethod dict print 'dict_print'



#demo
new string "This is a test"
x=$REPLY
$x print
#echo $REPLY


new list $(seq 0 19)
y=$REPLY
$y print

$y get '::-3'
z=$REPLY
$z print

$y get '5:-5'
z=$REPLY
$z print



new dict
d=$REPLY
$d set foo bar
for x in one two 3 "3 3" "3.5" "f o u r" "555 55"; do
    $d set "$x" "some generic value"
done
$d print
