#!/bin/zsh

function mix() {
    local -a lines
    local -A chrunks

    lines=("${(@f)$(<&0)}")
    
    @IF $#lines

    local -i i 
    local line
    for ((i=1; i<=$#lines; ++i)); do
        line=$lines[i]
        if [[ $line[1] == '@' ]]; then
            @IF "FIND TAG: $line"
        fi
    done
}
