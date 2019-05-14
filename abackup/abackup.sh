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
    if [[ -f ${backuptimestamp} ]]; then 
        last=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)
        echo "****** last backup was ${last}"
    fi

    touch ${backuptimestamp}
    now=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)

    echo "****** rolling backup start *******"
    mkdir -p ${destfolder_rolling} ${logfolder}
    rsync ${rsyncopts} --log-file=${logfolder}/rolling-${now}.log "${sourcefolder}" "${destfolder_rolling}"
    echo "****** rolling backup end *******"
    
    echo ""
    
    echo "****** differential backup start ******"
    if [[ -n $last ]]; then
        destfolder_diff_last=$(realpath -m ${destfolder_diff}..)/last
        echo destfolder_diff_last $destfolder_diff_last
    fi

    mkdir -p ${destfolder_diff}
    sourcefolder=$(realpath -m $sourcefolder)
    destfolder_diff=$(realpath -m $destfolder_diff)

    if [[ -d ${destfolder_diff_last} ]]; then
        linkdestopt="--link-dest=${destfolder_diff_last}"
    else
        linkdestopt=
    fi
    echo rsync ${rsyncopts} --log-file=${logfolder}/differential-${now}.log "${sourcefolder}"  "${destfolder_diff}" $linkdestopt
    rsync ${rsyncopts} --log-file=${logfolder}/differential-${now}.log "${sourcefolder}"  "${destfolder_diff}" $linkdestopt

    ln -nsf "${destfolder_diff}" "${destfolder_diff_last}"
    echo "****** differential backup end ******"

fi

if [[ -n $STATUS ]]; then
    echo status: not implemented
fi
