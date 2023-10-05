#! /usr/bin/env bash

debug=false

en_url='https://en.wikipedia.org/wiki/MIT_License'

if [ -e links.txt ]; then
  # read cache
  language_links="$(cat links.txt)"
else
  echo "fetching language links of $en_url"
  language_links="$(
    echo "$en_url";
    #
    curl -s "$en_url" |
    grep -F '<a href="https://de.wikipedia.org/wiki/MIT-Lizenz"' |
    sed 's|<li class="interlanguage-link|\n&|g' |
    sed -E 's|^.*<a href="(https://[^"]+)".*$|\1|' |
    sed '/^\s*$/d'
  )"
  # write cache
  echo "$language_links" >links.txt
fi

if ! [ -d html ]; then # TODO remove
echo "fetching articles to html/"
mkdir -p html
cd html
wget -N -r -l 0 --adjust-extension $language_links
# TODO tell wget to not fetch the robots.txt file
find . -type f -name robots.txt -delete
cd ..
fi

if ! [ -d export ]; then # TODO remove
echo "fetching articles to export/"
# https://www.mediawiki.org/wiki/Help:Export
# $site/wiki/Special:Export/$name
mkdir -p export
cd export
# TODO does "wget --adjust-extension" add the ".xml" extensino?
wget -N -r -l 0 --adjust-extension $(echo "$language_links" | sed 's|\.wikipedia\.org/wiki/|&Special:Export/|')
# TODO tell wget to not fetch the robots.txt file
find . -type f -name robots.txt -delete
# remove the "/Special:Export/" part of file paths
while read export_path; do
  if ! echo "$export_path" | grep -q -F "/Special:Export/"; then
    continue
  fi
  d1=${export_path%/*}
  d2=${export_path%/*/*}
  n=${export_path##*/}
  mv -v "$export_path" "$d2/$n"
  rmdir -v "$d1"
done < <(
  find . -type f | sort
)
cd ..
fi

# TODO remove
export PATH=$PATH:/nix/store/9qcgz5dzf0lppxfyshhgk75zqf6vsypk-xq-0.2.44/bin



echo checking wiki

if ! [ -d wiki ]; then

echo "parsing articles from export/ to wiki/"

while read export_path; do

  # this should work, but no...
  # xq /mediawiki/page/text <export/de.wikipedia.org/wiki/Special:Export/MIT-Lizenz
  # xmlstarlet sel -t -c /mediawiki/page/text export/de.wikipedia.org/wiki/Special:Export/MIT-Lizenz

  # so lets do this the hard way...
  # 2944:<text bytes="5360" xml:space="preserve">
  text_match="$(
    grep -b -m1 -o -E '<text bytes="[0-9]+" xml:space="preserve">' "$export_path"
  )"
  $debug && echo "text match: $text_match"
  # 2944
  text_offset=$(echo "$text_match" | grep -o -E '^[0-9]+')
  $debug && echo "text offset: $text_offset"
  # <text bytes="5360" xml:space="preserve">
  text_open=$(echo "$text_match" | sed -E 's/^[0-9]+://')
  $debug && echo "text open: $text_open"
  $debug && echo "text open size: ${#text_open}"
  # input: <text bytes="5360" xml:space="preserve">Die '''MIT-Lizenz'''
  # expected: Die '''MIT-Lizenz'''
  # actual: ''MIT-Lizenz'''
  # -> 5 bytes are missing
  text_offset=$((text_offset + ${#text_open}))
  $debug && echo "text offset 2: $text_offset"
  # 5360
  # surprise! the "bytes" value is wrong.
  text_size_attr=$(echo "$text_match" | sed -E 's/.* bytes="([0-9]+)" .*/\1/')
  $debug && echo "text size attr: $text_size_attr"
  # lets get the text size from the "</text>" tag

  text_match="$(
    grep -b -m1 -o -E '</text>' "$export_path"
  )"
  $debug && echo "text match: $text_match"
  text_end=$(echo "$text_match" | grep -o -E '^[0-9]+')
  $debug && echo "text end: $text_end"
  text_size=$((text_end - text_offset))
  $debug && echo "text size: $text_size"

  text="$(dd if="$export_path" bs=1 skip=$text_offset count=$text_size status=none)"
  if $debug; then
    echo "text:"
    echo "$text" | head -n5
    echo "[...]"
    echo "$text" | tail -n5
  fi

  wiki_path="$export_path"
  wiki_path="wiki/${wiki_path#*/}"
  wiki_path="${wiki_path%.xml}.wiki"

  # unescape xml tags
  # &lt; -> <
  # &gt; -> >
  # &amp; -> &
  # TODO more?
  text="$(echo -n "$text" | sed -E 's/&lt;/</g; s/&gt;/>/g; s/&amp;/\&/g;')"

  # the sha1 hash is stored in base36
  text_sha1_base36=$(
    grep -b -m1 -o -E '<sha1>[0-9a-z]{31}</sha1>' "$export_path" |
    sed -E 's|^.*<sha1>([0-9a-z]{31})</sha1>.*$|\1|'
  )
  text_sha1_base16=$(echo $text_sha1_base36 | ./base_convert.py 36 16)

  text_sha1_base16_actual=$(echo -n "$text" | sha1sum - | cut -d' ' -f1)

  if [[ "$text_sha1_base16" != "$text_sha1_base16_actual" ]]; then
    echo "FIXME hash mismatch in $wiki_path"
    echo "text hash expected: $text_sha1_base16"
    echo "text hash actual  : $text_sha1_base16_actual"
  fi

  echo "writing $wiki_path"
  mkdir -p "$(dirname "$wiki_path")"
  echo -n "$text" >"$wiki_path"

done < <(
  # debug
  #echo export/de.wikipedia.org/wiki/MIT-Lizenz.xml
  find export/ -type f -name '*.xml' | sort
)

fi



echo checking md

if ! [ -d md ]; then

echo "parsing articles from wiki/ to md/"

while read wiki_path; do

  md_path="$wiki_path"
  md_path="md/${md_path#*/}"
  md_path="${md_path%.wiki}.md"

  echo "writing $md_path"

  mkdir -p "$(dirname "$md_path")"

  # TODO diff?
  #pandoc "$wiki_path" -o "$md_path" -t commonmark --wrap=none
  pandoc "$wiki_path" -o "$md_path" -t markdown_strict --wrap=none

done < <(
  find wiki/ -type f -name '*.wiki' | sort
)

fi



echo checking txt

if ! [ -d txt ]; then

mkdir txt

while read md_path; do

  txt_path="$md_path"
  txt_path="${txt_path#*/}"
  txt_path="$(echo "$txt_path" | sed 's|\.wikipedia.org/.*$||')"
  txt_path="txt/MIT_License.$txt_path.txt"

  echo "writing $txt_path"

  cp "$md_path" "$txt_path"

done < <(
  grep -r -F 'Copyright (c)' md/ |
  grep -v -F 'Copyright (c) <year> <copyright holders>' |
  sed 's/:.*$//'
)

fi
