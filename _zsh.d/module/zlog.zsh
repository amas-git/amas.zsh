#!/bin/zsh
alias logf='logd "$(basename $0)()"'
ZLOG_FMT='date +%H:%M:%S'

alias @E="___zlog E '$fg[red]'"
alias @I="___zlog I '$fg[green]'"
alias @W="___zlog W '$fg[yellow]'"
alias @D="___zlog D '$fg[white]'"

alias @EF='@E $(basename $0)'
alias @IF='@I $(basename $0)'
alias @WF='@W $(basename $0)'
alias @DF='@D $(basename $0)'
alias @A='@I $(basename $0)  argc=$#argv,  argv="$argv"'

function ___zlog() {
    local head="$1"; shift
    local color="$1"; shift
    local tag="$1"; shift
    local time=$(eval $ZLOG_FMT)
    local x
    for x in "${(@f)*}"; do
        print -u2 "${color}${head}:[$tag]($time): $x$terminfo[sgr0]"
    done 
}

function logd() {
    #TODO: 如果$1中包含路径分隔符，将会导致sed失败
    local tag=$(echo "$1" | sed -e "s/\//\\\\\//g")
    echo "$2" | sed -e "s/^/DEBUG[$tag]: /g" 1>&2 ; 
}

function _() {
    help () {
        echo "$ var=value"
        echo "$ _ var"
        echo "var=value"
    }
    print $(eval "print $1=\$$1")
}

echoerr() { 
    echo "$@" 1>&2; 
}

alias @MSG="___zmsg '$fg[yellow]'"
function ___zmsg() {
    local color=$1; shift
    print -u2 "${color}$*$terminfo[sgr0]"
}
