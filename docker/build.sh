#!/usr/bin/env bash
SCRIPT_DIR=`dirname $( readlink -m $( type -p $0 ))`

docker build -f $SCRIPT_DIR/Dockerfile -t rosindex/rosindex $SCRIPT_DIR/..
