#!/bin/zsh




function createFile() {
    local p=${1:=unknown.dat}.dat
    local size=${2:=1}

    local parent=$(dirname $p)
    echo "careate : $p"
    [[ -d $parent ]] || mkdir -p $parent
    # default file size = bs * seek = 1024 x 1 = 1kB
    # 1M   : size=1024
    # 10M  : size=1024*10
    # ...
    dd if=/dev/zero of=${p} bs=1024 count=0 seek=$size 2> /dev/null
}


# $1 : 深度
# $2 : 建立文件大小
# $3 : 建立多少个顶级目录
function create() {
    depth=${1:=10}
    size=${2:=1024}
    count=${3:=10}
    child=({01..$depth})
    for x in dir{001..$count}; do
        p="$x/${(j:/:)child}"
        createFile "$p" $size
    done

}

main() {
    (  
        root=test
        [[ -d $root ]] && rm -rf $root
        [[ -d $root ]] || mkdir $root
        cd $root
        create 3 1024 10
    )
}

main $*
