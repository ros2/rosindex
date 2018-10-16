#!/bin/bash
SCRIPT_DIR=`dirname $( readlink -m $( type -p $0 ))`

docker build -f $SCRIPT_DIR/image/Dockerfile \
       --build-arg user=`whoami` --build-arg uid=`id -u` \
       -t rosindex/rosindex $SCRIPT_DIR/..
