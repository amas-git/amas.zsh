
#!/bin/zsh
OKX_API_V5="https://www.okx.com/api/v5"
BNB_API_V3=(
https://api.binance.com
https://api-gcp.binance.com
https://api1.binance.com
https://api2.binance.com
https://api3.binance.com
https://api4.binance.com)
BTR_API_V1=https://openapi.bitrue.com/api/v1

function main() {

}


function okx.get() {
    curl -s $OKX_API_V5/${1} 
}



function bnb.time() {

}



function bnb.get() {
    local url="$bnb_api_v3[1]/api/v3/$1"
    curl -s -g -x get $url
}


function bnb.time() {
    bnb.get time | jq -r ".serverTime"
}

function okx.time() {
    curl -s $OKX_API_V5/public/time | jq -r '.data[0].ts'
}

function btr.get() {
    url="$BTR_API_V1/$1"
    curl -s -g "$url"
}

# $1: market list
# @result: supported market list by bnb
function bnb.spot.market.support() {
    local xs=(ASKUSDT USDTUSDT)
    for x in $argv; do
        [[ -n $xs[(r)$x] ]] && continue
        print $x
    done
}

function bnb.spot.price.usdt() {
    local base=USDT
    symbols=(${^@}${base})
    params=${(j:,:)${(qqq@)${(U)symbols}}}
    bnb.get "ticker/24hr?symbols=[$params]&type=MINI" | jq -r '.[] | [.symbol,.lastPrice,.highPrice,.lowPrice] | @tsv'
}

function bitrue.spot.price.usdt() {
    local base=USDT
    local query 
    [[ -n $argv ]] && {
        query="?symbol=${(U)1}$base"
    }
    resp=$(btr.get "ticker/24hr${query}")
    print $resp | jq -r '.[] | [.symbol,.lastPrice,.highPrice,.lowPrice] | @tsv' 2&> /dev/null
}

function okx.feature.price() {
    local instId=${1:=}
    local quote=${2:=USDT} # USD | USDT | BTC | USDC
    local resp=$(okx.get "market/index-tickers?quoteCcy=${(U)quote}&instId=${(U)instId}")
    print -n $resp | jq -r '.data[] | [.instId,.idxPx,.high24h,.low24h] | @tsv' | column -t
}






main "${(@)argv}"