#! /bin/bash
search_dir=`pwd`
for entry in "$search_dir"/*
do
  convert -define dcm:display-range=reset "$entry" -normalize "$entry.png"
done