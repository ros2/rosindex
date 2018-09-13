#!/usr/bin/env bash
BASE_DIR=`dirname $( readlink -m $( type -p $0 ))`

$BASE_DIR/run.sh make build serve-devel
