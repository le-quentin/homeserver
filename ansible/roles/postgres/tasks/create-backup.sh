#!/bin/bash

backups_root=/backups
db=$1
printf -v date '%(%Y-%m-%d_%H:%M)T' -1
filename="dump-$db-$date.tar.gz"

sudo -u postgres pg_dump "$db" > "/tmp/$filename"
chown nfs:nfs "/tmp/$filename"
sudo -u nfs mkdir -p "$backups_root/$db"
sudo -u nfs mv "/tmp/$filename" "$backups_root/$db/$filename"
