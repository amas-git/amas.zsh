#!/bin/zsh
typeset -A IMPORTS

# mkclass -class foo.bar.ClassName [-rf func] [-gf func] [-v]
# -v : verbose output
# -rf: root function for searching project root
# -gf: generator functions for create body
# -class : full class name (e.g.: foo.bar.HelloWorld)
# ----------------------------------------------------
# expose variables:
#  * CLASS
#  * CLASSNAME
#  * BASENAME
#  * PACKAGE
#
# TODO:
# FIXME -> mkclass -class Test
alias mkclass.writer=basewriter
function mkclass() {
    ctrl=()
    # rootf function for find project root
    function parse_options() {
        zparseopts -A opts -K -D -- body:=opts rf:=opts class:=opts v=ctrl
    }
    parse_options $*
    
    # TODO: check_class_name
    local rf=$opts[-rf]
    local body=${opts[-body]} ; [[ -z "$body" ]] && body=$(gf-java-simpleclass)
    local verbose=$ctrl[(r)-v]

    CLASS=$opts[-class]
    CLASSNAME=$(java-classname $CLASS)
    PACKAGE=$(java-package-name $CLASS)
    
    local src="$(eval ${rf:=pwd})"; [[ -z $src ]] && src="."
    local classd=$src/$(dirname ${CLASS//.//})

    # mk package dir
    [[ -d $classd ]] || mkdir -p $classd
    
    if [[ -n $verbose ]]; then
        _ CLASS
        _ PACKAGE
        _ CLASSNAME
        _ classd
        _ rf
        #logd "$CLASS" "$body"
    fi
    echo "$body" | mkclass.writer "$classd/${CLASSNAME}.java"
}

function require-class() {
    require+ CLASS -c "${1:=Enter full class name}"
    CLASSNAME=$(java-classname $CLASS)
    PACKAGE=$(java-package-name $CLASS)
    @IF "CLASS=$CLASS CLASSNAME=$CLASSNAME PACKAGE=$PACKAGE"
}

function imports() {
    for x in $IMPORTS; do
        echo "import $x;"
    done
}

alias java.cn=java-classname
alias java.pn=java-package-name
function java-package-name() {
    help() {
        echo "$(basename $0) foo.bar.HelloWorld"
        echo "foo.bar"
    }
    local class="$1"
    local -a xs
    xs=(${(s:.:)class})
    if (( $#xs > 1 )); then
        echo "${(j:.:)xs[1,-2]}"
    fi
}

function java-classname() {
    local class="$1"
    local -a xs
    xs=(${(s:.:)class})
    echo $xs[-1]
}


#+add::int -- x::int y::String  -> public int add(int x, int y)
typeset -A JAVA_RV_MAP
JAVA_RV_MAP[int]=0
JAVA_RV_MAP[char]=0
JAVA_RV_MAP[boolean]=false
JAVA_RV_MAP[long]=0
JAVA_RV_MAP[float]=0f
JAVA_RV_MAP[double]=0
JAVA_RV_MAP[void]=''


function java.variable() {
    help() {
        echo "java.variable [variable-spec] ..."
        echo "[variable-spec]:"
        echo "    [-+*]name::type"
        echo "    +: public"
        echo "    -: private"
        echo "    *: protected"
        echo "[options]:"
        echo "    -s: static"
        echo "    -f: final"
        echo "[e.g]:"
        echo "$ java.variable -name::String -age::int +TAG::String"
        echo "private  String name;"
        echo "private  int age;"
        echo "public  String TAG;"
    }
    [[ -z $argv ]] && help && return
    local -a modifier triple flags
    flags=()
    zparseopts -A opts -K -D -- lv:=opts s=flags f=flags 
    [[ -n $flags[(r)-s] ]] && modifier+=static
    [[ -n $flags[(r)-f] ]] && modifier+=final
    names=()
    types=()
    local name type
    for varSpec in $argv; do
        local -a m
        m=()
        [[ $varSpec[1] == '-' ]] && varSpec="$varSpec[2,-1]" && m+=private
        [[ $varSpec[1] == '+' ]] && varSpec="$varSpec[2,-1]" && m+=public
        [[ $varSpec[1] == '#' ]] && varSpec="$varSpec[2,-1]" && m+=protected
        m+=$modifier
        triple=(${(s=::=)varSpec})
        name=$triple[1]
        type=$triple[2]
        names+=$name
        types+=$type
        print "$m $type $name;"
    done
}

function java.method() {
    help() {
        echo "echo [function-body]  | java.method [+-*]function-name::return-type -- param1::parame-type1 ... paramN::param-typeN "
        echo '[options]'
        echo '    -s: static'
        echo '    -f: final'
        echo '    -r: auto generate *return* statement'
        echo "e.g: "
        echo '$ echo "return x+y;" | java.method -add::int -- x::int y::int'
        echo 'private int add(int x, int y) {'
        echo '    return x+y;'
        echo '}'
    }
    [[ -z $argv ]] &&  help && return 0
    local paramsSpec funcSpec  funcSpec_ n r rv nt params modifier statements
    statements=("${(f)$(<&0)}")
    modifier=()
    local flags
    zparseopts -A opts -K -D -- r=flags s=flags f=flags 
    
    # @EF "$flags"
    integer nx=$argv[(i)--]
    funcSpec="$argv[1,nx-1]"
    paramsSpec=($argv[nx+1,-1])
    
    funcSpec_=(${(s=::=)funcSpec})
    n=$funcSpec_[1]
    r=$funcSpec_[2]
    if [[ -n $n ]]; then
        [[ $n[1] == '-' ]] && n="$n[2,-1]" && modifier+=private
        [[ $n[1] == '+' ]] && n="$n[2,-1]" && modifier+=public
        [[ $n[1] == '#' ]] && n="$n[2,-1]" && modifier+=protected
    fi
    [[ -n $flags[(r)-s] ]] && modifier+=static
    [[ -n $flags[(r)-f] ]] && modifier+=final

    params=()
    for x in $paramsSpec; do
       nt=(${(s=::=)x})
       params+="$nt[2] $nt[1]"
    done
    
    [[ -n $flags[(r)-r] ]] && statements+="return $JAVA_RV_MAP[$r];"
    # @EF "$method $name $r $params"
    print "${modifier} $r $n(${(j:, :)params}) {\n    $(print -l ${statements})\n}"
}

function textAcc() {
    local acc=
    local template="$1"
    acc=$(<&0)
    setopt EXTENDED_GLOB
    for x in $argv ; do 
       if [[ $x = (#b)(*)=(*) ]]; then
          name=$match[1]
          value=$match[2]
          eval "local $name=$value"
       fi
    done
    unsetopt EXTENDED_GLOB
    echo $acc
    tf "$template"
}


function java.format() {
    local javacode="$(<&0)"

    local tmpFile="/tmp/$(uuid).java"
    echo "$javacode" > $tmpFile && astyle -s4 -j < "$tmpFile"
    rm $tmpFile
}
