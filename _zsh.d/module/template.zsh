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

# @vendor
function @foldl() {
    (
        help() {
            print "\
$ @foldl '$(($1 - $2))' 5 -- 1 2 3 4
"
        }
        (( $#argv < 3 )) && help && return -1
        local expr="$1"; shift
        local vars="$1"; shift
        local -a opts

        zparseopts -D  -- h:=opts
        func() {
            @A
            vars=${(e)expr}
        }
        integer level=0
        for x in ${argv}; do
            @EF "$level: $vars "
            func "$vars" "$x"
            (( ++level ))
        done
        echo $vars
    )
}

# @vender
function @foldr() {
    (
        help() {
            print "\
$ @foldr '<$1>$2</$1>' 'He's good body' -- beijing china earth 

PARAMETERS:
    $1     : left parameter
    $2     : right parameter (this always hold expr)
    $level : root 0, eatch fold calc will inrc this value
arithmetic:
$ @foldr '$(($1 - $2))' 5 -- 1 2 3 4 5 
"\
        }
        local expr="$1"; shift
        local vars="$1"; shift
        local -a opts

        zparseopts -D  -- h:=opts

        func() {
        # @A
            vars=${(e)expr}
        }
        integer level=$#argv
        for x in ${(O)argv}; do
            func "$x" "$vars"
            (( --level ))
        done
        echo $vars
    )
}


function @emap() {
    ( # remove subshell may case outout memory, why?        
        help() {
print '''

'''
        }
        ___emap=()
        local -A omap
        local -i ___i ___row col_size
        local -a ___columns ___argv
        local ___expr="$(<&0)"

        zparseopts -A omap -D -K -- c:=omap
        
        # clone $argv
        ___argv=("${(@)argv}")

        if [[ -n $omap[-c] && $omap[-c] != <-> ]]; then
            ___columns=($=omap[-c])
            col_size=$#___columns
        else
            col_size=${omap[-c]:=1}
        fi
        
        # check tuple number
        (( col_size > 0 && $#___argv%$col_size != 0 )) && print -u2 "$#___argv elements can't group by $col_size" && return -1

        ___row=$(($#___argv/col_size))
        
        # TODO: 可以使用匿名函数
        emap.expand() {
            local -i ___i=1
            local ___name
            for ___name in $___columns; do
                local "$___name"=$argv[___i]
                (( ++___i ))
            done
            ___emap+=${(e)___expr}
        }


        for ((___i=0; ___i<___row; ___i++ )); do
            emap.expand "${(@)___argv[___i*col_size+1,(___i+1)*col_size]}"
        done

        print -l -- $___emap
    )
}

# xargs 可以向指定函数反复提交多个参数, 
# @emap '$1 "This is not mine" ' -- {1..999} | @xargs '(){ echo $2 $1}' 
# 将所有目录打包
# print -l * | @pipeline '(){ tar czvf $1.tgz $1}'
# 支持\0分割？？？
# FIXME:
# echo "()" | @xargs  -> will case eval error
function @xargs() {
    (
        help() {
            [[ -n $argv ]] && print $argv
            print -- "\
$ print -l {1..10} | @xargs echo
$ print -l {1..10} | @xargs '(){ echo \"<\$1>\" }'
OPTIONS
    -s <seperator> : How to splite input
    -0             : splite with '\0', same with -s $'\0'
"
        }

        local -a _argv _o_splite _o_flags

        _o_splite=(-s $'\n')
        zparseopts -D -K -- s:=_o_splite 0=_o_flags
        local func="$argv" 
        local _IFS_RESTORE expr
        [[ -z $func ]] && help "no functions or command" && return -1
        [[ -n $_o_flags[(r)-0] ]] && _o_splite=(-s $'\0')
        # splite :P
        # NOTICE: The $IFS need backup&restore after splite
        # for avoding take side effect on next eval operation
        _IFS_RESTORE=$IFS && IFS="$_o_splite[2]"
        _argv=("${=$(<&0)}")
        IFS=$_IFS_RESTORE

        for x in $_argv; do
            expr+="$func $x ;"
        done
        eval "$expr"
    )
}

function @foreach() {
    (
        help() {
            print '\
$ @foreach <expr> element1 element2 ... elementN

EXAMPLE:
$ @foreach "'"echo $1"'" a b c
a 
b
c

NOTICE:
This function executed on subshell
'
        }
        [[ -z $argv ]] && help && return -1
        eval 'function _() { '"$1"' }'
        for x in $argv[2,-1]; do
            _ "$x"
        done
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
# $ @acc -c 'NAME AGE' xiaoming 18 zhoujb '19' wangming '29' <<<'
# == NAME
# <$NAME>
# == AGE
# <$AGE>
#'
#
# TODO:
# 1. support num parameters
# 2. support gsep
function @grow() {
    (
        help() {
            print -u2 '\
SYNOPSIS
     @grow [-s] [-c namelist | -c number ] -- element1 element2 ... elementN 
DESCRIPTION
    Expand piped expr, each placeholder(or variable) will be clonned after substitution with specify element seperator which could be specified by option "-s". in shuch way, each placeholder grow up.
OPTIONS
    -s string   : element seperator (default is "\n")
    -c namelist : "name1 name2 name3" -- element1 elemnt2 ... elementN (where N%3=0)
    -c number   : group elements by number
EXAMPLES 
'
        }
        local -a ___expr ___header ___flags ___argv ___esep
        local -A ___omap
        
        zparseopts -A ___omap -D -K -- c:=___omap s:=___omap
        [[ -z $argv ]] && help && return

        ___expr="$(<&0)"
        # clone $argv
        ___argv=("${(@)argv}")
        
        # global element seperator
        ___esep=${___omap[-s]:="\n"}
        
        # group input
        if [[ -n $___omap[-c] && $___omap[-c] != <-> ]]; then
            ___columns=($=___omap[-c])
            col_size=$#___columns
        else
            col_size=${___omap[-c]:=1}
        fi
        
        
        # check tuple number
        (( col_size > 0 && $#___argv%$col_size != 0 )) && print -u2 "$#___argv elements can't group by $col_size" && return -1
        ___row=$(($#___argv/col_size))
                
        # TODO: 可以使用匿名函数
        # TODO: 可以令placeholder为数组，节点生长变为向数组中直接追加元素，最后进行一次e展开即可
        acc.expand() {
            local -i ___i=1
            local ___name
            
            # bind column names
            for ___name in $___columns; do
                if [[ -n $___LAST ]]; then
                    # last substiution
                    local "$___name"="$argv[___i]"
                else
                    # grow
                    local "$___name"="$argv[___i]${___esep}\$${___name}"
                fi
                (( ++___i ))
            done

            # nobind, clone number parameter
            if [[ -z $___columns ]] && [[ -z $___LAST ]]; then
                for (( ___i=1; ___i<=$#argv; ++___i )); do
                    argv[___i]+="${___esep}\$${___i}"
                done
            fi
            ___expr=${(e)___expr}
        }

        for (( ___i=0; ___i<___row; ___i++ )); do
            (( ___i==(___row-1) )) && ___LAST=1
            acc.expand "${(@)___argv[___i*col_size+1,(___i+1)*col_size]}"
        done
        echo "$___expr"
    )   
}




# new template handler
function z() {
    (
        function help() {
            print '''
$ z TEMPLATE
'''
        }

        
        [[ -z $argv ]] && help && return 0
        zparseopts -K -D -- I=flags
        @EF $flags
        local Z_SOURCE="$1" && shift;


        local _line _handler 
        local -a _chunk _echunk
        local _context=:NONE
        setopt EXTENDED_GLOB

        function evalchunk() {
            # has echunk
            [[ -n $_echunk ]] && <<< ${(eF)_echunk} && _echunk=()
            (( $#_chunk    )) || return

            # has chunk, pipe to it's handler
            <<< ${(F)_chunk} eval "$_handler"

            # reset state
            _chunk=()
            _handler=
        }

        function @i() {
            # skip interactive mode
            [[ -n $flags[(r)-I] ]] && return
            local content="$(<&0)"
            eval "$(<<< ${(e)content} | vipe)"
            # eval $xxx
        }

        function @e() {
            local sh
            sh="$(<&0)"
            eval "$sh"
            @EF "$sh"
        }

        function @echo() {
            <<< "$(<&0)"
        }

        for _line in "${(@f)$(<$Z_SOURCE)}"; do

            if [[ $_line = (#b)\#----(-)#\|(\ )#(*) ]]; then
                evalchunk
                _context=:CHUNK
                _handler="$match[3]"
            elif [[ $_line = (#b)\#----(-)# ]]; then
                _context=:CHUNK_END
                evalchunk
            else
                [[ $_context = :CHUNK ]] && _chunk+=$_line && continue
                _echunk+=$_line
            fi
        done
        
        # ensure last chunk be evaled
        evalchunk
    )
}

# f命令负责将内容放置到磁盘上
function f() {
    (
    setopt EXTENDED_GLOB
    local -A map
    local store_spec target
    
    function writer.stdout() {
        <<< ${(F)content}
    }
    
    function writer.file() {
        # TODO: append writer support ???
        local file="$1"
        [[ $file == @stdout ]] && <<< ${(F)content} &&  content=() && return
        [[ -z $content ]] && @EF "没有输出内容" && return
        [[ -z $file    ]] && @EF "没有输出文件" && return
        local parent=$(dirname $file)

        # ensure the directory existed
        [[ -d $parent ]] || mkdir -p "$parent"
        <<< ${(F)content} > "$file"
        content=()
    }

    type=file
    local -a content
    for _line in "${(@f)$(<&0)}"; do
        # @IF $_line
        if [[ $_line = (#b)\====(=)#\|(\ )#(*) ]]; then
            writer.$type ${target%%(\ )#}
            # store_spec=$match[3]
            target=$match[3]
            continue
        fi
        content+="$_line"
    done
    
    writer.$type ${target%%(\ )#}
                # TODO 检测结果
    )
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
function ztemplate() {
    local selected
    
    function select_template() {
        (
            cd $ZHOME/$1
            local -a ztemplate
            ztemplate=(**/*.z)

            PROMPT3="选择一个模板'$ZHOME/$1'(q:退出): "
            select selected in $ztemplate; do
                if [[ "$REPLY" = q ]];  then
                    break
                elif [[ -n "$REPLY" ]]; then
                    <<< "$selected"
                    break
                fi
            done
        )
    }

    selected=${ZHOME}/$1/$(select_template $*)
    z $selected
}
