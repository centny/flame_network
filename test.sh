
if [ "$1" == "" ];then
    flutter test --coverage $1
else
    flutter test --coverage --timeout none --name $1
fi
genhtml coverage/lcov.info -o coverage


pkgs="\
 github.com/centny/flame_network/lib/src/network\
"
export EMALL_DEBUG=1
echo "mode: set" > build/all.cov
for p in $pkgs;
do
 if [ "$1" = "-u" ];then
  go get -u $p
 fi
 go test -v -timeout 20m -covermode count --coverprofile=build/c.cov $p
 cat build/c.cov | grep -v "mode" >> build/all.cov
done

gocov convert build/all.cov > build/coverage.json
cat build/all.cov | sed 's/sxbastudio.com\/emall\/emservice\///' > build/coverage.cov
cat build/coverage.json | gocov-html > build/coverage.html
cat build/coverage.cov | gocover-cobertura > build/coverage.xml
go tool cover -func build/all.cov | grep total
