#!/bin/bash

if [ "$1" == "go" ];then
    go build -v .
    ./fire
else
    MODE=server flutter test lib/main.dart
fi
