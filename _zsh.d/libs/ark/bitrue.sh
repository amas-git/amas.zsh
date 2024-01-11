#!/bin/zsh

BITRUE_SPOT_API=https://openapi.bitrue.com


function bitrue() {
    print "
BITRUE API     : ${BITRUE_SPOT_API}
BITRUE_AKEY    : $([[ -n $BITRUE_AKEY ]] && print -n 'true' || print -n 'false')
BITRUE_SKEY    : $([[ -n $BITRUE_SKEY ]] && print -n 'true' || print -n 'false')
OPENSSL        : $(whence openssl)
    "

    curl -s ${BITRUE_SPOT_API}/api/v1/exchangeInfo | jq
}

function bitrue.api.sign() {
    local s=$(print -n ${1} | openssl dgst -sha256 -hmac $BITRUE_SKEY)
    print -n ${s/*= }
}

function bitrue.api.params() {
    typeset -A map
    map=("${(@)argv}")
    map[timestamp]=$(bitrue.time)

    local r
    for k in ${(ko)map}; do
        v=$map[$k]
        r="$r&${k}=${v}"
    done
    r="${r#&}"
    r="${r}&signature=$(bitrue.api.sign $r)"
    print $r
}

function bitrue.api.ping() {
    curl -s ${BITRUE_SPOT_API}/api/v1/ping
}

function bitrue.time {
    curl -s ${BITRUE_SPOT_API}/api/v1/time | jq .serverTime
}

function bitrue.api.kline() {

    #curl -s ${BITRUE_SPOT_API}api/v1/market/kline
}

function bitrue.api.ticker() {
    local symbol=${1:=btcusdt}
    curl -s "${BITRUE_SPOT_API}/api/v1/ticker/24hr?symbol=${(U)symbol}" | jq
}

function bitrue.api.price() {
    local symbol=${1:=btcusdt}
    local ammount=${2:=1}
    local r=$(curl -s "${BITRUE_SPOT_API}/api/v1/ticker/price?symbol=${(U)symbol}" | jq -r .price)
    [[ $r == null ]] && print "0" && return 
    expr="x=(${(q)r}*$ammount)/1; if(x<1) print 0; x" 
    <<< $expr | bc -l
}

function bitrue.api.order.open() {
    local symbol=${1:=ftmusdt}
    local params=$(bitrue.api.params recvWindow 5000 symbol ${(U)symbol})
    curl -s \
        -H "X-MBX-APIKEY: $BITRUE_AKEY" \
        -X GET "${BITRUE_SPOT_API}/api/v1/openOrders?${params}" | jq  -M .
}

function bitrue.api.account() {
    local params=$(bitrue.api.params recvWindow 5000)
    local r=$(curl -s \
         -H "X-MBX-APIKEY: $BITRUE_AKEY" \
         -X GET "${BITRUE_SPOT_API}/api/v1/account?${params}" | jq  -M .)
    print $r | jq -r '.balances[] | select(.free != "0" or .locked != "0") | [.asset,.free,.locked,(.free|tonumber) + (.locked|tonumber)] | @tsv' | column -t
}

function bitrue.api.order.list() {
    local symbol=${1:=ftmusdt}
    local limit=${3:=100}
    local days=${2:=60}
    local range=($(date.range $days))


    function query() {
        local startTime=$1
        local endTime=$2
        local params=$(bitrue.api.params recvWindow 5000 symbol ${(U)symbol} startTime $startTime endTime $endTime)
        x='''
{
    "symbol": "ACEUSDT",
    "orderId": "493450483729760256",
    "price": "13.1000000000000000",                 # 价格
    "origQty": "200.0000000000000000",              # 下单量
    "executedQty": "199.8000000000000000",          # 成交数量
    "cummulativeQuoteQty": "2617.3800000000000000", # 成交额
    "status": "FILLED",                             # 状态
    "type": "LIMIT",                                # 单子类型
    "side": "BUY",                                  # 方向
    "time": 1703379302514,
    "updateTime": 1703396228000,
}
    '''
        resp=$(curl -s \
            -H "X-MBX-APIKEY: $BITRUE_AKEY" \
            -X GET "${BITRUE_SPOT_API}/api/v1/allOrders?${params}")
        [[ $resp == *'"data":null'* ]] && return -1
        [[ $resp == "[]" ]] && return 0
        print $resp | jq  -r '.[] | [.orderId,.symbol,.side,.status,.price,.origQty,.executedQty,.cummulativeQuoteQty,(.updateTime|tonumber)-(.time|tonumber)] | @tsv'
    }
    for x in $range; do
        r=(${(s=:=)x})
        query $r[1] $r[2]
    done
}

# $1: the days before now
# $2: steps (default:28 day)
function date.range() {
    let now=$(date +%s)
    let prv=${1:=28}
    let step=29
    let day=$((24*60*60))

    local xs=({$[$now-day*prv]..$now..$[$step*$day]})
    (( $xs[-1] < $now )) && xs+=$now
    let i=0
    for x in $xs[1,-2]; do
        i=$[i+1]
        print $xs[i]001:$xs[i+1]000
    done
}

function bitrue.exchangeInfo() {
    resp=$(curl -s "${BITRUE_SPOT_API}/api/v1/exchangeInfo")
    print $resp | jq .
}