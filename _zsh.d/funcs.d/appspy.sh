#!/bin/zsh


PKG_LIST='/data/system/packages.list'
PKG_XML='/data/system/packages.xml'

db="$(adb shell su -c 'cat /data/system/packages.xml')"
packages=()
packages=($(echo "$db" | xml sel -t -m 'packages/package' -v '@name' -o ' '))


function getprop.ro.product.name {
    adb shell getprop ro.product.name
}
# echo "
# PACKAGES:
# * NUMBER=$#packages
# * NAMES:
# ${(F)packages}
# " 

typeset -A certref

dot=("digraph G {" "node[shape=box];" "rankdir=LR");

for x in $packages; do
    # echo "$db" | xml sel -t -m "packages/package[@name='$x']" -v '@flags' -o ' ' -v '@codePath' -o ' ' -v '@version' -o ' ' -v '@userId'

    cert=$(echo "$db" | xml sel -t -m "packages/package[@name='$x']/sigs/cert" -v '@key')
    if [[ -z $cert ]]; then
        cert="-"  
    else
        cert=$(echo $cert | md5sum | awk '{ print $1 }')
    fi

    if [[ -z $certref[$cert] ]]; then
        certref[$cert]=1
    else
        certref[$cert]=$(( $certref[$cert] + 1 ))
    fi
    echo "$x $cert" 
    # dot+="\"$x\"->\"$cert\";"
done
dot+="}"

print -l $dot > g.dot

for x in ${(k)certref}; do
    echo $x=$certref[$x]
done
