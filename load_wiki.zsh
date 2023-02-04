#!/usr/bin/env zsh

script_dir=${0:a:h}
set -e
set -a
. $script_dir/.env
set +a

if (( ${+ES_PASSWORD} )); then
  es_user="${ES_USER:-elastic}"
  es_auth=(-u $es_user:$ES_PASSWORD)
else
  es_auth=
fi

wikiapi=https://en.wikipedia.org
data_set="${WIKI:-enwiki}"
index="${ES_INDEX:-$data_set}"
data_dir="$script_dir/data/$data_set"
chunks_dir="$data_dir/chunks"
dump_date="${WIKI_DUMP_DATE:-20230130}"
dump_file=$data_dir/$data_set-$dump_date-cirrussearch-content.json.gz
dump_url=https://dumps.wikimedia.org/other/cirrussearch/$dump_date/$data_set-$dump_date-cirrussearch-content.json.gz
es="${ES_URL:-http://localhost:9200}"

echo "Processing $data_set"
echo "Index $index"
echo "Dump date $dump_date"

mkdir -p $data_dir

if [ ! -f $dump_file ]; then
  echo "Downloading $dump_file"
  curl -o $dump_file -L $dump_url
fi

if [ ! -d $chunks_dir ]; then
  mkdir -p $chunks_dir
  echo "Splitting  $dump_file into chunks"  
  gunzip -c $dump_file | jq -c 'if .index then del(.index._type) else . end' | split -a 10 -l 500 - $chunks_dir/$index
fi

echo "Creating $index using $es"

curl $es_auth -XDELETE "$es/$index?pretty"
curl -H 'Content-Type: application/json' -s $wikiapi'/w/api.php?action=cirrus-settings-dump&format=json&formatversion=2' |
  jq '{
    settings: { 
        index: { 
            analysis: .content.page.index.analysis, 
            similarity: .content.page.index.similarity 
        } 
    }
  } |
    del(.settings.index.analysis.filter.weighted_tags_term_freq) |
    del(.settings.index.analysis.analyzer.weighted_tags) |
    walk(if type == "object" and .type == "edgeNGram" then .type |= "edge_ngram" else . end) |
    walk(if type == "object" and .type == "nGram" then .type |= "ngram" else . end) |
    walk(if type == "array" then map(select(. != "preserve_original_recorder" and . != "preserve_original" and .!= "homoglyph_norm")) else . end)
  ' |
  curl $es_auth -H 'Content-Type: application/json' -XPUT $es/$index\?pretty -d @-

curl -H 'Content-Type: application/json' -s $wikiapi'/w/api.php?action=cirrus-mapping-dump&format=json&formatversion=2' |
  jq ' .content | 
    del(.properties.weighted_tags) |
    walk(if type == "object" and .format == "dateOptionalTime" then .format |= "date_optional_time" else . end) 
  ' |
  curl $es_auth -H 'Content-Type: application/json' -XPUT $es/$index/_mapping\?pretty -d @-  

echo "Loading $data_set chunks"

for file in $data_dir/chunks/*; do
  echo -n "${file}:  "
  took=$(curl $es_auth -s -H 'Content-Type: application/x-ndjson' -XPOST $es/$index/_bulk\?pretty --data-binary @$file |
    jq '.took')
  printf '%7s\n' $took
done

echo "Done"