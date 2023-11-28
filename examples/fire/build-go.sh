#!/bin/bash
set -e

pkg_ver=`git rev-parse --abbrev-ref HEAD`

if [ "$1" == "docker" ];then
    flutter build web
    cd `dirname ${0}`/../../
    docker build -t fire-go:$pkg_ver -f examples/fire/DockerfileGo .
else
    mkdir -p build/server
    go build -v -o build/server/fire .
fi