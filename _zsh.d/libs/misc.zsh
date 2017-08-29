#!/bin/zsh
# 用于保存一些临时的想法
#---------------------------------------------------------------[ alias ]
alias __DEBUG_ARGS__='print -u2 $0 : $#argv $argv'

alias www.clone=wget -r -l20 -H -np -erobots=off "$@"                  # 克隆网站
alias www.httpd='python -m SimpleHTTPServer || python -m http.server'  #  简单的HTTP文件服务器 

# HTTP
alias http.get-head='curl --head'
alias http.delete='curl -X DELETE'
alias http.get='curl -X GET'
alias http.put='curl -X PUT'

function http.status() {
    curl -s -L --head -w "%{http_code}\n" "$1" | tail -n1
}

#---------------------------------------------------------------[ date ]
alias now.yymmdd='date +%Y%m%d'

# 给定年份是否是闰年
function isLeapYear() {
    typeset -i year="$1"
    (( year % 4 == 0 && year % 100 != 0 || year % 400 == 0 ))
}
#---------------------------------------------------------------[ utils ]
# shell转函数
function script2function() {
    function_template='
function $fname() {
$body
}
'

    for fname in $argv; do
        body=$(< $fname)
        print ${(e)function_template} 
    done
}

# filter all element by the given regex
# text.grep <regex>
function text.grep() {
    local regex=$argv[1]
    [[ -z $regex ]] && print -l $packages && return

}

function cgrep() {
    find . -type f -name '*.c' -print0 | xargs -0 grep --color -n "$@"
}
#---------------------------------------------------------------[ math ]
# 求和
function math.sum() {
    local -i sum
    for x in $argv; do
        sum+=x
    done
    print $sum
}
#---------------------------------------------------------------[ android.device ]

# print all packages installed on the device
# android.device.packages [<regex>]
function android.device.packages() {
    __DEBUG_ARGS__
    packages=(${${$(adb shell pm list packages)#package:}%$'\u0d'}) 
    local regex="$*"
    
    print -l ${(M)packages:#*$regex*}
}

function android.device.permissions() {
    perms=(${${$(adb shell pm list permissions)#package:}%$'\u0d'}) 
    print -l $perms
}


#---------------------------------------------------------------[ android.project ]
function android.project.home() {
    (
        local target=$(pwd)
        local project_type

        while [[ $target != / ]]; do
            project_type=$(project.type)
            [[ $project_type ==  android.* ]] && print $project_type:$target
            cd ..
            target=$(pwd)
        done
    )
}

function project.type() {
__='
@desc   : Gusess the project type of current dir 
@return : 
           * android.eclipse
           * android.studio
'
    # android studio project
    [[ -f app/src/main/AndroidManifest.xml ]] \
        && [[ -d app/src/main/java ]]         \
        && [[ -d app/src/main/res ]]          \
        && print android.studio
    # android eclipse project
    [[ -f AndroidManifest.xml              ]] \
        && [[ -d res ]]                       \
        && [[ -d src ]]                       \
        && print android.eclipse
}

function android.path.manifest() {
    local -a xs
    xs=(${(s=:=)$(android.project.home)})
    
    local m
    [[ $xs[1] == android.eclipse ]] && m=$xs[2]/AndroidManifest.xml
    [[ $xs[1] == android.studio  ]] && m=$xs[2]/app/src/main/AndroidManifest.xml

    [[ -f $m ]] && print $m
}

function android.package.name() {
    local m
    m=$(android.path.manifest)
    [[ -n $m ]] && {
        
    }
}



function android.adb.logcat() {
    LOGCAT_V='s/^V/'"$BG[default]$FG[b-green]"'&/g'
    LOGCAT_D='s/^D/'"$BG[default]$FG[b-cyan]"'&/g'
    LOGCAT_I='s/^I/'"$BG[default]$FG[b-yellow]"'&/g'
    LOGCAT_E='s/^E/'"$BG[b-red]"'&/g'
    LOGCAT_F=''
    END_RESET='s/$/'"$terminfo[sgr0]"'/g'
    OPERATOR='s/[-=<>+{}:]/'"$FG[b-write]"'&'"$terminfo[sgr0]"'/g'    
    NAMEING_SPACE_LIKE='s/([[:space:]=({])([[:alpha:]][-_[:alpha:]]*[.$][[:alpha:]][[:alpha:][:digit:].$@_/]*)/'"$FG[b-blue]"''"$terminfo[sgr0]"'/g'
    DIGITS='s/<[0-9][0-9]*>/'"$FG[b-cyan]"'&'"$terminfo[sgr0]"'/g'
    HEX_DIGITS='s/(0[xX]([[:xdigit:]][[:xdigit:]]*))/'"$FG[b-cyan]"'&'"$terminfo[sgr0]"'/g'

    # NOTE(zhoujb): do not change order of -e '...'
    adb logcat "$@" | sed -e $DIGITS -e $HEX_DIGITS -e $LOGCAT_E -e $NAMEING_SPACE_LIKE -e $END_RESET  -e $OPERATOR
}


SEDCMD='/<color name="$x">.*color>/d'
function anroid.color.rm() {
    local -a sedcmd

    for x in $argv; do
        sedcmd+=-e
        sedcmd+=${(e)SEDCMD}
    done

    for f in $targets; do
        sed -i $sedcmd $f
    done
}


function android.keyboard.click_menu() {
#/dev/input/event0: 0001 0066 00000001
#/dev/input/event0: 0000 0000 00000000
#/dev/input/event0: 0001 0066 00000000
#/dev/input/event0: 0000 0000 00000000
    adb shell sendevent /dev/input/event0 1 102 1
    adb shell sendevent /dev/input/event0 0 0 0 
    sleep 1
    adb shell sendevent /dev/input/event0 1 102 0
}


function android.packageinfo() {
#!/bin/zsh
words="$1"
ts=($(adb shell pm list packages | grep "$words"))

(( $#ts == 0 )) && print -u2 NOT FOUND: $words && return 1

function packageinfo() { 
    adb shell dumpsys package ${1%$''}
}

for t in ${ts}; do
    packageinfo ${t#package:}
done
}


function android.pid() {
    adb shell ps | grep $1 | awk '{print $2}'
}


function android.proc.dump() {
    local -A maps
    maps=()
    local -a pids
    pids=($(adb shell ps | awk '{print $2}'))

    for x in $pids; do
        echo "pid=$x" 
        echo " cmdline='$(android.su cat /proc/$x/cmdline)'"
    done
}


function android.project.clear() {
    rm -rf bin
    rm -rf gen
    rm -rf .project
    rm -rf .classpath
}


function android.remount() {
    (
        remount="mount -o remount /dev/block/mtdblock0 /system"
        su=$(adb shell 'ls /system/bin/su 2&>/dev/null || ls /system/xbin/su 2&>/dev/null')
        cmd=(adb shell)

        # rooted ?
        [[ -n $su ]] && cmd+=(su -c) 
    
        cmd+=$remount
        print "exec : $cmd"
        $cmd
    )
}


function android.string2csv() {
    local _file="$1"
    xmlstarlet sel -t -m resources/string  -v "concat(@name,', ',.)" -n "$_file"
}


# resources
# resources/skip
# resources/string
# resources/string/font
# resources/string/xliff:g
function android.strings.put() {
    local _name="$1"
    local _value="$2"
    local _strings_xml="$3"

    local _xpath="/resources/string[@name='$_name']"

    local _orgin_value=$(xmlstarlet sel -t -m $_xpath -v . $_strings_xml)

    # -P : 保留原XML的格式
    # -L : 直接编辑XML文件
    # -S : preserve non-significant spaces
    xmlstarlet ed -P -S -u $_xpath -v "$_value" "$_strings_xml" 
}

function android.strings.foreach() {
    local _strings_xml=$1

    _keys=($(xmlstarlet sel -t -m "/resources/string" -v @name -o ' ' $_strings_xml))
    
    for x in $_keys; do
        v=$(android.strings.get $x $_strings_xml)
        echo -E $x=$v SHA=$(echo $v | sha1sum)
    done
}

# $1 : string.xml
# $2 : string.xml'
function android.strings.diff() {
    local _strings_xml_0=$1
    local _strings_xml_1=$2

    local _v0=''
    local _v1=''
    local _src=''

    xmlstarlet sel -t -m "/resources/string" -v @name -n $_strings_xml_0 >  .keys
    xmlstarlet sel -t -m "/resources/string" -v @name -n $_strings_xml_1 >> .keys
    
    set -A keys $(echo $(sort -u --parallel=4 .keys | xargs))
    typeset -A merged

    echo "<resources>"
    for x in $keys; do 
        _v0=$(android.strings.get $x $_strings_xml_0) # | sha1sum | sed -e 's/[ -]//g')
        _v1=$(android.strings.get $x $_strings_xml_1) # | sha1sum | sed -e 's/[ -]//g')
        
        if [[ $_v0 = $_v1 ]]; then
            # unchanged string
        else
            [[ -z $_v0 ]] && merged[$x]="add" && _src=$_strings_xml_1
            [[ -z $_v1 ]] && merged[$x]="del" && _src=$_strings_xml_0
            [[ -n $_v0 ]] && [[ -n $_v1 ]] && [[ $_v0 != $_v1 ]] && merged[$x]="mod" && _src=$_strings_xml_1 # TODO(amas): trim then compare
            echo "<string name="$x" tag="$merged[$x]">$(android.strings.get $x $_src)</string>"
        fi
    done
    echo "</resources>"
}


function md5sum.string() {
    echo -E "$*" | md5sum | sed -e 's/[ -]//g'
}

# $1: string id
# $2: string file name
function android.strings.get() {
    local _strings_key=$1
    local _strings_xml=$2

    xmlstarlet sel -t -c "/resources/string[@name='$_strings_key']/node()" $_strings_xml
}
