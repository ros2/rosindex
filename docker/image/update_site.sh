#!/bin/bash

SCAFFOLD_PATH=${1:-`pwd`}
SITE_PATH=${2:-${SCAFFOLD_PATH}/_site}
build_site $SCAFFOLD_PATH $SITE_PATH
if [ -z "$(git config --global user.name)" ]; then
    git config --global user.name "rosindex"
fi
if [ -z "$(git config --global user.name)" ]; then
    git config --global user.email "rosindex@build.ros.org"
fi
git -C $SITE_PATH commit -a -m "ROSIndex deployment by `whoami`"
