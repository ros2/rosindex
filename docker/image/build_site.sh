#!/bin/bash

SCAFFOLD_PATH=${1:-`pwd`}
SITE_PATH=${2:-${SCAFFOLD_PATH}/_site}
make -C $SCAFFOLD_PATH build site_path=$SITE_PATH
