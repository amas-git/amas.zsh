#!/bin/zsh
# 用于保存一些临时的想法
#---------------------------------------------------------------[ debug ]
alias __DEBUG_ARGS__='print -u2 $0 : $#argv $argv'

#---------------------------------------------------------------[ alias ]
alias git.config.credential.cache=git config --global credential.helper cache

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

alias ip.info='curl ipinfo.io/'
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

#---------------------------------------------------------------[ libgen ]
LIBGEN_HOST="http://93.174.95.29"
function libgen.search.md5() {
    for x in $argv; do
        local url="${LIBGEN_HOST}/_ads/${x}"    
        local content=$(curl -s "$url")
        local xs=$(print $content | tr -d '\n' | sed -n 's/.*\(main\/[0-9]*[^"]*\).*\/\(covers\/[0-9]*[^"]*\).*Author(s):\ \([^<]*\).*Publisher:\ \([^<]*\).*/\1\n\2\n\3\n\4/p')
        print $xs
    done
}

function libgen.id() {
    for x in $argv; do
        curl -s "http://libgen.is/book/bibtex.php?md5=$x"
    done
}

function libgen.search() {
    local keywords="$(urldecode $1)"
    local max=${2:=1}
    for n in {1..$max}; do
        local url="http://libgen.is/search.php?&res=100&req=${keywords}&phrase=0&view=detailed&column=def&sort=def&sortmode=ASC&page=${n}"
        libgen.ls $url
    done
}

# spider for libgen.ls
function libgen.ls() {
    local list="$1"
    local content
    content=$(curl -s "$list" | sed -n 's/.*href="..\/book\/index.php?md5=\([A-Z0-9]*\)">\(.*\)\(<\/a.*\)/\1|||\2/p')
    local xs
    local INTER=3
    local i=0
    local ys

    for x in "${(@f)content}"; do
        ys=("${(@s:|||:)x}")
        md5=$ys[1]
        name=$ys[2]
        
        (( ++i % $INTER == 0 )) && {
            sleep 0.31 
        }
        xs=("${(@f)$(libgen.search.md5 $md5)}")
        [[ -z $xs ]] && {
            continue
        }


        # 1: download link
        # 2: cover
        # 3: author
        # 4: publisher
        link=$LIBGEN_HOST/$xs[1]
        cover=$LIBGEN_HOST/$xs[2]
        author=$xs[3]
        publisher=$xs[4]
        print "$md5\t$link"
        print "\t- $name @$author"
        print "\t- $publisher"
        print "\t- ${link##*.}"
    done
}

function libgen_local_has() {
    local md5=$1
    [[ -d $LIBGEN_DB/.libgen/md5/$md5 ]] && return 0
    return 1
}

function libgen_download() {
    local -a xs
    xs=("${(@f)$(<&0)}")
    for x in $xs; do
        [[ $x =~ '[#!\ ].*' ]] && continue
        for link in "${(@ps:\t:)x}"; do
            libgen_local_has "$link" && break
            [[ "$link" =~ 'http.*' ]] || {
                continue
            }
            out="$(urldecode $(basename $link))"
            #axel -n 4 "$link" -o "$out"
            wget "$link"
            libgen_local_add "$out"
        done
    done
}

#$1: file1, file2,...,fileN
function libgen_local_add() {
    for f in $argv; do
        [[ -f "$f" ]] || continue
        md5=${(U)$(md5sum "$f" | cut  -d' ' -f1)}
        dir=$LIBGEN_DB/.libgen/md5/$md5
        [[ -d $dir ]] && print "existed" && continue
        mkdir -p $dir
        ln -sf "$(readlink -f $f)"  "$dir/$(basename $f)"
    done
}

function libgen_update() {
    local libhome=${1:=$LIBGEN_DB}
    LIBGEN_DB=$libhome
    local md5
    for f in $libhome/**/*(.); do
        libgen_local_add $f
        print "[DONE] $f"
    done
}

BOOKS_DB=~/.books

function search_home() {
    # max depth limited by FUNCNEST
    local target=${1}
    local dir=${2:=$(pwd)}
    [[ $dir = /          ]] && return -1
    [[ -d $dir/${target} ]] && print $dir && return
    search_home $target ${dir:h}
}

# home dir of b
function b.home() {
    search_home '.b'
}


#
# $ b.init <dir>
function b.init() {
    local b_home=$(b.home $1)
    [[ -d $b_home ]] && {
        print "EXISTED BHOME: '${b_home}'"
        return -1
    }
   
    # create db
    b_home=${${1:=.}:A}/.b
    mkdir $b_home
}

function b.isbook() {
    [[ ${1:e:l} = (pdf|epub|mobi|azw3|cbr|cbz|djvu) ]]
}

function b.backup() {

}

function b.md5() {
    print ${(U)$(md5sum -- "$1" | cut  -d' ' -f1)}
}

function error() {
    print "[E] : $1" && exit 1
}

function I() {
    print "[I] : $1"
}

function b.utils.needImport() {
    local bhome=$1
    local target=$2
    [[ ! $target = $bhome/* ]]
}

function b.store.has {
    local bhome="$1"
    local id="$2"
    local bookd=$bhome/.b/md5/$2

}

# $1: bhome
# $2: bookID (md5)
# @return: live links
# check the book on filesystem, if it moved, try to fix link
function b.store.checklink() {
    local bhome=$1
    local id=$2
    local loc
    local -a urls dead live
    local _urls=$bhome/.b/md5/$id/urls

    [[ -f $_urls ]] && urls=("${(@fu)$(<$_urls)}")

    for u in $urls; {
        [[ -f $bhome/$u ]] && live+=$u || dead+=$u
    }


    [[ -n $dead ]] && {
        print -l -- $live > "$_urls"    
    }
    [[ -z $live ]] && return -1
    print -l -- $live
    return 0
}

function b.search() {
    local bhome=$1
}

# $1: bhome
# $2: file path to the book
# added new book
function b.store.add() {
    local bhome=$1
    local book=$2
    local id=$3
    local needcp
    [[ -f $book  ]] || return 1
    [[ -d $bhome ]] || return 2

    b.utils.needImport "$bhome" "$book" && needcp=true
    
    local item=$bhome/.b/md5/$id
    [[ -d $item ]] || mkdir -p $item

    # read link
    local -a xs live dead
    [[ -f $item/urls ]] && xs=("${(@fu)$(<$item/urls)}")
    for x in $xs; {
        [[ -f "$bhome/$x" ]] && live+=$x || dead+=$x
    }

    # as least one live link
    [[ -n $live ]] && [[ -n $needcp ]] && {
        I "[SKIP][$id] AT LEAST HAVE 1 LIVE FILE"
        return 1
    }

    local to=${book#$bhome/}
    # copy if needed
    [[ -n $needcp ]] && {
        to=${bhome}/${book:h:t:u}/${book:t}
        if (( $#live <= 0 )); then
            [[ -d ${to:h} ]] || mkdir -p "${to:h}"
            [[ -f $to ]] || { 
                cp "$book" "$to" && {
                    I "[COPY TO] $to"
                }
            }
        fi
    }

    live+=$to
    [[ -n $live ]] && {
        print -l -- ${(u)live} > $item/urls
    }
    
    [[ -n $dead ]] && {
        print -l -- ${(u)dead} > $item/dead
    }
}

BHOME=/data


function b.homeOrExit() {
    [[ -d $1/.b ]] || {
        I "NOT BOOK HOME, EXIT(1)"
        exit 1
    }
}

function b.store.mv() {(
    local bhome=$1
    local book
    b.homeOrExit

)}

# clean useless file, fix bad link
function b.gc() {(
    local bhome=${1:=$(b.home)}
    b.homeOrExit $bhome
    cd $bhome/.b/
    local -a xs
    local -i total dup

    # calc the reserve book file
    function reserved() {
        local r
        for x in $argv; do
            # dead link 
            [[ -f $x ]] || {
                I "DEAD LINK : $x"
                print -n -- $x > $bhome/.b/md5/dead
                continue
            }
           
            [[ -z r ]] && r=$x
            # longest first
            (( ${#x:t} > $#r )) && {
                r=$x 
            }
        done
        print $r
    }

    function DEAD() {
        I "[DEAD] : $bhome/$item" 
    }

    function MANY() {
        local keep=$(reserved "${(@)xs}")
        I "[DUP($#xs)] : KEEP: $keep"
        [[ -d $bhome/.b/dup ]] || mkdir -p $bhome/.b/dup 
        for x in ${xs#$keep}; do
            I "    - [MV TO DUP]: $x"
            mv -- "$bhome/$x"  $bhome/.b/dup/
        done
        I ""
    }

    function NORM() {
        I "[OK] : $bhome/.b/$item"
    }

    for item in **/urls; {
        xs=("${(@f)$(b.store.checklink "$bhome" ${item:a:h:t})}")
        xs=(${(u)xs})
        local action=NORM
        [[ -z $xs   ]] && action=DEAD
        (( $#xs > 1 )) && action=MANY
        $action
    }
)}

# add book
function b.add() {(
    bhome=$(b.home)
    [[ -z $bhome ]] && bhome=${BHOME:A}
    [[ -z $bhome ]] && error "BHOME NOT FOUND, run b.init or set BHOME"

    local -a src xs
    local -i sum

    for x in $argv; {
        [[ -f $x ]] && src+=$x && continue
        for f in $x/**/*(.); {
            src+=$f
        }
    }

    [[ -z $src ]] && src=(**/*(.))
   
    for s in $src; {
        # is accepttale ebook format?
        book=${s:a}
        b.isbook "$book" || {
            I "[SKIP] : $book"
            mkdir -p $bhome/.SKIP
            mv "$book" $bhome/.SKIP
            continue
        }
        md5=$(b.md5 $book)

        b.store.add "$bhome" "$book" "$md5"
        (( sum++ ))
        I "[$sum/${#src}] : .b/md5/$md5/urls"
    }
)}

function libgen.meta() {
    local md5=$1
    [[ -z $md5 ]] && return -1
    local r
    r=$(noglob curl -s "http://libgen.is/book/bibtex.php?md5=${md5}")
    local error=$(echo $r | grep 'Wrong MD5')
    [[ -n $error ]] && {
        return -2
    }
    print $r
}

function books.name.normalize() {

}

function books.rename() {
    function rename() {
    
    }
    
    local -a xs
    for b in ${argv:=.}; do
        [[ -f $b ]] && {
            xs+=$b
            continue
        }
        for f in $b/**/*; do
            xs+=$f
        done
    done

    for x in $xs; do
        md5=${(U)$(md5sum "$x" | cut  -d' ' -f1)}
        if books.has $md5; then
            print "$x: existed : $(books.name.byMD5 $md5)"
        else
            print "$x: NEW"
        fi
    done
}

function books.name.byMD5() {
    echo -n $(< $BOOKS_DB/md5/${(U)1}/name)
}

function books.has() {
    [[ -d $BOOKS_DB/md5/${(U)1} ]]
}

# $1 : id (md5)
function books.info.byMD5() {
    local id=$1
    info=$BOOKS_DB/md5/$id
    [[ -d $info ]]
    print -l \
        "ID  : $id" \
        "NAME: $(<$info/name)" \
        "PATH: $(<$info/path)" \
        "META: $(<info/meta)"
}

function books.import() {
    local target=${1:=.}
    local md5
    for f in $target/**/*(.); do
        md5=${(U)$(md5sum "$f" | cut  -d' ' -f1)}
        dir=$BOOKS_DB/md5/${md5}
        __f=$(readlink -f $f)

        if [[ -d $dir ]]; then
            print "[EXISTED] : $md5:$f"
            continue 
        else
            print "[**NEW**] : $md5:$f"
            mkdir -p $dir
            name=$(basename "$f")
            echo $name > $dir/name

            meta=
            if [[ -f $dir/meta ]]; then
                meta=$(<$dir/meta)
            else
                meta=$(libgen.meta $md5)
                [[ -n $meta ]] && echo $meta > $dir/meta
            fi

        fi
        echo $__f    >> $dir/path
    done
}

function books.stat() {(
    local -A counter
    for id in $BOOKS_DB/md5/*; do
        [[ -d $id ]] || continue
        name=$(<$id/name)
        ___p=$(<$id/path)
        meta=$(<$id/path)
        (( 
            counter[TOTAL]++
        ))
    done
    typeset -p counter

)}
#---------------------------------------------------------------[ archlinux ]
alias pacman.rm.unused='pacman -Rns $(pacman -Qtdq)'

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

#---------------------------------------------------------------[ system ]
# created rsa key
function sshkeygen.rsa() {
    local id=${1:=id_rsa}
    ssh-keygen -t rsa -b 4096 -C "${RANDOM}@amas.com" -f $id && print "SUCCESS CREATED: $id|$id.pub"
}

# search the duplicated files
function ls.duplicate() {
    local target=${1:=.}
    local -A map
    local -a xs
    xs=(${target}/**/*)
    mkdir .DUP
    for f in ${(O)xs}; do
        [[ -d $f ]] && continue
        md5=${(U)$(md5sum "$f" | cut  -d' ' -f1)}
        [[ -z $md5 ]] && continue
        [[ -z $map[$md5] ]] || {
            mv "$f" .DUP
            print "[DUP] $f @$map[$md5]"
            continue
        }
        map[$md5]=$f
    done
}

function djvu2pdf() {
    local target=$1
    [[ -f $target ]] || exit 1

    local out
    out=${target/.djvu/.pdf}
    ddjvu -format=pdf -verbose "$target" "$out"
}
#---------------------------------------------------------------[ docker ]
function docker.gc() {
    docker system prune
}

function docker.rmi.dangling() {
    docker rmi $(docker images -f "dangling=true" -q)
}

function docker.registry.run() {
    local port=${1:5000}
    docker run -d -p${port}:5000 registry
}

function docker.images() {
    docker images
}

function docker.ps() {
    docker ps $argv
}

function docker.rm-contianer() {
    docker stop $1
    docker rm $1
}

function docker.containers.ids() {
    docker ps -a -q
}

function docker.cotainers.stopall() {
    local -a all
    all=($(docker ps -a -q))
    docker stop $all
}

function docker.cotianers.stopall() {
    local -a all
    all=($(docker ps -a -q))
    docker stop $all
    docker rm $all
}

function docker.stats() {
    docker stats $(docker ps --format={{.Names}})
}

# 登录到容器并
function docker.shell() {
    docker exec -ti $1 /bin/bash
}

function docker.ui() {
    docker run --net host --name kitematic \                                                                                                                                                                  ~:[130]
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY=$DISPLAY \
        -v $HOME/.Xauthority:/root/.Xauthority \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -v /var/run/docker.sock:/var/run/docker.sock \
        --privileged=true -t jonadev95/kitematic-docker
}

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

function ip.lan() {
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
String mapToJSON() {
    local map=$1
    print $map
}

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
function gogrep()   { print -l **/*.go   | xargs  grep --color -n "$*" } 
function pygrep()   { print -l **/*.py   | xargs  grep --color -n "$*" }
function jsgrep()   { print -l **/*.js   | xargs  grep --color -n "$*" }
function allgrep()  { print -l **/*      | xargs  grep --color -n "$*" }

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

# 水仙花数
function narcissistic_numbers() {
    for ((x=1; x<999999; ++x)); do
        n=0
        for i in {1..$#x}; do
            ((n+=$x[i]**$#x))
        done
        (( x == n )) && print $x
    done
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


# $1: string id
# $2: string file name
function android.strings.get() {
    local _strings_key=$1
    local _strings_xml=$2

    xmlstarlet sel -t -c "/resources/string[@name='$_strings_key']/node()" $_strings_xml
}

#---------------------------------------------------------------[ 加密货币 ]
BLOCK_INFO_API='https://blockchain.info/q'
function btc.getdifficulty() {
    curl $BLOCK_INFO_API/getdifficulty
}

function btc.getblockcount() {
    curl $BLOCK_INFO_API/getblockcount
}

function btc.latesthash() {
    curl $BLOCK_INFO_API/getblockcount
}

function btc.latesthash() {
    curl $BLOCK_INFO_API/latesthash
}

function btc.blockReword() {
    curl $BLOCK_INFO_API/bcperblock
}

# 总共有多少比特币
function btc.total() {
    curl $BLOCK_INFO_API/totalbc
}

# 计算出一个区块的概率
function btc.probability() {
    curl $BLOCK_INFO_API/probability
}

# hashestowin - Average number of hash attempts needed to solve a block
function btc.hashestowin() {
    curl $BLOCK_INFO_API/hashestowin
}

function ustd.getTx() {
    curl -s -X GET -H "Content-Type: application/x-www-form-urlencoded" "https://api.omniexplorer.info/v1/transaction/tx/${1}" 
}

#nextretarget - Block height of the next difficulty retarget
#avgtxsize - Average transaction size for the past 1000 blocks. Change the number of blocks by passing an integer as the second argument e.g. avgtxsize/2000
#avgtxvalue - Average transaction value (1000 Default)
#interval - average time between blocks in seconds
#eta - estimated time until the next block (in seconds)
#avgtxnumber - 
