#!/bin/bash
set -e

pkg_ver=`git rev-parse --abbrev-ref HEAD`
flutter_ver=3.16.1

if [ "$1" == "docker" ];then
    cd `dirname ${0}`/../../
    if [[ "$(docker images -q flutter:$flutter_ver 2> /dev/null)" == "" ]]; then
        docker build --build-arg=VER=$flutter_ver -t flutter:$flutter_ver -f examples/fire/DockerfileSDK .
    fi

    docker build -t fire-dart:$pkg_ver -f examples/fire/DockerfileDart .
else
    if [ "$FLUTTER_ROOT" == "" ];then
        echo "FLUTTER_ROOT is not setted"
        exit 1
    fi
    mkdir -p build/server
    flutter build bundle
    cp -rf build/flutter_assets build/server/assets
    dart $FLUTTER_ROOT/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot \
        --sdk-root $FLUTTER_ROOT/bin/cache/artifacts/engine/common/flutter_patched_sdk/ \
        --target=flutter --enable-asserts \
        --output-dill build/server/fire.dill \
        lib/main.dart
    case `uname` in
    Darwin)
        cp -rf $FLUTTER_ROOT/bin/cache/artifacts/engine/darwin-x64/* build/server/
    ;;
    Linux)
        cp -rf $FLUTTER_ROOT/bin/cache/artifacts/engine/linux-x64/* build/server/
    ;;
    esac

    cat > build/server/fire.sh <<EOF
dir=\$(dirname \${0})
cd \$dir
export MODE=service
./flutter_tester --disable-vm-service --flutter-assets-dir=assets fire.dill
EOF
    chmod +x build/server/fire.sh
fi