#!/bin/bash
protoc --dart_out=grpc:. -I. server.proto
