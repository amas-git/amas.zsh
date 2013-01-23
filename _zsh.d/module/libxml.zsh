#!/bin/zsh
typeset -A XML_ATTRS
alias xml.edit.subnode="xmlstarlet ed -P -L -s"
alias xml.edit.update="xmlstarlet ed -P -L -u"

alias xml.listE="xmlstarlet el"
alias xml.listEA="xmlstarlet el -a"
alias xml.listEAV="xmlstarlet el -v"
alias uuid='echo "x$(uuidgen)"' # lower performance
alias uuid="echo x_${RANDOM}_${RANDOM}"
# 获取指定元素下的属性值
# $1: xpath
# $2: attribute name
function xml.getAttribute() {
    local xpath="$1"
    local attr_name="$2"
    local file="$3" ; [[ -f $file ]] || @E "file : '$file' not found"

    xmlstarlet sel -t -m "$xpath" -v "@${attr_name}" "$file"
}

function xpath.matched() {
    local xpath="$1"
    echo "$(<&0)" | xml sel -I -t -i "$xpath" -o "true" --else -o "false"
}

function xpath.matched.accept() {
    help() {
        echo "xpath.matched.accept xpath"
        echo "如果匹配xpath,输出整个文档，否则输出空"
    }
    local xpath="$1"
    echo "$(<&0)" | xmlstarlet sel -I -D -t -i "$xpath" -c "/"
}

function xpath.matched.refuse() {
    help() {
        echo "xpath.matched.refuse"
        echo "如果匹配xpath,则输出空，否则输出整个文档"
    }
    local xpath="$1"
    echo "$(<&0)" | xmlstarlet sel -E "utf-8" -I -D -t -i "$xpath" -o "" --else -c "/"
}

function deleteElement() {
    local xpath="$1" ; shift
    echo $(<&0) | xmlstarlet ed -d "$xpath"
}

function updateElement() {
    help() {
        echo "updateElement xpath [-value value] [attr1=value1 attr2=value2 ... attrN=valueN]"
        echo "No Docs!"
    }
    [[ $# < 1 ]] && help && return -1
    local xpath="$1" ; shift
    local skipValue=$argv[(r)-value]

    local opts
    zparseopts -A opts -K -D -E  -- value:=opts
    
    local xml=
    local elementValue=$opts[-value]
    xml=$(<&0)
    
    [[ -z $xml ]] && return 0

    local name value options
    if [[ -n $skipValue ]]; then
        options+=" -u \"$xpath\" -v \"$elementValue\""
    fi

    # TODO(amas): use s:=: replace it
    setopt EXTENDED_GLOB
    for x in $argv; do 
       if [[ $x = (#b)(*)=(*) ]]; then
           name=$match[1]
           value=$match[2]  
           options+=" -d \"$xpath/@$name\" -s \"$xpath\" -t attr -n \"$name\"  -v \"$value\""
       fi
    done
    unsetopt EXTENDED_GLOB
    eval "echo \$xml | xml ed $options"
}

function newElement+() {
    help() {
        echo "newElement /parent/element -name elementName [-value elementValue] [attr1=value1 attr2=value2 ...]"
        echo 'e.g:'
        echo '$ echo "<a></a>" | newElement /a/xxx "" id=1'
        echo '<?xml version="1.0"?>'
        echo '<a>'
        echo '  <xxx id="1" />'
        echo '</a>'
        echo ' -guard : xpath test condition, if matched guard, the new element will NOT added'
    }
    [[ $# < 1 ]] && help && return -2
    local opts
    zparseopts -A opts -K -D -E  -- name:=opts value:=opts guard:=opts g:=opts
    local xml=
    xml=$(<&0)
    local parent="$1"; shift
    local elementN=$opts[-name] ; [[ -z $elementN ]] && help && return -6
    local elementV=$opts[-value]
    local guard="$opts[-guard]"
    local O="$opts[-g]" 
    [[ -n $ns ]] && O+=" -N $ns"

    [[ -z $xml ]] && return 0

    local guardMached=
    # guard test
    if [[ -n $guard ]]; then
        guardMached=$(echo "$xml" | xml sel -I -t -i "$guard" -o "true" --else -o "false")
        @DF "guard='$guard' test result: '$guardMached'"
        [[ $guardMached == true ]] && echo "$xml" && return 0
    fi

    local name value options
    local uuid=$(uuid)
    options+="$O -s \"$parent\"  -t elem -n $uuid -v \"$elementV\""
    

    local pair
    pair=()
    for x in $argv ; do 
       pair=(${(s:=:)x})
       name=$pair[1]
       value=$pair[2]    
       options+=" -s \"$parent/$uuid\" -t attr -n $name -v \"$value\""
    done
    #logf "echo \$xml | xml ed $options -r //$uuid -v $elementN"
    eval "echo \$xml | xml ed $XML_OPTS $options -r //$uuid -v $elementN"
}

# same as newElement except  duplicated attribute only keep the last one
function newElement() {
    help() {
        echo "newElement /parent/element -name elementName [-value elementValue] [attr1=value1 attr2=value2 ...]"
        echo 'e.g:'
        echo '$ echo "<a></a>" | newElement /a/xxx "" id=1'
        echo '<?xml version="1.0"?>'
        echo '<a>'
        echo '  <xxx id="1" />'
        echo '</a>'
        echo ' -guard : xpath test condition, if matched guard, the new element will NOT added'
    }
    [[ $# < 1 ]] && help && return -2
    local opts
    zparseopts -A opts -K -D -E  -- name:=opts value:=opts guard:=opts g:=opts
    local xml=
    xml=$(<&0)
    local parent="$1"; shift
    local elementN=$opts[-name] ; [[ -z $elementN ]] && help && return -6
    local elementV=$opts[-value]
    local guard="$opts[-guard]"
    local O="$opts[-g]" 

    [[ -z $xml ]] && return 0

    local guardMached=
    # guard test
    if [[ -n $guard ]]; then
        guardMached=$(echo "$xml" | xml sel -I -t -i "$guard" -o "true" --else -o "false")
        @DF "guard='$guard' test result: '$guardMached'"
        [[ $guardMached == true ]] && echo "$xml" && return 0
    fi

    local name value options
    local uuid=$(uuid)
    options+="$O -s \"$parent\"  -t elem -n $uuid -v \"$elementV\""
    
    local pair
    local -A amap
    pair=()
    for x in $argv ; do 
       pair=(${(s:=:)x})
       name=$pair[1]
       value=$pair[2] 
       [[ -n $value ]] && amap[$name]=" -s \"$parent/$uuid\" -t attr -n $name -v \"$value\""
       # options+=" -s \"$parent/$uuid\" -t attr -n $name -v \"$value\""
    done
    options+=$(print ${(o)amap})
    # @EF "$options"
    
    # @DF "echo \$xml | xml ed $options -r //$uuid -v $elementN"
    eval "echo \$xml | xml ed $XML_OPTS $options -r //$uuid -v $elementN"
}

# 更方便书写xml
function list2xml() {
    # local spec="$1"
    
    # local opts
    zparseopts -A opts -K -D -E  -- g:=opts
    local O="$opts[-g]"
    local spec=

    if (( $#argv > 0 )); then
        spec="$*"
    else
        spec="$(<&0)"
    fi

    # @EF "$spec"

    local -a stack

    ### stack
    stack=()
    put() { stack=("$1" $stack) }
    pop() { (( $#stack > 0 )) && stack=($stack[1,-2]) || return -1 }
    top() { print $stack[-1] }
    
  

    local -A map
    map=()
    local -i height=0
    local -i maxHeight=0
    
    local base s
    local -a child childNum
    child=()
    childNum=()
    base=""

    
    on-new-word () {
        local w="$1"

        if [[ -n $w ]]; then
            if [[ -z  $map[$base] ]]; then
                # base=$(dirname $base)/$w
                # @IF "base=$base"
                map[$base]+="//*[@_id='$(dirname $base)'] $w"     
            else
                map[$base]+=" $w"
            fi 
        fi
        word=
    }

    
    # NOTE: performance tunning
    # 1: bare loop are very slow!!!
    # integer time=$(date +%s%N)
    integer size
    size=$#spec
    for (( i=1; i<=size; ++i)) do     
        c="$spec[i]"
        if (( false )); then
            break
        elif [[ $c == ' ' || $c == $'\n' ]]; then 
            on-new-word  "$word"
        elif [[ $c == '(' ]]; then 
            on-new-word  "$word"
            (( maxHeight=++height ))
            (( childNum[height]+=1 ))
            base+="/$childNum[height]"
            put "$c"
        elif [[ $c == ')' ]]; then
            on-new-word  "$word"
            (( --height ))
            base=$(dirname $base)
            pop || return -3
        else
            word+="$c"
        fi           
    done
    
    # time2=$(date +%s%N)
    # @DF "SPEC --> MAP: DONE : $#map 元素 $(( ($time2-$time) / 1000000 )) 毫秒 "
    local xml='<?xml version="1.0" encoding="utf-8"?>
<root/>'
    local name p

    local -i n=1
    for id in ${(ok)map};do
        # print -f "%-20s : '%s'\n" $elem $map[$elem]
        child=(${=map[$id]})
        xparent="$child[1]"
        name="$child[2]"

        # @EF "$xparent/$name [ $child[3,-1] ]"
        if (( n == 1)); then
            # @EF "$child[3,-1]"
            xml=$(echo "$xml" | newElement  /root -name $name _id=$id $child[3,-1] 2> /dev/null)
            xml=$(echo "$xml" | xml sel -D -E "utf-8" -t -m /root -c 'node()' 2> /dev/null )
        else
            xml=$(echo "$xml" | newElement "$xparent" -name $name _id="$id" $child[3,-1] 2> /dev/null)
        fi
        (( n++ ))
    done
    echo "$xml" | xml ed -O -d "//@_id" 2> /dev/null
    # @EF "Tree: height=$maxHeight  stack='$stack'"
    

    if [[ -n $stack ]]; then
        s=-2
    fi 
    return $s
}
