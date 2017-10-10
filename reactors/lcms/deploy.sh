#!/usr/bin/env bash

# Path to app bundle
APP=$1
APPJSON=$2

if [ -z "${APPJSON}" ]
then
    APPJSON=$(find $APP -type f -name "*app.json")
fi

if [ -z "${APPJSON}" ]
then
    echo "Can't find an application JSON. Re-run $0 <app> <jsonfile>"
    exit 0
fi

# stage-test-data.csv marks localtest with a hidden file to indicate that its a bad idea to deploy it
if [[ -n $(find "${APP}" -name ".dirty" ) ]]
then
    echo "Error: A localtest directory inside $APP is marked as dirty. Please run clean-test-data.sh $APP <local-test-path> before deploying."
    exit 1
fi

if [ -z "$NODOCKER" ]
then
    if [ ! -f "./Dockerfile" ]
    then
        echo "Warning: ./Dockerfile not found. Image not built."
    else
        {
            bash build.sh
        } || { 
            echo "No ./build.sh script. Image not built."
        }
    fi
fi

# Agave application management
# Assumptions: 
_APPNAME=$(jq -r .name $APPJSON)
_APPVERS=$(jq -r .version $APPJSON)
_APPID="${_APPNAME}-${_APPVERS}"

_DEPPATH=$(jq -r .deploymentPath $APPJSON)
_DEPAPPSPATH=$(dirname "${_DEPPATH}")
_DEPSYS=$(jq -r .deploymentSystem $APPJSON)

# Deploy application assets
#
# Policies
# ATOMIC - Try to rename original DEPPATH on DEPSYS
# DESTRUCTIVE - Delete DEPPATH on DEPSYS (Yolo)
# INPLACE (default) - One-way sync to DEPSYS/DEPPATH

_FILEOPTS=
if [ ! -z "$_DEPSYS" ]
then
    _FILEOPTS="${_FILEOPTS} -S ${_DEPSYS}"
fi

if [ -z "$NOFILEOPS" ]
then
set -x
# DESTRUCTIVE
    files-delete ${_FILEOPTS} ${_DEPPATH}
    files-mkdir ${_FILEOPTS} -N ${_DEPAPPSPATH} /
    files-upload -q ${_FILEOPTS} -F ${APP} ${_DEPAPPSPATH}/
set +x
fi

# Register the application
if [ -z "$NOUPDATE" ]
then
set -x
    apps-addupdate -F ${APPJSON}
set +x
fi

# Sleep 1 then check its status

