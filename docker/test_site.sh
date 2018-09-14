#!/usr/bin/env bash
SCRIPT_DIR=`dirname $( readlink -m $( type -p $0 ))`

$SCRIPT_DIR/run.sh make build serve-devel
