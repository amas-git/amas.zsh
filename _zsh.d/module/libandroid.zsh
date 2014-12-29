#!/bin/zsh
alias android.src='echo $(find-android-project-home src)'



android.output.drawableXml() {
    local -L fname="$1"
    local drawable="$(find-android-project-home res/drawable/$fname)"
    if [[ -n $drawable ]]; then
        [[ -d $(dirname $drawable) ]] || mkdir $(dirname $drawable)
    fi

    echo "$2 "| basewriter "$drawable"
}


function isAndroidProject() {
    # This is tricky code
    [[ -z $(find-android-project-home) ]] && return -1 || return 0
}
#------------------------------------------------------------------------[ ZCG Require Functions ]
alias require-android-class=require-activity
function require-activity() {
    require CLASS -c  "${1:=请输入类名,短名可使用.x.y.Name}"
    local package=$(android.manifest.getPackageName)
    
    if [[ $CLASS != ${package}.* && $CLASS[1] == . ]]; then
        CLASS=${package//\//.}.${CLASS#.}
    fi
    
    
    CLASSNAME=$(java-classname $CLASS)
    PACKAGE=$(java-package-name $CLASS)
    @DF "CLASS='$CLASS' | PACKAGE='$PACKAGE' | CLASSNAME='$CLASSNAME'"
}

#------------------------------------------------------------------------[ Android Project Functions ]
# backward search to find android project home
find-android-project-home() {
    local dir=$(pwd)

    local manifest=$(echo */**/main/AndroidManifest.xml)

    [[ -n $manifest ]] && print $dir/$manifest
}

#------------------------------------------------------------------------[ XmlHelper Functions ]
# 1. 处理XML相关的操作，如增/删/改/查等等
# 2. 所有函数必须按照如下规则书写
#   * 不能直接处理xml文件, 只能通过pipe处理保存在变量里的xml或者管道传输过来的xml
#   * 函数之间可以使用管道串联
#   * 比如: cat string.xml | android.xml.newActivity n1 v1 | android.xml.newActivity n2 v2 可以连续追加两个string元素
function android.xml.addActivity() {
    local name="$1"; shift
    newElement /manifest/application -name activity "android:name=$name" $*
}

function android.xml.addReceiver() {
    local name="$1"; shift
    newElement /manifest/application -name receiver "android:name=$name" $*
}

function android.xml.addService() {
    local name="$1"; shift
    newElement /manifest/application -name service "android:name=$name" $*
}


function android.xml.addPermission() {
    local name="$1"
    newElement /manifest -name uses-permission android:name=$name
}

function android.xml.addMeta() {
    local name="$1"; shift
    newElement /manifest/application -name meta-data android:name=$name $*
}

# O_o! : pipe is slow...
function android.xml.addPermissions() {
    local xml
    xml="$(<&0)" && [[ -z $xml ]] && return 0
    for x in $argv; do
        xml=$(echo "$xml" | newElement /manifest -name uses-permission -guard "/manifest/uses-permission[@android:name='$x']"  android:name=$x)
    done
    echo $xml
}

function android.xml.addStringArray() {
    local xml=
    local name="$1";shift
    [[ -z $name ]] && logf "name can not be empty!"
    xml=$(<&0) && [[ -z $xml ]] && logf "create string-array failed, input xml is empty." && return 0
    xml=$(echo $xml | newElement /resources -name string-array name=$name)
    
    for x in $argv; do
        xml=$(echo "$xml" | newElement "/resources/string-array[@name='$name']" -name item -value "$x")
    done
    echo $xml
}

function android.xml.addMenuItem() {
    local xml
    local id="$1";shift
    xml=$(<&0) && [[ -z $xml ]] && @DF "add menu item failed, input xml is empty." && return 0
    echo "$xml" | newElement "/menu" -name item android:id="@+id/${(L)id}" $*
}

function android.xml.getIds() {
    echo "$(<&0)" | xml sel -t -m "//*[@android:id!='']" -v @android:id -o ' '
}


function android.package() {
    android.manifest.getAttribute package
}



function _manifest.getAttribute() {
    local xpath="$1"
    local attr_name="$2"
    local manifest="$(find-android-project-home AndroidManifest.xml)"
    [[ -z $manifest ]] && return -1

    xml.getAttribute "$xpath" "$attr_name" "$manifest"
}

function android.manifest.getAttribute() {
    local attr_name="$1"
    _manifest.getAttribute "/manifest" $attr_name
}

function android.manifest.application.getAttribute() {
    local attr_name="$1"
    _manifest.getAttribute "/manifest/application" $attr_name
}



#------------------------------------------------------------------------[ ZCG TextNode Functions ]
# TextNode函数的概念: 返回值嵌入到模板中的函数，TextNode函数可以有副作用，比如: 建立一个文件
# 调用另一个模板文件等等

# -> R
function importR() {
    R=$(android.package) && [[ -n $R ]] && R+=.R && print "import $R;"
}


alias mkstyle.writer=basewriter
function mkstyle() {
    local -A opts
    zparseopts -A opts -K -D -- name:=opts parent:=opts o:=opts -f:=flags
    local name=$opts[-name]     &&  [[ -z $name   ]] && return -1
    local parent=$opts[-parent]
    local out=${opts[-o]:=$(find-android-project-home res/values/styles.xml)}
    [[ -f $out  ]] || (echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > "$out")
    local xml=
    xml="$(<$out)" && [[ -z $xml ]] && @DF "xml is null" && return -1
    xml=$(print "$xml" | android.xml.addStyle -name $name -parent "$parent" $*)
    print "$xml" | mkstyle.writer "$out"
    print "$name"
}


alias mkpreference.writer=basewriter
function mkpreference() {
    parse_options() {
        zparseopts -A opts -K -D -- gf:=opts id:=opts body:=opts
    }
    parse_options $*
    
    local id=$opts[-id]
    local srcroot="$(find-android-project-home res/xml)"
    local body="$opts[-body]"
 
    if [[ -n $srcroot ]]; then
        [[ -d $srcroot ]] || mkdir "$srcroot"
        out="$srcroot/$id.xml"
    else
        out=$id.xml
    fi
    # echo "$body" > "$out" && logd "$id" "$content"
    echo "$body" | mkpreference.writer "$out"
    print $id
}

###
alias mklayout.writer=basewriter
function mklayout() {
    parse_options() {
        zparseopts -A opts -K -D -- rf:=opts gf:=opts id:=opts body:=opts
    }
    parse_options $*
    
    local rf='find-android-project-home res/layout'
    local srcroot="$(eval ${rf})"
    local id=$opts[-id]
    local body="$opts[-body]"

    if [[ -d $srcroot ]]; then
        out=$srcroot/$id.xml
    else
        @E "$id(WARN)" "目录不存在: '$srcroot'" 
        out=$id.xml
    fi
    echo "$body" | mklayout.writer "$out" && @DF "layout/$id.xml" "$body"
    @DF "layout/$id.xml created"
    print $id
}

###
alias mkarray.writer=basewriter
function mkarray() {
    local arrays_xml=$(find-android-project-home res/values/arrays.xml)
    [[ -f $arrays_xml ]] || echo "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n</resources>" > "$arrays_xml"
    local xml=
    xml=$(< $arrays_xml) && [[ -z $xml ]] && logf "input xml is empty." && return

    echo "$xml" | android.xml.addStringArray $* | mkarray.writer "$arrays_xml" && logf "strings-array[name=$1] added to '$arrays_xml'"
    print "$1"
}

###
alias mkpermissions.writer=basewriter
function mkpermissions() {
    local manifest="$(find-android-project-home AndroidManifest.xml)";
    echo "$(< $manifest)" | android.xml.addPermissions $* | mkpermissions.writer "$manifest"
    print -l $*
}

alias mkmeta.writer=basewriter
function mkmeta() {
    local manifest="$(find-android-project-home AndroidManifest.xml)";
    local package=$(android.package)
    local name="$1"; shift
    local xml=
    xml=$(< $manifest)

    echo "$xml" | xpath.matched.refuse "/manifest/application/meta-data[@android:name='$name']" | android.xml.addMeta "$name" $* | basewriter "$manifest"
    echo "$name"
}

### 
alias mkactivity.writer=basewriter
function mkactivity() { 
    help() {
        echo "$mkactivity .ui.TestActivity"
    }
    local manifest="$(find-android-project-home AndroidManifest.xml)";
    local package=$(android.package)
    local className="$1"; shift
    local xml=
    xml=$(< $manifest)

    help() {
        echo " 在AndroidMandifest中添加Activity标签"
        echo " $(basename $0) org.amas.ui.MainActivity android:enabled=false android:theme=xxx"
        echo " TODO: implement -file options"
    }
    
    if [[ -z $(echo "$xml" | xpath.matched.refuse "/manifest/application/activity[@android:name='$className']") ]]; then
        @IF "Activity: '$className' existed, changed nothing"
        return -1
    else 
        echo "$xml" | android.xml.addActivity "$className" $* | mkactivity.writer "$manifest"
        @IF "Activity: '$className' added to '$manifest'"
    fi
    print $className
}


###
alias mkstring.writer=basewriter
function mkstring() {
    local name="$1"
    local text="$2"
    local strings_xml=$(find-android-project-home res/values/strings.xml)
    if [[ -f "$strings_xml" ]]; then
    else 
        echo $name
        return -1
    fi

    xml=$(< "$strings_xml")

    [[ -z $xml ]] && return -1
    xml=$(echo "$xml" | xpath.matched.refuse "/resources/string[@name='$name']" | android.xml.addString "$name" "$text"  2> /dev/null)

    if (( $? == 0 )); then
        if [[ -n $xml ]]; then
            echo "$xml" | mkstring.writer "$strings_xml"
        else
            @IF "element existed"
        fi
    else
        @EF "add string failed (error code: $?)"
    fi
    echo $name
}


function addStaticLib() {
    local jar="$1"
    local libs=$(find-android-project-home libs)
    [[ -z $libs ]] && return -1
    [[ -d $libs ]] || mkdir $libs
    [[ -d $libs ]] && cp "$1" "$libs" && return
}

alias mkreceiver.writer=basewriter
function mkreceiver() {
    local manifest="$(find-android-project-home AndroidManifest.xml)";
    local package=$(android.package)
    local className="$1"; shift
    local xml=
    xml=$(< $manifest)

    print $className
    if [[ -z $(echo "$xml" | xpath.matched.refuse "/manifest/application/receiver[@android:name='$className']") ]]; then
        @IF "Receiver: '$className' existed, changed nothing"
        #echo "$xml" | Android.xml.updateActivity "$className" $* | mkactivity.writer "$manifest"
        
        return -1
    else 
        echo "$xml" | android.xml.addReceiver "$className" $* | mkreceiver.writer "$manifest"
        @IF "Receiver: '$className' added to '$manifest'"
    fi
}


# 空参数请加上占位符:-
# Spec是三元组
# (parentXPath ElementName ElmentAttribute)
# ElementAttribute=AttrebuteName=AttrbiteValue,...
function createXmlBySpec() {
    local matchPath=
    local xml="$(<&0)"
    help() {
        echo "createXmlBySpec xmlSpec"
    }
    (( $# % 3 != 0 )) && @EF "Spec不完整"
    #or xpath in ${(on)argv}; do
    for (( i=1; i<=${#argv}; i+=3)) do
        matchPath=$argv[i] 
        element=$argv[i+1]
        attrs=$argv[i+2]
        @IF "Create Element '$element' in '$matchPath'"
        xml=$(echo "$xml" | newElement "$matchPath" -name "${element}" ${=attrs})
    done

    echo $xml
}

function android.addDrawbleXml() {
    local content="$1"
    local id="$2"
    [[ -z $id ]] && return -1
    android.addFile "$content" "res/drawable/$id.xml"
    print $id
}

function android.addFile() {
    local content="$1"
    local target=$(find-android-project-home "$2")
    # @IF "add file '$target'"
    # @DF "$content"
    echo "$1" | basewriter $target
}

argtest() {
    echo "数量=$#"
}


function android.hasCompontent() {
    help() {
        print """\
$ android.hasCompontent [-f AndroidMenifest.xml]
"""
    }

    local name="$1"
    local -a opts file
    zparseopts -K -- h=opts f:=file
    
    xpath.matched 
}


function project() {
    help() {
        print -u2  """\
$ project home
"""
    }
    
    function project.home() {
        local dir=$(pwd)
        local subdir="/$*"
        while [[ $dir != / ]]; do
            [[ -f "$dir/AndroidManifest.xml" && -d "$dir/src" && -d "$dir/res" ]] && break
            dir=$(dirname $dir)
        done
        [[ $dir == "/" ]] && return -1
        echo "$dir$subdir"
    }

    [[ -z $argv ]] && help && return
    local subcmd="$1"; shift
    # TODO(amas): validate subcommand
    project.$subcmd $*
}



function android.XML() {
    local id=${1:=unknown}
    <<< $(project home res/xml/${id}.xml)
}

function android.layout() {
    local id=${1:=unknown}
    echo $(project home res/layout/${id}.xml)
}


function android.project.home() {
    local dir=$(pwd)
    [[ -f AndroidManifest.xml ]] && {
        print $dir
        return
    }

    
    local manifest=$(echo */**/main/AndroidManifest.xml)
    [[ -n $manifest ]] && print $dir/$manifest
}

function +android() {
    help() {
        print -u2 "
在android工程目录下执行此命令，将引入一些常用的变量，包括:
 * M : AndroidManifest.xml文件的路径('$M')
 * P : 应用的包名('$P')
 * R : R的完整类名('$R')
 * PROJECT_HOME: 工程路径('$PROJECT_HOME')
 * LAYOUT: layout文件目录('$LAYOUT')
"
    }
    
    M=
    R=
    P=
    LAYOUT=
    PROJECT_HOME=$(android.project.home)
    [[ -z $PROJECT_HOME ]] && return

    LAYOUT=${PROJECT_HOME}res/layout/
    P=$(android.package)
    R=${P}.R
    M=${PROJECT_HOME}AndroidManifest.xml

    help
}
