#!/bin/zsh
# 用于保存一些临时的想法
#---------------------------------------------------------------[ alias ]
alias __DEBUG_ARGS__='print -u2 $0 : $#argv $argv'


#---------------------------------------------------------------[ date ]
alias now.yymmdd='date +%Y%m%d'

#---------------------------------------------------------------[ utils ]
# shell转函数
script2function() {
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


function android.color.rm() {
SEDCMD='/<color name="$x">.*color>/d'

function color_rm() {
    local -a sedcmd

    for x in $argv; do
        sedcmd+=-e
        sedcmd+=${(e)SEDCMD}
    done

    for f in $targets; do
        sed -i $sedcmd $f
    done
}

function main() {
    local -a rmset
    
    if [[ -z $argv ]] ; then
        local input="$(<&0)"
        rmset=(${(@f)input})
    else
        rmset=($argv)
    fi

    color_rm $rmset
}

local -a targets

targets=($(print -l */**/colors.xml))

print 'FOUND COLOR IN: '
print -lC4 $targets
main "$@"
}


function android.memory.leak() {
# @author: amas
# @desc: collect the target package's vm heap dump information, it will be
# found @/data/misc/*.hprof
#
# 1. find the package pid
# 2. kill -10 $pid
# 3. adb shell pull /data/misc/xxx.hprof $local
# 4. convert the .hprof file from the dalivk vm format to standard one.
# 5. launch anaylise application (e.g: MAT)
PKG=$1
PKG_PID=$(adb shell ps | grep $PKG | awk '{print $2}')

echo "PKG=$1 PID=$PKG_PID"
adb shell chmod 777 /data/misc
adb shell kill 10 $PKG_PID

adb pull /data/misc/ .

HPROF_LIST=($(echo *.hprof))
echo "DUMP=$HPROF_LIST"

for x in $HPROF_LIST; do
    hprof-conv $x $x.std
done
}


function android.menu() {
#!/bin/sh
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

#adb shell ps |  awk '{print "pid=$2 name=$9"}'

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


function android.string.diff() {

# $1: string id
# $2: string file name
function android.strings.get() {
    local _strings_key=$1
    local _strings_xml=$2

    xmlstarlet sel -t -c "/resources/string[@name='$_strings_key']/node()" $_strings_xml
}


# $1 : string.xml
# $2 : string.xml'
function main() {
    local _strings_xml_0=$1
    local _strings_xml_1=$2

    local _v0=''
    local _v1=''
    local _src=''

    print -u2 "01 : $1"
    print -u2 "01 : $2"
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


main $*
}


function android.string.get() {
# $1: string id
# $2: string file name
local _strings_key=$1
local _strings_xml=$2

xmlstarlet sel -t -c "/resources/string[@name='$_strings_key']/node()" $_strings_xml
}


function android.string.put() {
function main() {
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

main "$*"
}


function android.strings.rm() {
#!/bin/zsh

SEDCMD='/<string name="$x">.*string>/d'

function strings_rm() {
    local -a sedcmd

    for x in $argv; do
        sedcmd+=-e
        sedcmd+=${(e)SEDCMD}
    done

    for f in $targets; do
        echo "处理: $f ($sedcmd)"
        sed -i $sedcmd $f
    done
}

function main() {
    local -a rmset
    
    if [[ -z $argv ]] ; then
        local input="$(<&0)"
        rmset=(${(@f)input})
    else
        rmset=($argv)
    fi

    strings_rm $rmset
}

local -a targets

targets=($(print -l */**/strings.xml))

print 'FOUND STRINGS IN: '
print -lC4 $targets
main "$@"
}


function android.su() {
#!/bin/zsh
(
adb=(adb shell)
su=$(adb shell 'ls /system/bin/su 2&> /dev/null || ls /system/xbin/su 2&> /dev/null')

[[ -n $su ]] && adb+=(su -c) || print -u2 'NOT rooted, use "adb shell"!!!'

adb+="$*"
$adb
)
}


function android.top() {
    adb shell dumpsys window windows | grep -E 'mCurrentFocus|mFocusedApp'
}


function android.uninstall() {

words=$1
ts=($(adb shell pm list packages | grep "$words"))

# NOT FOUND ANY MATCHED PACKAGES
[[ -z $ts ]] && print -u2 NOT FOUND: $words && return 1

# FOUND ONLY MATCHED
(( $#ts == 1 )) && {
    print UNINSTALL: ${ts[1]#package:}
    p=${${ts[1]#package:}%$''}
    adb uninstall ${ts[1]#package:}
    return
}

print -l $ts
}


function android.xml.ed() {
#!/bin/zsh
# @author: amas
# @desc  : zsh script collection for android xml file editing
# 
# e.g:
# $ . ~/Downloads/android.xml.ed
# $ android.strings2csv strings.xml
#
# NOTICE(amas):
#  - 如果需要直接修改XML文件，请使用-L参数，否则修改结果将打印到STDOUT中
#
#
# TODO:
#  1. Diff string.xml
#  2. csv2xml
#  3. patch the diff file
#
# diff file1.csv file2.csv --old-line-format="< %L" --new-line-format="> %L" --unchanged-line-format="= %L"
export ANDROID_XML_NS="android=http://schemas.android.com/apk/res/android"
export XLIFF_XML_NS="xliff=urn:oasis:names:tc:xliff:document:1.2"

function main() {
        
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

function android.strings.hash() {
    local _strings_xml=$1
    local _out=$2

    local _v=''

    _keys=($(xmlstarlet sel -t -m "/resources/string" -v @name -o ' ' $_strings_xml))
    
    typeset -A hash_map

    for x in $_keys; do
        hash_map[$x]=$(android.strings.get $x $_strings_xml | md5sum | sed -e 's/[ -]//g')
    done

    echo $hash_map
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



function android.strings2array() {
    local _strings_xml=$1
    local _PH="===::~::===" # place holder for internal proc
    local _delim=' '
    local _quot="'"
    xmlstarlet sel -t -m "/resources/string" -o $_PH  -v "@name" -o $_PH -o $_delim -o $_PH -c "node()" -o $_PH -n $_strings_xml | sed -e 's/mlns:xliff=.*" //g' -e "s/"/""/g" -e "s/$_PH/$_quot/g"
}
