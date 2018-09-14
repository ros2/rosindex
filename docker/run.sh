#!/usr/bin/env bash
SCRIPT_DIR=`dirname $( readlink -m $( type -p $0 ))`

# Ensure your SSH private key has been added to the ssh-agent as follows:
# ssh-add /home/$USER/.ssh/id_rsa

# Example Usage:
# ./run.sh make build

COMMAND=''
if [ -z "$1" ]
then
  COMMAND="bash"
else
  COMMAND=$@
fi

docker run\
  --env SSH_AUTH_SOCK=/ssh-agent\
  -v $SSH_AUTH_SOCK:/ssh-agent\
  -v "$SCRIPT_DIR/../../workdir:/workdir:rw"\
  -v "$SCRIPT_DIR/..:/workdir/rosindex:rw"\
  --net=host\
  -p 4000:4000\
  -ti rosindex/rosindex\
  $COMMAND
