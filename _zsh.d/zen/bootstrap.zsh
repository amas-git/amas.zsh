#!/usr/bin/env zsh

ZEN_PATH=${ZDOTDIR:-$HOME}/.zen
REPOSITORY_URL=http://svn.asyd.net/svn/zsh/tags/zen/0.2

local buffer

# --- functions
function wcat () {
   # exemple usage: wcat http://example.com/foo/
   local tcp_lines
   http_get ${${1#http://}%%/*} /${${1#http://}#*/}
   tcp_lines=(${tcp_lines#*] })
   if [ -z "${tcp_lines[1]//* 200 OK*}" ]; then
      print -r ${${(F)tcp_lines}#*$(echo "\r\n\r")?}
   else
      return 1
   fi
}

function http_get {
	autoload -U tcp_open
	TCP_SILENT=1
	url_encode $2	
	tcp_open -q $1 80 $1 || return 2
	tcp_send -s $1 -- "GET ${http_url_encoded} HTTP/1.1"
	tcp_send -s $1 -- "Host: $1"
	tcp_send -s $1 -- "Accept-Charset: utf-8"
	tcp_send -s $1 -- ""
	OLDIFS=$IFS
	IFS=''
	tcp_read -b -d -s $1
	IFS=$OLDIFS
	tcp_close -q $1
}

function url_encode {
	input=(${(s::)1})
	http_url_encoded=${(j::)input/(#b)([^A-Za-z0-9_.!~*\'\(\)-])/%${(l:2::0:)$(([##16]#match))}}
}

# --- code
set -e

# check if $ZEN_PATH already exists
if [[ -r $ZEN_PATH ]] ; then
	echo "WARN: $ZEN_PATH already exists, do you want to delete it and reinstall?"
	echo "WARN: If you choose yes, $ZEN_PATH wil be DELETE!"
	echo -n "[y/n]: "
	read -q answer
	if [[ $answer == "y" ]] ; then
		rm -fr $ZEN_PATH
	else
		exit 1
	fi
	
fi

echo "INF: ZEN will use $ZEN_PATH as repository"

mkdir -p $ZEN_PATH/{zsh/{scripts/http,zle},data,config}

echo "zen $REPOSITORY_URL" > $ZEN_PATH/config/repositories
# Fetch required files
#for i in data/{catalog,depends}
#do
#	echo "INF: Downloading $i"	
#	wcat $REPOSITORY_URL/$i > $ZEN_PATH/$i
#done

for i in zsh/scripts/{http/{urlencode,get,cat},zen}
do
	echo "INF: Downloading $i"	
	wcat $REPOSITORY_URL/$i > $ZEN_PATH/$i
	buffer=${${(s: :)${(M)${(f)"$(< $ZEN_PATH/$i)"}:#\#[[:space:]]Version:[[:space:]]*}}[3]}
	printf "%s,%s\n" $i $buffer >> $ZEN_PATH/data/installed
done

echo "INF: Bootstrap done"
echo 
echo "INF: Add the following code in your zsh configuration:"
echo "fpath=("
echo "\t\$fpath"
echo "\t$ZEN_PATH/zsh/scripts"
echo "\t$ZEN_PATH/zsh/zle )"
echo "autoload -U zen"
echo "zen update"
echo
echo "INF: Example:"
echo "% zen search"
echo "% zen install zsh/scripts/zpaste"

