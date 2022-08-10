#!/bin/bash

function isGitDir() {
    [[ $# -eq 0 ]] && return 1
}

isGitDir hello
echo $?
