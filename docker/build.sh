#!/usr/bin/env bash
BASE_DIR=`dirname $( readlink -m $( type -p $0 ))`

docker build -f $BASE_DIR/Dockerfile -t rosindex/rosindex $BASE_DIR/..
