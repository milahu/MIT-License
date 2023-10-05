#! /usr/bin/env bash

# wrap text file at 78 columns

# https://github.com/jgm/pandoc/issues/9122 # add input format plain

if ! [ -e "$1" ]; then
  echo usage: wrap.sh input_file.txt
  exit 1
fi

# the conversion done by pandoc is lossy
# so we need a backup
bak_path="$1.$(date +%F.%H-%M-%S)"
cp -v "$1" "$bak_path"

pandoc "$1" -t plain --wrap=auto --columns=78 -o "$1"
