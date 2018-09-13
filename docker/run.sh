#!/usr/bin/env bash
BASE_DIR=`dirname $( readlink -m $( type -p $0 ))`

# Ensure your SSH private key has been added to the ssh-agent as follows:
# ssh-add /home/$USER/.ssh/id_rsa

# Example Usage:
# ./run.sh make build

docker run\
  --env SSH_AUTH_SOCK=/ssh-agent\
  -v $SSH_AUTH_SOCK:/ssh-agent\
  -v "$BASE_DIR/workdir:/workdir:rw"\
  -v "$BASE_DIR/..:/workdir/rosindex:rw"\
  --net=host\
  -p 4000:4000\
  -ti rosindex/rosindex\
  $@
