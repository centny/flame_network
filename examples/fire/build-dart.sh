#!/bin/bash
set -e

pkg_ver=`git rev-parse --abbrev-ref HEAD`
flutter_ver=3.16.1

cd `dirname ${0}`/../../
if [[ "$(docker images -q flutter:$flutter_ver 2> /dev/null)" == "" ]]; then
    docker build --build-arg=VER=$flutter_ver -t flutter:$flutter_ver -f examples/fire/DockerfileSDK .
fi

docker build -t fire-dart:$pkg_ver -f examples/fire/DockerfileDart .
