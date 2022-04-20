#!/bin/bash


function msg {
    printf "%s\n" "$*" >&2 
}

function msg_prefix {
    local _prefix="$1"
    shift 1
    msg "$_prefix:$*"
}

function msg_error {
    msg_prefix "error" "$*"
}

function msg_warning {
    msg_prefix "warning" "$*"
}

function msg_info {
    msg_prefix "info" "$*"
}

function msg_debug {
    msg_prefix "debug" "$*"
}

function error {
    msg_error "$*"
    exit 1
}


function print_arch {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        "x86_64" | "amd64" )
            printf "x86_64\n"
            ;;
        "aarch64" | "arm64" )
            printf "aarch64\n"
            ;;
        * )
            error "arch='$arch' not supported"
            ;;
    esac
}

