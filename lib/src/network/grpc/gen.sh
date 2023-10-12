#!/bin/bash
protoc --dart_out=grpc:. -I. server.proto

protoc --go_out=. --go_opt=paths=source_relative \
    --go-grpc_out=. --go-grpc_opt=paths=source_relative \
    server.proto