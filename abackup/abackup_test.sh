#!/bin/bash

# all folders must be relative to this script 
cd $( dirname $0 )

#
# the following tests use backup.cfg.test
#

source backup.cfg.test
 
rm -rf test backup_timestamp /tmp/abackup-test-nonrelative

sources=(${sourcefolders//,/ })
destsr=(${destfolders_rolling//,/ })
destsd=(${destfolders_incr//,/ })

destsr[0]=$(realpath -m --relative-to . ${destsr[0]})
destsr[1]=$(realpath -m --relative-to . ${destsr[1]})
destsd[0]=$(realpath -m --relative-to . ${destsd[0]})
destsd[1]=$(realpath -m --relative-to . ${destsd[1]})

for source in "${sources[@]}"
do
    mkdir -p $source
    echo test1 > $source/test1.txt
    echo test2 > $source/test2.txt
done

./abackup.sh run \
    --config ./backup.cfg.test

echo "###### test if destination file test1 exists in rolling backup folder"
if [[ ( ! -f ${destsr[0]}/$(basename ${sources[0]})/test1.txt ) ||  ( ! -f ${destsr[1]}/$(basename ${sources[0]})/test1.txt ) ]]; then
    echo failled && exit 1
fi

echo "###### test if destination file test1 exists in incremental backup folder"
if [[ ( ! -f ${destsd[0]}/$(basename ${sources[0]})/test1.txt ) || ( ! -f ${destsd[1]}/$(basename ${sources[0]})/test1.txt ) ]]; then    
    echo failled1 && exit 1
fi

echo "###### test if destination file test1 exists in incremental last backup folder"
if [[ ( ! -f ${destsd[0]}/../last/$(basename ${sources[0]})/test1.txt ) || ( ! -f ${destsd[1]}/../last/$(basename ${sources[0]})/test1.txt ) ]]; then    
    echo failled2 && exit 1
fi

echo "###### test status with source folder without changes"
./abackup.sh status \
    --sourcefolders ${sources[0]} \
    --config ./backup.cfg.test
if [[ $? -ne 0 ]]; then 
    echo failled && exit 1
fi

# simulate some changes
echo test2b > ${sources[0]}/test2.txt
echo test3 > ${sources[0]}/test3.txt

# workaround: macOS does not use GNU date as default but has gdate installed
datecmd=date
command -v gdate >/dev/null 2>&1 && datecmd=gdate

# test tomorrow
tomorrow=$($datecmd --date="-1 days ago" +%Y-%m-%d-%H%M)
tomorrow_wd=$($datecmd --date="-1 days ago" +%A)
dd=$(realpath -m --relative-to=. ${destsd[0]}/../${tomorrow})/
dr=$(realpath -m --relative-to=. ${destsr[0]}/../${tomorrow_wd})/

./abackup.sh run \
    --destfolders_rolling $dr \
    --destfolders_incr $dd \
    --config ./backup.cfg.test

# simulate some changes
echo test4 > ${sources[0]}/test4.txt
echo ${sources[0]}/test4.txt

# test the day after tomorrow (without trailing slashes)
tomorrow=$($datecmd --date="-2 days ago" +%Y-%m-%d-%H%M)
tomorrow_wd=$($datecmd --date="-2 days ago" +%A)
dd=$(realpath -m --relative-to=. ${destsd[0]}/../${tomorrow})
dr=$(realpath -m --relative-to=. ${destsr[0]}/../${tomorrow_wd})

./abackup.sh run \
    --destfolders_rolling $dr \
    --destfolders_incr $dd \
    --config ./backup.cfg.test

echo "###### list hard linked files"
find ./test -links +1 ! -type d -print

echo "###### test if file test1.txt exist 6 times in all incremental backup folders"
if [[ 6 -ne $(find test/backup_incr -name test1.txt | wc -l) ]]; then 
    echo failled && exit 1
fi

echo "###### test if 6 hard links for test1.txt exists in all incremental backup folders because test1.txt never changed"
if [[ 6 -ne $(find ./test -links +1 ! -type d -print | grep test1.txt | wc -l) ]]; then 
    echo failled && exit 1
fi

echo "###### test if 0 hard links for latest changed file test4.txt exists in incremental backup folders"
if [[ 0 -ne $(find ./test -links +1 ! -type d -print | grep test4.txt | wc -l) ]]; then 
    echo failled && exit 1
fi


echo "###### make sure backup is in sync"
./abackup.sh run \
    --config ./backup.cfg.test


echo "###### test status success on no changed files since last backup"
./abackup.sh status \
    --config ./backup.cfg.test

if [[ $? -ne 0 ]]; then 
    echo failled && exit 1
fi

echo "###### test status failure on two changed files since last backup"
sleep 1
touch ${sources[0]}/test2.txt
touch ${sources[0]}/test3.txt
./abackup.sh status \
    --config ./backup.cfg.test

if [[ $? -ne 4 ]]; then 
    echo failled && exit 1
fi

echo "###### test status with source folder with changes"
./abackup.sh status \
    --sourcefolders ${sources[0]} \
    --config ./backup.cfg.test

if [[ $? -ne 4 ]]; then 
    echo failled && exit 1
fi

echo "###### test status excluding standard and additional files"
touch ${sources[0]}/backup_timestamp

./abackup.sh status \
    --sourcefolders ${sources[0]} \
    --config ./backup.cfg.test \
    --exclude "*.txt"

if [[ $? -ne 0 ]]; then 
    echo failled && exit 1
fi


#
# the following tests use backup.cfg.testb
#

source backup.cfg.testb

sources=(${sourcefolders//,/ })

for source in "${sources[@]}"
do
    mkdir -p $source
    echo testb1 > $source/testb1.txt
    echo testb2 > $source/testb2.txt
done

./abackup.sh run \
    --config ./backup.cfg.testb

dest=$(realpath -m --relative-to . ${destfolders_incr})

echo "###### test if there is a backup for testb1.txt for both sources a2 and a3"
if [[ ( ! -f ${dest}/$(basename ${sources[0]})/testb1.txt ) || ( ! -f ${dest}/$(basename ${sources[1]})/testb1.txt ) ]]; then    
    echo failled1 && exit 1
fi

echo "###### test if file testb1.txt was synced twice"
if [[ 2 -ne $(grep "testb1.txt" test/logb/* | wc -l) ]]; then 
    echo failled && exit 1
fi

sleep 1

./abackup.sh run \
    --config ./backup.cfg.testb

dest=$(realpath -m --relative-to . ${destfolders_incr})

echo "###### test if there is a backup for testb1.txt for both sources a2 and a3"
if [[ ( ! -f ${dest}/$(basename ${sources[0]})/testb1.txt ) || ( ! -f ${dest}/$(basename ${sources[1]})/testb1.txt ) ]]; then    
    echo failled1 && exit 1
fi

echo "###### test if file testb1.txt was synced not again ( just twice from the last time )"
if [[ 2 -ne $(grep "testb1.txt" test/logb/* | wc -l) ]]; then 
    echo failled && exit 1
fi

echo "###### test idlocalreg if local folder is detected as local folder"
dest='/tmp/'
idlocalreg="^[a-zA-Z0-9@_\-\.]+:"

if [[ ${dest} =~ ${idlocalreg} ]]; then
    echo failled && exit 1
fi

echo "###### test ssh url reg expression with groups"
dest='admin@192.168.10.10:/share/CACHEDEV1_DATA/tmp/:abackuptest'
idlocalreg="(^[a-zA-Z0-9@_\-\.]+):(.*)"

if [[ ${dest} =~ ${idlocalreg} ]]; then
    if [[ ${BASH_REMATCH[1]} != "admin@192.168.10.10" ]]; then
            echo failled && exit 1
    fi
    if [[ ${BASH_REMATCH[2]} != "/share/CACHEDEV1_DATA/tmp/:abackuptest" ]]; then
            echo failled && exit 1
    fi
fi


echo ""
echo "###### all tests successful"
