source backup.cfg
 
rm -rf test

mkdir -p $sourcefolder
echo test1 > $sourcefolder/test1.txt
echo test2 > $sourcefolder/test2.txt

./abackup.sh run

echo "*** test if destination file test1 exists in rolling backup folder"
if [[ ! -f $destfolder_rolling${sourcefolder}test1.txt ]]; then    
    echo failled && exit 1
fi

echo "*** test if destination file test1 exists in differential backup folder"
if [[ ! -f ${destfolder_diff_today}${sourcefolder}test1.txt ]]; then    
    echo failled1 && exit 1
fi
if [[ ! -f ${destfolder_diff_last}${sourcefolder}test1.txt ]]; then    
    echo failled2 && exit 1
fi


# test tomorrow
destfolder_rolling=$(realpath -m --relative-to=. ${destfolder_rolling}../`date -v+1d +%A`)/
destfolder_diff=$(realpath -m --relative-to=. ${destfolder_diff}../`date -v+1d +%Y-%m-%d`)/
./abackup.sh run \
    --destfolder_rolling $destfolder_rolling \
    --destfolder_diff $destfolder_diff

# test the day after tomorrow
destfolder_rolling=$(realpath -m --relative-to=. ${destfolder_rolling}../`date -v+2d +%A`)/
destfolder_diff=$(realpath -m --relative-to=. ${destfolder_diff}../`date -v+2d +%Y-%m-%d`)/
./abackup.sh run \
    --destfolder_rolling $destfolder_rolling \
    --destfolder_diff $destfolder_diff

# ToDo: tests that show that the differential backup works

echo "*** all tests successful"
