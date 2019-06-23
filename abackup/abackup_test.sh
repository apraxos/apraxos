#!/bin/bash

# all folders must be relative to this script 
cd $( dirname $0 )

source backup.cfg.test
 
rm -rf test backup_timestamp /tmp/abackup-test-nonrelative

sources=(${sourcefolders//,/ })
destsr=(${destfolders_rolling//,/ })
destsd=(${destfolders_diff//,/ })

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
sources[0]=$(realpath --relative-to . ${sources[0]})
sources[1]=$(realpath --relative-to . ${sources[1]})

./abackup.sh run \
    --config ./backup.cfg.test

echo "###### test if destination file test1 exists in rolling backup folder"
if [[ ( ! -f ${destsr[0]}/${sources[0]}/test1.txt ) ||  ( ! -f ${destsr[1]}/${sources[0]}/test1.txt ) ]]; then
    echo failled && exit 1
fi

echo "###### test if destination file test1 exists in differential backup folder"
if [[ ( ! -f ${destsd[0]}/${sources[0]}/test1.txt ) || ( ! -f ${destsd[1]}/${sources[0]}/test1.txt ) ]]; then    
    echo failled1 && exit 1
fi

echo "###### test if destination file test1 exists in differential last backup folder"
if [[ ( ! -f ${destsd[0]}/../last/${sources[0]}/test1.txt ) || ( ! -f ${destsd[1]}/../last/${sources[0]}/test1.txt ) ]]; then    
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
    --destfolders_diff $dd \
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
    --destfolders_diff $dd \
    --config ./backup.cfg.test

echo "###### list hard linked files"
find . -links +1 ! -type d -print

echo "###### test if 3 hard links for test1.txt exists in all differential backup folders"
if [[ 3 -ne $(find . -links +1 ! -type d -print | grep test1.txt | wc -l) ]]; then 
    echo failled && exit 1
fi

echo "###### test if 0 hard links for latest changed file test4.txt exists in differential backup folders"
if [[ 0 -ne $(find . -links +1 ! -type d -print | grep test4.txt | wc -l) ]]; then 
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

echo "###### test status with source folder and exclude with ignored changes"
./abackup.sh status \
    --sourcefolders ${sources[0]} \
    --config ./backup.cfg.test \
    --exclude "${sources[0]}/*.txt"

if [[ $? -ne 0 ]]; then 
    echo failled && exit 1
fi

echo ""
echo "###### all tests successful"
