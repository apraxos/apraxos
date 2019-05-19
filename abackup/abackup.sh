#!/bin/bash

# exit on error
set -e
# avoid globbing
set -f  

# check_folder ${name} ${folder}
function check_folder {
    _name=$1
    _folder=$2

    if [[ ! ( "${_folder}" =~ ^.+$ ) ]]; then
        echo "${_name} folder ${_folder} must be non null"
        exit 2
    fi
}

# rolling_backup ${now} ${sourcefolder} ${destfolder} 
function rolling_backup {
    _now=$1
    _sourcefolder=$2
    _destfolder=$3

    check_folder "source folder" $_sourcefolder
    check_folder "destination folder" $_destfolder
    
    # check if source folder exists
    _sourcefolder=$(realpath --relative-base . $_sourcefolder)

    mkdir -p ${_destfolder} ${logfolder}

    set -x
    echo "****** rolling backup start ${_sourcefolder} --> ${_destfolder} *******" >> ${logfolder}/rolling-${_now}.log
    rsync ${rsyncopts} --log-file=${logfolder}/rolling-${_now}.log "${_sourcefolder}" "${_destfolder}"
    echo "****** rolling backup end ${_sourcefolder} --> ${_destfolder} *******" >> ${logfolder}/rolling-${_now}.log
    set +x
}  

# differential_backup ${last} ${sourcefolder} ${destfolder} 
function differential_backup {
    _last=$1
    _sourcefolder=$2
    _destfolder=$3

    check_folder "source folder" $_sourcefolder
    check_folder "destination folder" $_destfolder

    # check if source folder exists
    _sourcefolder=$(realpath --relative-base . $_sourcefolder)
    
    _destfolder=$(realpath -m $_destfolder)
    _destfolder_last=$(realpath -m ${_destfolder}/..)/last
    mkdir -p ${_destfolder}

    if [[ -d ${_destfolder_last} ]]; then
        linkdestopt="--link-dest=${_destfolder_last}"
    else
        linkdestopt=
    fi
    
    set -x
    echo "****** differential backup start ${_sourcefolder} --> ${_destfolder} ******" >> ${logfolder}/differential-${now}.log
    rsync ${rsyncopts} --log-file=${logfolder}/differential-${now}.log "${_sourcefolder}"  "${_destfolder}" $linkdestopt
    ln -nsf "${_destfolder}" "${_destfolder_last}"
    echo "****** differential backup end ${_sourcefolder} --> ${_destfolder} ******" >> ${logfolder}/differential-${now}.log
    set +x
}

OTHER=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -h|--help)
    HELP="1"
    shift
    ;;
    --destfolders_diff)
    DESTFOLDERS_DIFF=("$2")
    shift
    shift
    ;;
    --destfolders_rolling)
    DESTFOLDERS_ROLLING=("$2")
    shift
    shift
    ;;
    status)
    STATUS="1"
    shift
    ;;
    changes)
    CHANGES="1"
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
    echo "possible commands: status, run, changes"
    exit 0
fi

source backup.cfg

if [[ -n $DESTFOLDERS_DIFF ]]; then
    destfolders_diff=$DESTFOLDERS_DIFF
fi
if [[ -n $DESTFOLDERS_ROLLING ]]; then
    destfolders_rolling=$DESTFOLDERS_ROLLING
fi


if [[ -n $1 ]]; then
    echo "unknown additional arguments:" $1
    exit 1
fi


if [[ -n $RUN ]]; then
    
    if [[ ! ( $destfolders_rolling =~ ^.+$ ) && ! ( $destfolders_diff =~ ^.+$) ]]; then
        echo "at leat destfolders_rolling or destfolders_diff must be non empty"
        exit 2
    fi

    if [[ -f ${backuptimestamp} ]]; then 
        last=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)
        echo "****** last backup was ${last}"
    fi

    touch ${backuptimestamp}
    now=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)

    sources=(${sourcefolders//,/ })
    for source in "${sources[@]}"
    do
        dests=(${destfolders_rolling//,/ })
        for dest in "${dests[@]}"
        do
            rolling_backup "${now}" "${source}" "${dest}" 
        done
        echo ""

        dests=(${destfolders_diff//,/ })
        for dest in "${dests[@]}"
        do
            differential_backup "${last}" "${source}" "${dest}" 
        done
    done

    touch ${backuptimestamp}_done
fi

if [[ -n $STATUS ]]; then
    if [[ ! -f ${backuptimestamp} ]]; then 
        echo "no started backup found"
        exit 1
    fi
    if [[ ! -f ${backuptimestamp}_done ]]; then 
        echo "no complete backup found"
        exit 2
    fi

    startedh=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)
    doneh=$(date -r ${backuptimestamp}_done +%Y-%m-%d-%H%M%S)
    echo "last backup"
    echo "  started ${startedh}"
    echo "  done ${doneh}"

    started=$(date -r ${backuptimestamp} +%s)
    done=$(date -r ${backuptimestamp}_done  +%s)
    
    if [[ "${started}" -gt "${done}" ]]; then
        echo ""
        echo "Last backup unsuccessful! Please check ${logfolder} for details!"
        exit 3
    fi

    sources=(${sourcefolders//,/ })
    count=0
    for source in "${sources[@]}"
    do
        c=$(find ${source} -newer ${backuptimestamp} | wc -l )
        count=$(( $count + $c ))
    done

    echo ""
    echo "There are ${count} newer files since last backup!"

    if [[ "${count}" -gt "0" ]]; then
        exit 4
    fi

    exit 0
fi

if [[ -n $CHANGES ]]; then

    sources=(${sourcefolders//,/ })

    for source in "${sources[@]}"
    do
        find ${source} -newer ${backuptimestamp}
    done

    exit 0
fi
