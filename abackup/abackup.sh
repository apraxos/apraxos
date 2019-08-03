#!/bin/bash

# exit on error
set -e
# avoid globbing
set -f  

# all folders must be relative to this script 
cd $( dirname $0 )

# default env variables, can be overwitten in backup.cfg:
backuptimestamp=./backup_timestamp
rsyncopts='-av --delete --exclude-from=./backup_exclude.cfg'
logfolder=/tmp/abackup/log

# regular expression to decide if a folder is local or remote
idlocalreg="^[a-zA-Z0-9@_-]+:"

# check_folder ${name} ${folder}
function check_folder {
    _name=$1
    _folder=$2

    if [[ ! ( "${_folder}" =~ ^.+$ ) ]]; then
        echo "${_name} folder ${_folder} must be non null"
        exit 2
    fi
}

# dobackup ${now} ${sourcefolders} ${destfolders} rolling|incremental
function dobackup {
    _now=$1
    _sourcefolders=$2
    _destfolders=$3
    _type=$4

    dests=(${_destfolders//,/ })
    for dest in "${dests[@]}"
    do
        check_folder "destination folder" $dest

        if [[ ${_type} == "incremental" ]]; then
            dest=$(realpath -m $dest)
            dest_last=$(realpath -m ${dest}/..)/last

            if [[ -d ${dest_last} ]]; then
                linkdestopt="--link-dest=${dest_last}"
            else
                linkdestopt=
            fi
        fi
        
        mkdir -p ${logfolder} 
        # if it is a local folder create it, remote folders will be created by rsync
        if [[ ! ${dest} =~ ${idlocalreg} ]]; then
            mkdir -p ${dest}
        fi

        sources=(${_sourcefolders//,/ })
        for source in "${sources[@]}"
        do
            check_folder "source folder" $source

            if [[ ! ${source} =~ ${idlocalreg} ]]; then
                # if it is a local path, check if source folder exists
                source=$(realpath --relative-base . $source)
            fi

            set -x
            echo "****** ${_type} backup start ${source} --> ${dest} *******" >> ${logfolder}/${_type}-${_now}.log
            rsync ${rsyncopts} ${exclude} --stats --log-file=${logfolder}/${_type}-${now}.log "${source}"  "${dest}" $linkdestopt
            echo "****** ${_type} backup end ${source} --> ${dest} *******" >> ${logfolder}/${_type}-${_now}.log
            set +x

        done

        if [[ ${_type} == "incremental" ]]; then
                ln -nsf "${dest}" "${dest_last}"
        fi

        echo ""
    done

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
    -s|--sourcefolders)
    SOURCEFOLDERS=("$2")
    shift
    shift
    ;;
    -d|--destfolders_incr)
    DESTFOLDERS_INCR=("$2")
    shift
    shift
    ;;
    -r|--destfolders_rolling)
    DESTFOLDERS_ROLLING=("$2")
    shift
    shift
    ;;
    -e|--exclude)
    EXCLUDE=("$2")
    shift
    shift
    ;;
    -c|--config)
    BACKUP_CFG=("$2")
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

if [[ -n $BACKUP_CFG ]]; then
    source $BACKUP_CFG
else
    source backup.cfg
fi

if [[ -n $SOURCEFOLDERS ]]; then
    sourcefolders=$SOURCEFOLDERS
fi
if [[ -n $DESTFOLDERS_INCR ]]; then
    destfolders_incr=$DESTFOLDERS_INCR
fi
if [[ -n $DESTFOLDERS_ROLLING ]]; then
    destfolders_rolling=$DESTFOLDERS_ROLLING
fi
if [[ -n $EXCLUDE ]]; then
    exclude=$EXCLUDE
fi

_destfolders_all=$destfolders_incr
if [[ -n $_destfolders_all ]]; then
    if [[ -n $destfolders_rolling ]]; then
        _destfolders_all="$_destfolders_all,$destfolders_rolling"
    fi
else
    _destfolders_all=$destfolders_rolling 
fi
if [[ -n $exclude ]]; then
    exclude="--exclude $exclude"
fi

if [[ -n $1 ]]; then
    echo "unknown additional arguments:" $1
    exit 1
fi


if [[ -n $RUN ]]; then
    
    if [[ ! ( $destfolders_rolling =~ ^.+$ ) && ! ( $destfolders_incr =~ ^.+$) ]]; then
        echo "at leat destfolders_rolling or destfolders_incr must be non empty"
        exit 2
    fi

    if [[ -f ${backuptimestamp} ]]; then 
        last=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)
        echo "****** last backup was ${last}"
    fi
    
    # save _destfolders_all for future "abackup.sh status" calls
    echo $_destfolders_all > ${backuptimestamp}_destinations

    touch ${backuptimestamp}
    now=$(date -r ${backuptimestamp} +%Y-%m-%d-%H%M%S)

    dobackup "${now}" "${sourcefolders}" "${destfolders_rolling}" "rolling"
    dobackup "${now}" "${sourcefolders}" "${destfolders_incr}"    "incremental"

    touch ${backuptimestamp}_done

elif [[ -n $STATUS ]]; then
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
    echo "  done    ${doneh}"

    started=$(date -r ${backuptimestamp} +%s)
    done=$(date -r ${backuptimestamp}_done  +%s)
    
    if [[ "${started}" -gt "${done}" ]]; then
        echo ""
        echo "Last backup unsuccessful! Please check ${logfolder} for details!"
        exit 3
    fi

    sources=(${sourcefolders//,/ })
    newerCount=0
    changedCount=0
    for source in "${sources[@]}"
    do
        source=$(realpath --relative-base . $source)
        newer=$(find ${source} -newer ${backuptimestamp} | wc -l )
        newerCount=$(( $newerCount + $newer ))
    done

    destinations=$(cat ${backuptimestamp}_destinations)
    for source in "${sources[@]}"
    do
        source=$(realpath --relative-base . $source)
        dests=(${destinations//,/ })
        for dest in "${dests[@]}"
        do
            changed=$(rsync --dry-run --stats ${rsyncopts} ${exclude} "${source}" "${dest}" | grep -e "^Number of.*files transferred:" | sed "s/^.*files transferred: //" | sed 's/[,\.]//g')            
            # echo rsync --dry-run --stats ${rsyncopts} ${exclude} "${source}" "${dest}" --   $changed         
            changedCount=$(( $changedCount + $changed ))
        done
    done

    echo ""
    echo "There are ${newerCount} newer files since last backup!"
    echo "There are ${changedCount} files that need to be transferred since last backup!"

    if [[ "${changedCount}" -gt "0" ]]; then
        exit 4
    fi

    exit 0

elif [[ -n $CHANGES ]]; then

    sources=(${sourcefolders//,/ })
    destinations=$(cat ${backuptimestamp}_destinations)

    for source in "${sources[@]}"
    do
        source=$(realpath --relative-base . $source)
        dests=(${destinations//,/ })
        for dest in "${dests[@]}"
        do
            echo "****** changes start ${source} --> ${dest} ******"
            # set -x
            rsync --dry-run --verbose ${rsyncopts} ${exclude} "${source}" "${dest}"
            # set +x
            echo "****** changes end ${source} --> ${dest} ******"
        done
    done

    exit 0

elif [[ -n $HELP ]]; then
    echo "usage: abackup.sh [status|run|changes] [--config|-c filename] [--sourcefolders|-s folderlist] [--destfolders_incr|-d folderlist] [--destfolders_rolling|-r folderlist] [--exclude|-e filesorfolders]"
    exit 0

else 
    echo "run with argument -h for help"
    exit 1
fi
