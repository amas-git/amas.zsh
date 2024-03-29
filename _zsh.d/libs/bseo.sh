#!/bin/zsh


BSEO_BASE='bitrue.com'
BSEO_MAX=3

function main() {
    local install=$(whence googler)
    [[ -z $install ]] && {
       print " googler command NOT FOUND, see: https://github.com/jarun/googler" 
       return -1
    }

    bseo.urls $argv

}


function sleep.random() {
    local min=${1:=10}
    local max=${2:=20}
    sleep $(( (min+RANDOM)%max ))
}

function bseo.urls() {
    local xs=(${argv:=$(<&0)})
    
    for x in $xs; do
        search="site:$BSEO_BASE/$x"
        for n in {0..1}; do
            s=$[n*100+1]
            n=$[n+100+100]
            sleep 1 
            googler -s $s -n $n --json "search" | jq '.[].url'
            sleep.random
        done
    done
}



main "$@"
