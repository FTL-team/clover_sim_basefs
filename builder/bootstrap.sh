#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

set -ex

debootstrap --include=systemd-container --components=main,universe,multiverse focal base http://archive.ubuntu.com/ubuntu | tee