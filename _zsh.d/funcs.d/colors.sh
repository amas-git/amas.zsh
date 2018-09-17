#!/bin/zsh
for ((i=1; i<255; i++)); do
    print -n "\e[38;5;${i}m${i}"
done
