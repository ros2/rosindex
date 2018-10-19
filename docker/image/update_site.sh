#!/bin/bash

REPO_PATH=${1:-`pwd`}
SITE_PATH=${2:-${REPO_PATH}/_site}
build_site $REPO_PATH $SITE_PATH
git -C $SITE_PATH commit -a -m "ROSIndex deployment by `whoami`"
