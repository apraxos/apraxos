#!/bin/bash

# exit on error
set -e

OTHER=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    HELP="1"
    shift
    ;;
    --destfolder_diff)
    DESTFOLDER_DIFF=("$2")
    shift
    shift
    ;;
    --destfolder_rolling)
    DESTFOLDER_ROLLING=("$2")
    shift
    shift
    ;;
    status)
    STATUS="1"
    shift
    ;;
    run)
    RUN="1"
    shift
    ;;
    *)
    OTHER+=("$1") 
    shift 
    ;;
esac
done
set -- "${OTHER[@]}"

if [[ -n $HELP ]]; then
    echo HELP  = "${HELP}" STATUS="${STATUS}"
    exit 0
fi

source backup.cfg

if [[ -n $DESTFOLDER_DIFF ]]; then
    destfolder_diff=$DESTFOLDER_DIFF
fi
if [[ -n $DESTFOLDER_ROLLING ]]; then
    destfolder_rolling=$DESTFOLDER_ROLLING
fi


if [[ -n $1 ]]; then
    echo "additional arguments:" $1
fi

if [[ -n $RUN ]]; then
    echo "****** rolling backup *******"
    mkdir -p ${destfolder_rolling}
    rsync ${rsyncopts} "${sourcefolder}" "${destfolder_rolling}"
    
    echo "***** differential backup ******"
    destfolder_diff_last=$(realpath -m --relative-to=. ${destfolder_diff}..)/last
    echo destfolder_diff_last $destfolder_diff_last
    mkdir -p ${destfolder_diff}
    rsync ${rsyncopts}  "${sourcefolder}"  "${destfolder_diff}" --link-dest="${destfolder_diff_last}"
    ln -nsf "${destfolder_diff}" "${destfolder_diff_last}"
fi

if [[ -n $STATUS ]]; then
    echo status: not implemented
fi
