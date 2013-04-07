#

function has() {

}

function trim() {
    local text="$*"
    echo ${text##' '}
}
