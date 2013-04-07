#!/bin/zsh
alias android.res.layout='echo $(find-android-project-home res/layout)'
alias android.src='echo $(find-android-project-home src)'
alias android.mkclass='mkclass -rf android.src'
# 列出id与类名的对应关系
alias android.xml.listClassById="xmlstarlet sel -t -m \"//*[@android:id!='']\"  -v '@android:id' -o ' ' -c 'name(.)' -o ' '"
alias android.xml.listMenuItemId="xmlstarlet sel -t -m \"//item[@android:id!='']\" -v '@android:id' -o ' '"
alias android.xml.listId="xmlstarlet sel -t -m \"//*[@android:id!='']\" -v '@android:id' -o ' '"
# 生成一个activity需要实体类+AndroidMenimest.xml中添加对应标签
alias android.output.activity='android.mkclass -class $CLASS -body "$*" && mkactivity $CLASS'
alias android.output.class='android.mkclass -class $CLASS -body "$*"'
alias stop-if-not-android-project='[[ -z $(find-android-project-home) ]] && return -1'

android.layout.listViewId() {
    local xml="$1"
    local class=${2:=*}
    if [[ -f $xml ]]; then
    else
        @EF "xml file not found : '$xml'" 
        return -1
    fi
    xmlstarlet sel -t -m "//${class}[@android:id!='']" -v '@android:id' -o ' ' "$xml"
}

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
    local subdir="/$*"
    
    while [[ $dir != / ]]; do
        [[ -f "$dir/AndroidManifest.xml" && -d "$dir/src" && -d "$dir/res" ]] && break
        dir=$(dirname $dir)
    done
    
    [[ $dir == "/" ]] && return -1
    print "$dir$subdir"
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




function android.xml.addStyle() {
    help() {
        print -u2 "cat style.xml | android.xml.addStyle -name <style-name> [-parent <parent-name>] -- attr1=value1 attr2=value2 ... attrN=valueN"
        # print -u2 " -f : 如果style已经存在，则替换之"
    }
    local -A opts
    zparseopts -A opts -K -D -- name:=opts parent:=opts -f:=flags
    local name=$opts[-name]     && [[ -z $name   ]] && return -1
    local parent=$opts[-parent] && [[ -n $parent ]] && parent="parent=$parent"
    local xpathGuard="/resources/style[@name='$name']"
    local xml                   
    xml=$(<&0)                  && [[ -z $xml    ]] && return 0

    if [[ $(echo $xml | xpath.matched $xpathGuard) == true ]]; then
        @DF "remove: $xpathGuard"
        xml=$(echo $xml | deleteElement "$xpathGuard")
        # @DF "$xml"
        # return 0
    fi

    # safe add style element
    xml=$(echo "$xml" | newElement /resources -name style "name=$name" $parent)

    # add style/item element
    local pair
    for item in $argv; do
        pair=(${(s:=:)item})
        xml=$(echo "$xml" | newElement $xpathGuard -name item -value "$pair[2]" -- "name=$pair[1]")
    done
    echo $xml
}

function android.xml.addReceiver() {
    local name="$1"; shift
    newElement /manifest/application -name receiver "android:name=$name" $*
}

function android.xml.addService() {
    local name="$1"; shift
    newElement /manifest/application -name service "android:name=$name" $*
}

function android.xml.addString() {
    local name="$1" 
    local text="$2"
    shift;shift
    newElement /resources -name string -value "$text" "name=$name" $*
}

function android.xml.addIntentFilter() {
    help() {
        print """\
Add intent-filter to specify android component.
$ cat AndroidManifest.xml | android.xml.addIntentFilter <component-name>  -a android.intent.action.MAIN -c android.intent.category.LAUNCHER -d 'android:mimeType=text/*'
optons: 
    -a: action-name
    -c: category-name
    -d: data 'attr1=value1 attr2=value2 ... attr3=value3'
        attr should be one of:
        - android:mimeType
        - android:host
        - android:scheme
        - android:port
        - android:path
        - android:pathPrefix
        - android:pathPattern
    -D: as main entrance of application. (equivalent '-a android.intent.action.MAIN  -c android.intent.category.LAUNCHER')
    -h: show this help
"""
    }

    local -a opts actions categorys dataspecs
    [[ -z $argv || $argv = '-h' ]] && help && return
    local componentName="$1"; shift
    local target="/manifest/application/*[(local-name()='activity' or local-name()='receiver') and (@android:name='$componentName')]"
    local targetIntentFilter manifest elemId

    zparseopts -K -- a+:=actions c+:=categorys d+:=dataspecs h=opts D=opts 
    [[ -n $opts[(r)-h] ]] && help && return

    @IF "actions  : $actions"
    @IF "categorys: $categorys"
    @IF "dataspecs: $dataspecs"
    @IF "opts     : $opts"

    elemId=$(uuid)
    targetIntentFilter="//intent-filter[@_id='$elemId']"
    # +element: intent-filter
    manifest=$(newElement "$target" -name intent-filter _id=$elemId)
    
    # handle single options
    [[ -n $opts[(r)-D] ]] && actions+=(-a "android.intent.action.MAIN") && categorys+=(-c "android.intent.category.LAUNCHER")
    
    # +element: action
    for x in ${(u)actions}; do
        [[ $x = "-a" ]] && continue
        manifest=$(echo "$manifest" | newElement "$targetIntentFilter" -name action android:name="$x")
    done

    # +element: category
    for x in ${(u)categorys}; do
        [[ $x = "-c" ]] && continue
        manifest=$(echo "$manifest" | newElement "$targetIntentFilter" -name category android:name="$x")
    done

    # +element: data
    # FIXME(amas): for data spec, the same attributes with different order may case output duplicate attributes
    for x in ${(u)dataspecs}; do
        [[ $x = "-d" ]] && continue
        manifest=$(echo "$manifest" | newElement "$targetIntentFilter" -name data ${=x})
    done
    <<< "$manifest" | xml ed -d "//@_id"
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

function android.menu() {
    help() {
        print """\
$ android.menu -n help -t 帮助 -n search 
OPTIONS:
    -m : menu id
    -i : menu icon
    -t : menu title
    -I : same with '-a ifRoom'   but take effect all menu items
    -N : same with '-a never'    but take effect all menu items
    -W : same with '-a withText' but take effect all menu items
    -A : same with '-a always'   but take effect all menu items
    -a : menu show as action, can override  option '-A|-N|w|I'
       - ifRoom
       - always
       - withText
       - never 
       - collapseActionView
    -p : prefix of menu id
    -o <file> : save menu to file
    -O <id>   : save menu to 'res/menu/${id}.xml'
"""
    }
    local -a opts menus action
    zparseopts -K -- m+:=menus i+:=menus t+:=menus a+:=menus h=opts A=opts W=opts N=opts I=opts
    if [[ $? != 0 ]] || [[ -n $opts[(r)-h] ]]; then
        help
        return -1
    fi

    local root='<?xml version="1.0" encoding="utf-8"?>
<menu xmlns:android="http://schemas.android.com/apk/res/android">
</menu>
'
    local icon title a etc x id

    [[ -n $opts[(r)-A] ]] && action+=always
    [[ -n $opts[(r)-N] ]] && action+=never
    [[ -n $opts[(r)-W] ]] && action+=withText
    [[ -n $opts[(r)-I] ]] && action+=ifRoom
    
    [[ -n $action ]] && etc+="android:showAsAction=${(j:|:)action}"

    local -i i
    for ((i=1; i<=$#menus; ++i )); do
        x=$menus[i]
        if [[ "$x" -eq "-m" ]]; then
            id="$menus[i+1]"
            root=$(echo "$root" | newElement  /menu -name item android:id="@+id/$id" android:title="$id" $etc)
        elif [[ $x -eq "-t" ]]; then
            title="$menus[i+1]"
            root=$(echo "$root" | updateElement "/menu/item[@android:id='$id']" android:title="$title")
        elif [[ $x -eq "-a" ]]; then
            a="$menus[i+1]"
            root=$(echo "$root" | updateElement "/menu/item[@android:id='$id']" android:showAsAction="$a")
        elif [[ $x -eq "-i" ]]; then
            # TODO: generate icon resource
        fi
        (( i++ ))
    done

    print "$root"
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

function android.component() {
    help() {
        print -u2 """\
$ android.component mk [-a|-r|-s|-p] <component-name> attr1=value1 attr=value2
$ android.component rm <component-name>
$ android.component ls [-a|-r|-s|-p] [-v]

OPTIONS:
   -a : activity
   -r : receiver
   -s : service
   -p : provider
"""
    }
    
    
    local manifest component_type name
    local -a opts CMDS
    CMDS=(mk rm ls)

    function android.component.ls() {
        xml sel -t -m manifest/application/${component_type} -v @android:name -o ' ' $manifest
    }
    
    function android.component.mk() {
        # Component name
        [[ -z $argv ]] && return -1
        local name=$1 && shift

        # TODO: avoid duplicated component
        <<< $(<$manifest) | newElement /manifest/application -name $component_type "android:name=$name" $*
    }

    function android.component.rm() {
    
    }
    

    # dispatcher
    [[ -z $argv             ]] && help && return
    local subcmd="$1"; shift
    [[ -z $CMDS[(r)$subcmd] ]] && help && return

    # AndroidManifest.xml
    manifest=$(project home AndroidManifest.xml)
    zparseopts -D -K -- a=opts r=opts s=opts p=opts v=opts

    # Component type
    if   [[ -n $opts[(r)-a] ]]; then
        component_type=activity
    elif [[ -n $opts[(r)-r] ]]; then
        component_type=receiver
    elif [[ -n $opts[(r)-s] ]]; then
        component_type=service
    elif [[ -n $opts[(r)-p] ]]; then
        component_type=provider
    else
        component_type='*'
    fi
    
    android.component.$subcmd $name $*
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

function android.class() {
    local class=${1:=$CLASS}
    local package=$(android.package)
    
    # full class name
    [[ $class[1] == '.' ]] && class=${package}${class}
    <<< $(project home src/${${class#.}//.//}.java)
}

function android.XML() {
    local id=${1:=unknown}
    <<< $(project home res/xml/${id}.xml)
}

function android.layout() {
    local id=${1:=unknown}
    echo $(project home res/layout/${id}.xml)
}

function android.fullclass() {
    local class=$1
    local package=$(android.package)
    if [[ "$class[1]" == "." ]]; then
        echo $package$class
    else
        echo $class
    fi    
}

function +android() {
    M=
    R=
    P=
    LAYOUT=
    PROJECT_HOME=
    isAndroidProject || return
    PROJECT_HOME=$(project home)
    LAYOUT=${PROJECT_HOME}res/layout/
    P=$(android.package)
    R=${P}.R
    M=${PROJECT_HOME}AndroidManifest.xml
}
