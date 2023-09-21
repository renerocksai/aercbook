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
        mode="ReleaseSafe"
    fi
    echo "Building $target..."
    rm -f zig-out/bin/aercbook
    rm -f zig-out/bin/aercbook.exe
    zig build -Dtarget=$target -Doptimize=$mode
    if [ -f zig-out/bin/aercbook ] ; then
        filn=$RELEASE_DIR/aercbook-$(getversion)--$target
        mv zig-out/bin/aercbook $filn
        gzip -f $filn
    else
        filn=$RELEASE_DIR/aercbook-$(getversion)--$target.exe
        mv zig-out/bin/aercbook.exe $filn
        zip -9 $filn.zip $filn
        rm -f $filn
    fi
    echo ""
}

build x86_64-linux
build x86_64-macos
build aarch64-macos
build x86_64-windows
