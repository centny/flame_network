#!/bin/bash
set -xe

mkdir -p coverage

if [ "$1" == "" ];then
    flutter test --coverage $1
else
    flutter test --coverage --timeout none --name $1
fi
lcov --remove coverage/lcov.info 'lib/src/network/grpc/' -o coverage/new_lcov.info
genhtml coverage/new_lcov.info -o coverage


if [ "$1" == "" ];then
    pkgs="\
        github.com/centny/flame_network/lib/src/network\
    "
    export EMALL_DEBUG=1
    echo "mode: set" > coverage/all.cov
    for p in $pkgs;
    do
    if [ "$1" = "-u" ];then
    go get -u $p
    fi
    go test -v -timeout 20m -covermode count --coverprofile=coverage/c.cov $p
    cat coverage/c.cov | grep -v "mode" >> coverage/all.cov
    done

    gocov convert coverage/all.cov > coverage/gocov.json
    cat coverage/all.cov | sed 's/github.com\/centny\/flame_network\///' > coverage/gocov.cov
    cat coverage/gocov.json | gocov-html > coverage/gocov.html
    cat coverage/gocov.cov | gocover-cobertura > coverage/gocov.xml
    go tool cover -func coverage/all.cov | grep total
fi