source backup.cfg
 
rm -rf test backup_timestamp

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

./abackup.sh run

echo "###### test if destination file test1 exists in rolling backup folder"
echo ${destsr[0]}/${sources[0]}/test1.txt
if [[ ( ! -f ${destsr[0]}/${sources[0]}/test1.txt ) ||  ( ! -f ${destsr[1]}/${sources[0]}/test1.txt ) ]]; then
    echo failled && exit 1
fi

echo "###### test if destination file test1 exists in differential backup folder"
echo ${destsd[0]}/../last/${sources[0]}/test1.txt
echo ${destsd[1]}/../last/${sources[0]}/test1.txt
if [[ ( ! -f ${destsd[0]}/${sources[0]}/test1.txt ) || ( ! -f ${destsd[1]}/${sources[0]}/test1.txt ) ]]; then    
    echo failled1 && exit 1
fi

echo "###### test if destination file test1 exists in differential last backup folder"
echo ${destsd[0]}/../last/${sources[0]}/test1.txt
if [[ ( ! -f ${destsd[0]}/../last/${sources[0]}/test1.txt ) || ( ! -f ${destsd[1]}/../last/${sources[0]}/test1.txt ) ]]; then    
    echo failled2 && exit 1
fi

echo test2b > ${sources[0]}/test2.txt
echo test3 > ${sources[0]}/test3.txt

# test tomorrow
dr=$(realpath -m --relative-to=. ${destsr[0]}/../`date -v+1d +%A`)/
dd=$(realpath -m --relative-to=. ${destsd[0]}/../`date -v+1d +%Y-%m-%d-%H%M`)/
./abackup.sh run \
    --destfolders_rolling $dr \
    --destfolders_diff $dd
echo test4 > ${sources[0]}/test4.txt
echo ${sources[0]}/test4.txt

# test the day after tomorrow (without trailing slashes)
dr=$(realpath -m --relative-to=. ${destsr[0]}/../`date -v+2d +%A`)
dd=$(realpath -m --relative-to=. ${destsd[0]}/../`date -v+2d +%Y-%m-%d-%H%M`)
./abackup.sh run \
    --destfolders_rolling $dr \
    --destfolders_diff $dd

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
./abackup.sh status
if [[ $? -ne 4 ]]; then 
    echo failled && exit 1
fi

echo ""
echo "###### all tests successful"
