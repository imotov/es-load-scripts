# Elasticsearch loading scripts

This is a collection of scripts to load diffrent test data to elasticsearch.


## Wiki Dumps

The `load_wiki.zsh` script loads different wiki dumps into elasticsearch. It is loosely based on the script in https://www.elastic.co/blog/loading-wikipedia but was updated to work with elasticsearch v8.0.0 and above and doesn't require installing any 3rd party plugins. The script will automatically download one of the wikipedia dumps and load it into elasticsearch.

It supports an optional `.env` file with the following variables:

```
ES_USER=changeme
ES_PASSWORD=changeme
ES_URL=http://localhost:9200
WIKI=enwiki
WIKI_DUMP_DATE=20230130
ES_INDEX=enwiki
```

To run:

```
$ ./load_wiki.zsh
```