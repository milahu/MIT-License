#! /usr/bin/env bash

# wrap text file at 78 columns

# https://github.com/jgm/pandoc/issues/9122 # add input format plain
# https://pandoc.org/custom-readers#example-plain-text-reader

if ! [ -e "$1" ]; then
  echo usage: wrap.sh input_file.txt
  exit 1
fi

pandoc "$1" -f plain.lua -t plain --wrap=auto --columns=78 -o "$1"
