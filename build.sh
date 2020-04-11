docker build -f Dockerfile -t fernandocorrea/red-tester .
docker build -f Dockerfile-no-config -t fernandocorrea/red-tester-no-config .

echo "Push the new images [y/N]: "
read push
if [ x$push == "xy" ]
then
    docker push fernandocorrea/red-tester
    docker push fernandocorrea/red-tester-no-config
fi