
if [ "$1" == "" ];then
    flutter test --coverage $1
else
    flutter test --coverage --timeout none --name $1
fi
genhtml coverage/lcov.info -o coverage
