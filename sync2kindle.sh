#!/bin/sh
rsync -zrvh --update -e "ssh -i ~/.ssh/kindleKey" * root@192.168.1.5:/mnt/us/extensions/clock
