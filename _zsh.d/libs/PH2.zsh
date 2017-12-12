#!/bin/zsh
TEMPLATE='
Hello $WORLD!
$((18*21))
'

WORLD=1
print ${(e)TEMPLATE}
