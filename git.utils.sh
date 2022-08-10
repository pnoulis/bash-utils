#!/bin/bash
# Author: Pavlos Noulis
# Start Date: <2022-08-10 Wed>

function isGitDir() {
    # input validation
    ## 1. one parameter has been provided
    [[ $# -eq 0 ]] && {
        echo isGitDir: Wrong number of arguments
        exit 1
    }

    ## 2. that paremeter is not an empty string
    [ -z "$1" ] && {
        echo isGitDir: Null string
        exit 1
    }

    # make sure:
    ## 1. is a path
    ## 2. all nodes exist
    ## 3. expand path
    {
        local tpath=$(realpath -qe "$1")
    } || {
        echo isGitDir: "$1": No such file or directory
        exit 1
    }

    # check cwd is a git repo
    pushd "$tpath" > /dev/null
    {
        git status >& /dev/null
    } || {
        echo isGitDir: "$tpath": Not a git repository
        exit 1
    }
    popd > /dev/null
    return 0
}

function isGitClean() {
    # input validation
    ## 1. one parameter has been provided
    [[ $# -eq 0 ]] && {
        echo isGitClean: Wrong number of arguments
        exit 1
    }

    ## 2. that paremeter is not an empty string
    [ -z "$1" ] && {
        echo isGitClean: Null string
        exit 1
    }

    # make sure:
    ## 1. is a path
    ## 2. all nodes exist
    ## 3. expand path
    {
        local tpath=$(realpath -qe "$1")
    } || {
        echo isGitClean: "$1": No such file or directory
        exit 1
    }


    # check
    pushd "$tpath" > /dev/null
    ## 1. provided argument is a path repository
    {
        git status >& /dev/null
    } || {
        echo isGitClean: "$tpath": Not a git repository
        exit 1
    }
    ## 2. working directory is clean
    [ -n "$(git status --porcelain)" ] && {
        echo isGitClean: "$tpath": working directory is dirty
        exit 1
    }
    popd > /dev/null

    return 0
}
