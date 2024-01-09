#!/bin/zsh
OPENAI_BASE="https://api.openai.com"
OPENAI_MODEL="gpt-3.5-turbo"
HTTP_HEADER_JSON="Content-Type: application/json"
HAS_JQ=$(whence jq)

# $1 : url
# $2 : data
function request() {
    local url="$OPENAI_BASE/$1"
    local data=$2

    [[ -z $OPENAI_AUTH ]] && return  1
    curl -sS $url \
    -H "Authorization: Bearer ${OPENAI_AUTH}" \
    -H $HTTP_HEADER_JSON                      \
    -d "$2"
}

function json.select() {
    local json=$(<&0)
    # no jq installed
    [[ -z $HAS_JQ ]] && print $json

    local m=${1:=.}
    <<< $json | jq -r $m
}

function openai.models() {
    request 
}

function openai.chat() {(
    json='{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "$*"}],
    "temperature": 0.7
}'    
    request v1/chat/completions "${(e)json}" | json.select '.choices[0].message.content'
)}


