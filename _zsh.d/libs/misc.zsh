#!/bin/zsh
# 用于保存一些临时的想法
#---------------------------------------------------------------[ debug ]
alias __DEBUG_ARGS__='print -u2 $0 : $#argv $argv'

#---------------------------------------------------------------[ alias ]

# 统计当前目录想下面的文件类型及数量
function suffix() {
    local -A map
    local suffix
    for f in **/*(.); do
        suffix=${f##*.} 
        (( $#suffix == $#f )) && continue
        map[$suffix]=$(( $map[$suffix] + 1 ))
    done
    print -l ${(k)map}
}

alias json.format='python -mjson.tool'
alias xml.format="xmlstarlet fo -s 4"
alias urlencode='python2 -c "import sys, urllib as ul; print ul.quote_plus(sys.argv[1])"'
alias urldecode='python2 -c "import sys, urllib as ul; print ul.unquote_plus(sys.argv[1])"'
#---------------------------------------------------------------[ system ]
alias du='du -h'
alias df='df -h'
alias c="git commit -am"

## X11 
alias x11-get-wm-class='msgI "Please click a window !!!" ; xprop | grep  WM_CLASS'
alias x11-get-wm-name='msgI "Please click a window !!!" ; xprop | grep  ^WM_NAME'
#---------------------------------------------------------------[ archlinux ]
alias pacman.rm.unused=pacman -Rns $(pacman -Qtdq)

# 列出除了base组以外安装的全部包名
function pacman.installed() {
    for p in "${(@f)$(pacman -Qg)}"; do
        xs=(${(s: :)p})
        [[ $xs[1] = 'base' ]] && continue
        print $xs[2]
    done
}
# 当前正在使用的内核支持的acpi模块列表
alias acpi.ls.mod="ls -l /lib/modules/$(uname -r)/kernel/drivers/acpi"
alias acpi.cd.mod_dir="cd /lib/modules/$(uname -r)/kernel/drivers/acpi"
alias pacman.rank-mirrors='sudo rankmirrors -n 5 /etc/pacman.d/mirrorlist.org > /etc/pacman.d/mirrorlist'


alias pacman-rm.package='sudo pacman -R'
alias pacman-rm.package.and-nouse-depend="sudo pacman -Rs"
# pacman会备份被删除程序的配置文件，将它们加上*.pacsave扩展名。如果你在删除软件包时要同时删除相应的配置文件
alias pacman-rm.package.and-keep-config="sudo pacman -Rn"

alias pacman.make-world='sudo pacman -Sy ; pacman -Su'
alias pacman.search='sudo pacman -Ss'
alias pacman.search-local='sudo pacman -Qs'
alias pacman.files='sudo pacman -Ql'
alias pacman.which='sudo pacman -Qo'
alias pacman.download='sudo pacman -Sw'
alias pacman.install-local='sudo pacman -U'
#仅在你确定不需要做任何软件包降级工作时才这样做。pacman -Scc会从缓存中删除所有软件包。
alias pacman.clear-cache='sudo pacman -Scc'
alias pacman.edit-conf='sudo vim /etc/pacman.conf'


#---------------------------------------------------------------[ network ] 
# HTTP
alias http.get-head='curl --head'
alias http.delete='curl -X DELETE'
alias http.get='curl -X GET'
alias http.put='curl -X PUT'
alias git.show.version='git rev-parse --short HEAD'
alias git.pack='git archive -o latest.zip HEAD'


function http.status() {
    curl -s -L --head -w "%{http_code}\n" "$1" | tail -n1
}

function wgetd() {
# Download all files in specify URL with specify extention.
#
# -r  : 递归下载
# -l1 : 递归下载深度为1,即只下载当前目录下的连接
# -H  : SpanDomains, 追踪其它站点的URLs
# -np : "No Parent", 不追踪父目录的URLS
# -nd : 将所有符合条件的资源保存到同一目录下，而不是克隆网站的目录结构
# -A  : 只下载指定后缀名的文件
# -erobots=off : 忽略标准的robots.txt文件
# -w5 : 每次下载请求间隔5秒
    local url="$1"
    local fileSuffix="$2"
    wget -r -l1 -H -t1 -nd -N -np -A.$fileSuffix -w2 -erobots=off $url
}

alias www.clone=wget -r -l20 -H -np -erobots=off "$@"                  # 克隆网站
alias www.httpd='python -m SimpleHTTPServer || python -m http.server'  #  简单的HTTP文件服务器 

functions ip.lan() {
    ip addr show | sed -n '/ether/ {n;p}' | awk '{print $2}' | sed -e 's/\/.*//g' 
}

function www.httpd() {
    print http://$(ip.lan):8000
    print
    print
    python -m SimpleHTTPServer || python -m http.server
}
#---------------------------------------------------------------[ math ]
function n() {
    for x in {1..63}; do
        print $x=$(( 2**x ))
    done
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

function cgrep()    { print -l **/*.c    | xargs  grep --color -n "$*" } 
function cppgrep()  { print -l **/*.cpp  | xargs  grep --color -n "$*" }
function javagrep() { print -l **/*.java | xargs  grep --color -n "$*" } 
function pygrep()   { print -l **/*.py   | xargs  grep --color -n "$*" }

function sourcegrep() {
    unsetopt NOMATCH
    print -l **/*.py       \
             **/*.c        \
             **/*.cpp      \
             **/*.java     \
             **/*.gradle   \
             | xargs  grep --color -n "$*"
    setopt NOMATCH
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
# print dex file header
alias dex.header="dexdump -f classes.dex | sed  '/^$/Q'"
alias android.cpu='adb shell cat /proc/cpuinfo'
alias android.cpu.core='adb shell cat /proc/cpuinfo | grep processor | wc -l'
alias android.load='watch -n 1 cat /proc/loadavg'
alias android.vmstat='adb shell vmstat'

function android.device.package-3rd() {
    packages=(${${$(adb shell pm list packages -3)#package:}%$'\u0d'}) 
    local regex="$*"
    
    print -l ${(M)packages:#*$regex*}
}

function android.device.package-sys() {
    packages=(${${$(adb shell pm list packages -s)#package:}%$'\u0d'}) 
    local regex="$*"
    
    print -l ${(M)packages:#*$regex*}
}

# print all packages installed on the device
# android.device.packages [<regex>]
function android.device.packages() {
    packages=(${${$(adb shell pm list packages)#package:}%$'\u0d'}) 
    local regex="$*"
    
    print -l ${(M)packages:#*$regex*}
}

function android.device.permissions() {
    perms=(${${$(adb shell pm list permissions)#package:}%$'\u0d'}) 
    print -l $perms
}

function android.device.uid() {
    local -a xs
    xs=($(adb shell ps $1))
    print $xs[-1]
}

function android.adb.service.list() {
    local -a xs
    xs=($(adb shell service list | cut -f2))
    print $xs
}

function android.adb.unisntall() {
   local -a px 
   px=($(android.device.packages $1))
   print -l $px
   adb uninstall $px[1]
}

# MONIT THREAD: for pid in %s; do pname=$(cat /proc/$pid/cmdline); for x in /proc/$pid/task/*; do echo $pname $pid $(cat $x/stat); done done

function android.list.so() {
    pid=$1
    adb shell cat /proc/$pid/maps | grep .so | uniq | sort
}

function android.pids() {
    adb shell ps | awk '/'"$1"'/ {print $2" "$1" "$9}'
}

function android.device.get-version() {
    packagename=($(android.device.packages $1))
    [[ -z $packagename ]] && return
    for p in $packagename; do
        print $p
        adb shell dumpsys package $packagename | grep version
    done
}

function android.device.get-top-activity() {
    adb shell dumpsys activity | grep mFocused
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
