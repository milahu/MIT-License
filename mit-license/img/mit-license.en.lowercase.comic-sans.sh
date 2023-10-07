#!/bin/sh

base=mit-license.en.lowercase.comic-sans

# TODO automate rendering from txt to pdf
# currently i do this manually with libreoffice writer
# using a comic.ttf font from https://duckduckgo.com/?q=comic+sans+ttf

# note: this is not reproducible
# every run of this script will produce a different png file

# create $base.pdf.png
pdftocairo -png -singlefile -r 150 $base.pdf $base.pdf

# create a regular white border around the text
convert $base.pdf.png -fuzz 25% -trim -bordercolor white -border 50 +repage $base.png

rm $base.pdf.png
