
ARK_HOME=~/.ark
source ./bitrue.sh
source ./price.sh

function ark.account() {

}

function ark.account.list() {
    local account=$1

}

function ark.list() {
    local config=($(print $ARK_HOME/**/*))

    for c in $config; do
        name=(${(s:.:)c:t})
        id=$name[1]
        res=$name[2] 
        print $res $id
    done
}

typeset -A ARK_PRICE_SPOT_BITRUE
typeset -A ARK_ACCOUNT_BITRUE
typeset -U ARK_ACCOUNT_BITRUE_IDX

ARK_ACCOUNT_BITRUE_IDX=(FTM ALGO ACE)

function ark.state.reset() {
    ARK_ACCOUNT_BITRUE=()
    ARK_ACCOUNT_BITRUE_IDX=()
    ARK_PRICE_SPOT_BITRUE=()
}

function ark.sync() {
    ark.price.sync
    # update price
    local time=$(bitrue.time)
    local bitrue=("${(@f)$(bitrue.spot.price.usdt)}")
    for p in $bitrue; do
        xs=(${=p})
        # last | high | low
        ark.state.price_put $xs[1] $xs[2] $xs[3] 
    done

    # update account
    ark.bitrue.account
}

function ark.state.price_put() {
    local id=$1
    local last=$2
    local high=$3
    local low=$4
    ARK_PRICE_SPOT_BITRUE[$id]=$last
}

# $1 : market or id
# $2 : total
# $3 : free
# $4 : lock
function ark.state.account_put() {
    local id=$1
    local total=$2
    local lock=$3
    local free=$4
    ARK_ACCOUNT_BITRUE[$id]=$total
}

# $1: id (BTC ftm)
function ark.state.account_get() {
    local id=$1
    local xs=$ARK_ACCOUNT_BITRUE[${(U)id}]
    print -n $xs
}

function ark.state.price_get() {
    local id=$1
    [[ $id == USDT ]] && print -n 1
    print -n $ARK_PRICE_SPOT_BITRUE[${(U)id}USDT]
}

function ark.bitrue.account() {
    local assets=("${(f@)$(bitrue.api.account)}")
    local sum=()
    local ulock ufree
    # market | locked | free | total
    for x in $assets; do
        xs=(${=x})
        id=$xs[1]
        price=$(ark.state.price_get $id)
        [[ -z $price ]] && price=0
        sum+="$price*$xs[4]"
        ark.state.account_put $id $xs[4] $xs[3] $xs[2]
        [[ $id == USDT ]] && {
            ulock=$xs[3]
            ufree=$xs[2]
        }
    done

    #print -l $sum
    local SUM=$(print -n "scale=2; (${(j:+:)sum})" | bc -l)
    print "total:$SUM free:$ufree lock:$ulock"
}

function ark.main() {
    # ark.sync
    bitrue.api.order.list ftmusdt 30 | ark.calc
    ark.head ftm
}

function ark.head() {
    local idx=(${1})
    for id in $idx; do
        v=$(ark.state.account_get $id)
        print $id $v $(bitrue.api.price ${id}USDT $v)
    done
}

function SUM() {
    print -n "${(j:+:)argv}" | bc -l
}

function SUMU() {
    print -n "scale=2;(${(j:+:)argv})/1" | bc -l
}

function ark.calc() {
    local order="$(<&0)"
    local bu=()
    local bv=()
    local su=()
    local sv=()

    function on_BUY_FILLED() {
        local v=$argv[7]
        local u=$argv[8]
        bu+=$u
        bv+=$v
    }

    function on_SELL_FILLED() {
        local v=$argv[7]
        local u=$argv[8]
        su+=$u
        sv+=$v
    }

    function on_SELL_NEW() {

    }

    function on_SELL_CANCELED() {

    }

    for x in "${(@f)order}"; do
        xs=(${=x})
        side=$xs[3]
        stat=$xs[4]
        on_${side}_${stat} $xs
    done
    print "SELL : $(SUMU $su) $(SUM $sv)"
    print "BUY  : $(SUMU $bu) $(SUM $bv)"
}