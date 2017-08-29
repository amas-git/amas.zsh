#!/bin/zsh

# TODO:
# 模板实例化写入文件时应当检测该文件是否存在，如果存在，则先备份，后覆盖
T_HOME="/home/amas/.t"
hash -d thome="$T_HOME"
alias tf=tf3
alias tn=t.core.evaln

function @TITLE() {
    @MSG "============================================="
    @MSG "      $___TNAME"
    @MSG "============================================="
}

function @() {
    @MSG "$*"
}

# tf2将被作为t.core.evalf的代替品，消除了对sed之依赖
# TODO: 变量名可能会与模板中的变量名冲突
function tf2() {

    local ___TPATH=$1;shift
    local ___TNAME="$(basename $___TPATH)"
    local ___TWD="$(dirname $___TPATH)"
    # [[ -f "$fname" ]] || ( echo "temlplate file not found : $1" && return -1 )
    unfunction output 2> /dev/null
    # TNAME=$fname
   
    local ___H=
    local ___B=
    local ___T=
    local ___R=
    local ___ESC="<<<<-;xe>>>>"
    
    # FIXME(amas): 这种方法空行会被吃掉
    ___T=("${(@f)$(<$___TPATH)}")
    integer nx=$___T[(i)#--]

    if (( nx == ${#___T} + 1 )); then
        #___B=${$(print -l $___T[1,-1])//\"/"$___ESC"}
        ___B=$(print -r -l $___T[1,-1])
        ___B=${___B//\"/$___ESC}
    else 
        ___H=$(print -r -l $___T[1,nx-1])
        ___B=$(print -r -l $___T[nx+1,-1])
        ___B=${___B//\"/$___ESC}
        # 下面这种方法会吃掉\n,不知道为什么???
        #___B=${$(print -l $___T[nx+1,-1])//\"/"$___ESC"}
    fi

    ## eval header
    if [[ -n $___H ]]; then
        eval "$___H" 
        [[ $? != 0 ]] && @EF "EVAL HEADER ERROR($?): $___H" && return -2
    fi

    ## eval body
    if [[ -n $___B ]]; then
        ___R=$(eval "print \"$___B\"")
        ___R=${___R//$___ESC/\"}
    fi

    # trigger callback funcs 是不是也得支持alias啊？
    if [[ -n $(builtin functions output) ]]; then
        output "$___R"
        unfunction output 2> /dev/null
    else   
        echo "$___R"
    fi
}

function tf3() {
    (
    local ___TPATH=$1;shift
    local ___TNAME="$(basename $___TPATH)"
    local ___TWD="$(dirname $___TPATH)"
    # [[ -f "$___TPATH" ]] || ( @EF "template file not found: '$___TPATH'" )
    unfunction output 2> /dev/null
    # TNAME=$fname
   
    local ___H=
    local ___B=
    local ___T=
    local ___R=
    local ___ESC="xxxxxxxxxxxxx"
    ___T=("${(@f)$(<$___TPATH)}")
    integer nx=$___T[(i)#--]
    if (( nx == ${#___T} + 1 )); then
        ___B=${(j:\n:)___T[1,-1]}
        ___B=${___B//\"/$___ESC}
    else 
        # build header & remove blank lines of header
        # XXX: ___H=${(j:\n:)___T[1,nx-1]} this will case eval error why?
        ___H=$(print -r -l $___T[1,nx-1])
        ___B=${(j:\n:)___T[nx+1,-1]}
        ___B=${___B//\"/$___ESC}
    fi

    ## eval header
    if [[ -n $___H ]]; then
        eval "$___H"
        [[ $? != 0 ]] && @EF "EVAL HEADER ERROR($?): $___H" && return -2
    fi

    ## parameter expansion & command expansion in body
    if [[ -n $___B ]]; then
        ___R="${(e)___B}"
        ___R="${___R//$___ESC/\"}"
    fi

    # trigger callback funcs 是不是也得支持alias啊？
    if [[ -n $(builtin functions output) ]]; then
        output "$___R"
        unfunction output 2> /dev/null
    else   
        echo "$___R"
    fi
    )
}

# ts之中所有需要输入的函数都将被忽略，ts只能用于非交互
function ts() {
    # [[ -f "$fname" ]] || ( echo "temlplate file not found : $1" && return -1 )
    unfunction output 2> /dev/null
    # TNAME=$fname
    # local clone=
    # [[ "$1" == clone ]] && shift && clone=true && CLONE=
    
    local H=
    local B=
    local T=
    local R=
    local ESC="\x00"
    setopt EXTENDED_GLOB
    for x in $argv ; do 
       if [[ $x = (#b)(*)=(*) ]]; then
          name=$match[1]
          value=$match[2]
          eval "local $name=$value"
       fi
    done
    unsetopt EXTENDED_GLOB
    T=("${(f)$(<&0)}")
    integer nx=$T[(i)#--]

    if (( nx == ${#T} + 1 )); then
        B=$(print -r -l $T[1,-1])
        B=${B//\"/$ESC}
    else 
        H=$(print -r -l $T[1,nx-1])
        B=$(print -r -l $T[nx+1,-1])
        B=${B//\"/$ESC}
    fi
    
    [[ -n $clone ]] && CLONE=$B
    ## eval header
    if [[ -n $H ]]; then
        eval "$H" || logf "EVAL HEADER ERROR($?): $H"
    fi

    ## eval body
    if [[ -n $B ]]; then
        R=$(eval "print \"$B\"")
        R=${R//$ESC/\"}
    fi

    # trigger callback funcs 是不是也得支持alias啊？
    if [[ -n $(builtin functions output) ]]; then
        output "$R"
        unfunction output 2> /dev/null
    else   
        echo "$R"
    fi
    # echo $CLONE
}

function xx() {
    s=$(<&0)
    echo $s
    eval "$(<&0)"
}


function t.core.evaln() {
    local name="$1"; shift
    tf "$T_HOME/$name" $*
}

function require() {
    local name="$1" && shift
    typeset -A opts
    opts=()
    zparseopts -A opts -K -D -- d:=opts c:=opts 

    local defaultValue=$opts[-d]
    local desc=$opts[-c]
    local value
    noglob read "$name"?"$desc(o默认值为:'$defaultValue')="
    [[ -z ${(P)name} ]] && eval "$name=$defaultValue"
    return 0
}

function basewriter() {
    local out="$1"; shift
    zparseopts -A opts -K -D -- echo:=opts
    [[ -f $out ]] # && @DF "TODO: 目标文件'$out'已经存在，即将被更新，将来需要备份源文件，警告警告"

    local content="$(<&0)"
    [[ -z $out ]] && @IF "没有指定输入文件, 回显到屏幕" && @MSG "$content" && return
    [[ -n $content ]] && echo "$content" > "$out" && @IF "${#content} characters write successful to '$out'" && return
    @IF "no content, write nothing"
}

function android.permission() {
    for x in $argv; do
        print -n " android.permission.$x"
    done
}

function select-q() {
    opts=()
    zparseopts -A opts -K -D -- d:=opts c:=opts 
    local defaultValue=$opts[-d]
    PROMPT3="$opts[-c][默认值='$defaultValue'](退出:q): "
    select selected in $argv[0,-1]; do
        if [[ "$REPLY" = q ]];  then
            print $defaultValue
            break
        elif [[ -n "$REPLY" ]]; then
            print $selected
            break
        fi
    done
}

# 过期了
function t.core.evalf() {
    local fname=$1
    [[ -f "$fname" ]] || ( echo "temlplate file not found : $1" && return -1 )
    unfunction output 2> /dev/null
    TNAME=$fname
    local header
    # search header bounding index
    integer nx=$(grep -m1 -n '^#--$' "$fname" | cut -d: -f1)
    # eval header
    if (( $nx>0 )) then
       header=$(awk " NR<$nx { print }" "$fname")
       eval "$header"
       if (( $? != 0 ))then
           logf "oooooooooooooooooops: eval header failed"
       fi
    fi

    # eval body
    local esc="\x00"
    local body="print \"$(awk " NR>$nx { gsub(\"\\\"\",\"$esc\"); print }" "$fname")\""
    local result=
    if [[ -n $body ]]; then
        #eval $body | sed -e "s/$esc/\"/g"
        result=$(eval $body | sed -e "s/$esc/\"/g")
    fi

    # trigger callback funcs 是不是也得支持alias啊？
    if [[ -n $(builtin functions output) ]]; then
        output "$result"
        unfunction output 2> /dev/null
    else   
        echo "$result"
    fi
    # output这函数名是不太普通了，容易影响别人？
    
}



function quote() {
    help() {
        
    }
    
}

function @zip() {
    (
    )
}





# The roots of zcg
# $1
# $2
# -- a b 
function @source() {
    local expr="$(<&0)"
    echo ${(e)expr}
}








function map() {
    (   
        _t=$1 && shift
        _array=()
        function _() {
          _array+=${(e)_t}
        }

        for x in $argv; do
            _ $x
        done
        print ${_array}
    )
}


#ZHOME=~sandbox/ztemplate.git/template

