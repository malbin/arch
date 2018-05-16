#!/usr/bin/env bash

skip_dirs=( 
  Dropbox 
  .dropbox*
  .cache 
  Downloads
)

for dir in "${skip_dirs[@]}"
do
  echo $dir
done
