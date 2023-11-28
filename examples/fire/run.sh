#!/bin/bash
set -e

if [ "$1" == "go" ];then
    go build -v .
    ./fire
else
    ./build-dart.sh
    ./build/server/fire.sh
fi
