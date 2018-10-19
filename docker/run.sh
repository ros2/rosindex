#!/bin/bash
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

docker run \
  -w /home/`whoami`/rosindex \
  -v $SCRIPT_DIR/..:/home/`whoami`/rosindex:rw \
  --net=host -ti rosindex/rosindex $COMMAND
