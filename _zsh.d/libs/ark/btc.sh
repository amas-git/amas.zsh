#!/bin/zsh


function random() {
    local size=${1:=64}
    echo -n "ibase=16;${(U)$(cat /dev/urandom | head -c $size | hexdump -ve '1/1 "%.2x"')}" | bc | tr -d "\n\\"
}

function base58() {
    local dict='123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'
    local hex=$(byte2hex "${1:=$argv}")
    local dec=$(hex2dec $hex)
    local xs=''

    while [[ $dec != 0 ]]; do
        xs+=$dict[$(echo "$dec%58" | bc)+1]
        dec=$(echo "$dec/58" | bc)
    done 
    # TODO: add padding with dict[1]
    print -r ${(j::)${(@Oa)${(s::)xs}}}
}

function byte2hex() {
    local x=${argv:=$(<&0)}
    echo -n $x | hexdump -ve '1/1 "%.2x"'
}

function hex2dec() {
    local x=${argv:=$(<&0)}
    <<< "ibase=16;${(U)x}" | bc | tr -d "\n\\"
}

function dec2hex() {
    local x=${argv:=$(<&0)}
    <<< "obase=16;${x}" | bc
}

function string_to_bigint() {
    
}
