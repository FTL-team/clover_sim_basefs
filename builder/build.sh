#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

set -ex

# Bootstrap
$SCRIPTPATH/bootstrap.sh

# Copy scripts to the chroot
cp -r $SCRIPTPATH ./base/

systemd-nspawn --resolv-conf=replace-host -D ./base /bin/bash ./builder/base.sh