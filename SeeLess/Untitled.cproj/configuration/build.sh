cd $CONFIG_DIR

rm -rf ../build &> /dev/null
mkdir ../build &> /dev/null

cd ../build

mkdir objects &> /dev/null

python ../configuration/find_sources.py

cd objects

sh .compile.sh

cd ../

rm objects/.compile.sh
