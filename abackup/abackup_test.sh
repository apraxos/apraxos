source backup.cfg
 
rm -rf test backup_timestamp

mkdir -p $sourcefolder
echo test1 > $sourcefolder/test1.txt
echo test2 > $sourcefolder/test2.txt

./abackup.sh run

echo "###### test if destination file test1 exists in rolling backup folder"
if [[ ! -f $destfolder_rolling${sourcefolder}test1.txt ]]; then    
    echo failled && exit 1
fi

echo "###### test if destination file test1 exists in differential backup folder"
if [[ ! -f ${destfolder_diff_today}${sourcefolder}test1.txt ]]; then    
    echo failled1 && exit 1
fi
echo "###### test if destination file test1 exists in differential last backup folder"
if [[ ! -f ${destfolder_diff_last}${sourcefolder}test1.txt ]]; then    
    echo failled2 && exit 1
fi

echo test2b > $sourcefolder/test2.txt
echo test3 > $sourcefolder/test3.txt

# test tomorrow
destfolder_rolling=$(realpath -m --relative-to=. ${destfolder_rolling}../`date -v+1d +%A`)/
destfolder_diff=$(realpath -m --relative-to=. ${destfolder_diff}../`date -v+1d +%Y-%m-%d`)/
./abackup.sh run \
    --destfolder_rolling $destfolder_rolling \
    --destfolder_diff $destfolder_diff

echo test4 > $sourcefolder/test4.txt

# test the day after tomorrow
destfolder_rolling=$(realpath -m --relative-to=. ${destfolder_rolling}../`date -v+2d +%A`)/
destfolder_diff=$(realpath -m --relative-to=. ${destfolder_diff}../`date -v+2d +%Y-%m-%d`)/
./abackup.sh run \
    --destfolder_rolling $destfolder_rolling \
    --destfolder_diff $destfolder_diff

# ToDo: tests that show that the differential backup works
echo "###### list hard linked files"
find . -links +1 ! -type d -print

echo "###### test if 2 hard links for test1.txt exists in all differential backup folders"
if [[ 2 -ne $(find . -links +1 ! -type d -print | grep test1.txt | wc -l) ]]; then 
    echo failled && exit 1
fi

echo "###### test if 0 hard links for latest changed file test4.txt exists in differential backup folders"
if [[ 0 -ne $(find . -links +1 ! -type d -print | grep test4.txt | wc -l) ]]; then 
    echo failled && exit 1
fi

echo ""
echo "###### all tests successful"
