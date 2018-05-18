#!/usr/bin/env bash
backup_path="/home/backups"
home="/home/jaryd"
date=$(date +%F)
tarsnap_dest="x1-home-$date"

# tar
tar=$(which tar)
tarsnap=$(which tarsnap)

# exclude this crap
skip_dirs=( 
  aur
  Dropbox 
  .dropbox*
  .cache 
  Downloads
)
for dir in "${skip_dirs[@]}"
do
  skip="$skip--exclude='$home/$dir' "
done

# build and run tar cmd
tar_cmd="$tarsnap -cf $tarsnap_dest $skip $home"
bash -c "$tar_cmd"
