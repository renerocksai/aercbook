#!/usr/bin/env bash

RELEASE_DIR=aerc-releases
mkdir -p $RELEASE_DIR

function getversion {
    zig run getversion.zig
}

function build {
    target=$1
    mode="$2"

    if [ "$mode" = "" ] ; then
        mode="release-safe"
    fi
    echo "Building $target..."
    rm -f zig-out/bin/aercbook
    rm -f zig-out/bin/aercbook.exe
    zig build -Dtarget=$target -D$mode
    if [ -f zig-out/bin/aercbook ] ; then
        mv zig-out/bin/aercbook $RELEASE_DIR/aercbook-$(getversion)--$target
    else
        mv zig-out/bin/aercbook.exe $RELEASE_DIR/aercbook-$(getversion)--$target.exe
    fi
    echo ""
}

build x86_64-linux
build x86_64-macos
build aarch64-macos
build x86_64-windows
