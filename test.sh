
if [ "$1" == "" ];then
    flutter test --coverage $1
else
    flutter test --coverage --name $1
fi
genhtml coverage/lcov.info -o coverage
