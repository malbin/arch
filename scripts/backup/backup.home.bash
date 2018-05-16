#!/usr/bin/env bash
backup_path="/home/backups"
home="/home/jaryd"
date=$(date +%F)
tarsnap_dest="$(uname -n)-home-$date"

# tar
tar=$(which tar)
tarsnap=$(which tarsnap)

# config
skip_dirs=( 
  aur
  Dropbox 
  .dropbox*
  .cache 
  Downloads
)

# skip everything in
for dir in "${skip_dirs[@]}"
do
  skip="$skip--exclude='$home/$dir' "
done

# build and run tar cmd
tar_cmd="$tarsnap -cf $tarsnap_dest $skip $home"
bash -c "$tar_cmd"
