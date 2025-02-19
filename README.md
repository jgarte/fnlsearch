# Technomancy Search

My own [personal search engine](https://search.technomancy.us).

Installation:

    sudo apt install fennel lua-sql-sqlite3 lua-luv pandoc

(You might not find `fennel` in apt yet depending on your distro, but
it's available in my [third-party repo](https://apt.technomancy.us) or
you can [install manually](https://fennel-lang.org/setup) easily enough.)

Create a file of URLs, then index it with:

    make index URLS=/path/to/urls

Run server:

    make run PORT=8080

Originally based on this post: 
https://hey.hagelb.org/users/technomancy/statuses/01J1AYF55SMFK81JS13S64YF5V

## How does it work???

Well, it's very simple you see.

You start out with a file that contains a list of URLs. Maybe it's
your bookmarks file that you've been lovingly collecting over the past
9 years. Maybe you got it from grepping some archive you found. Maybe
it came from an RSS feed? Or you could extract it from your social
media account. Doesn't matter.

Point the indexer at this file, and it will crawl it. For each
successfully-fetched response, if it's text, it will toss it straight
into SQLite's [full-text search](https://www.sqlite.org/fts5.html). If
it's HTML, it'll pass it thru [pandoc](https://pandoc.org) first to
get something a little more palatable.

Once the indexing is done, you can launch a web server that will serve
up a search page and give you responses in your browser! You probably
want to put [Caddy](https://caddyserver.com/) in front of it to give
it TLS, but this isn't strictly required.

## Search sources

I lied! It's not that simple.

Every time you index a set of URLs, you provide a `source` field which
will be stored with the pages from that indexing run. When you go to
make a search, you can select what sources you wish to use on a
per-query basis.

## Distributed searches

Local sources get added automatically at indexing time. But you can
also add remote sources so that searches include results across a
number of sites.

To add a remote, run this:

    fennel main.fnl add-remote "https://search.technomancy.us?q=%s" \
      "technomancy searches" "https://search.technomancy.us" \
      "a search engine"

Then it will show up in the sources listing for each search.

## Also there is an API

https://search.technomancy.us/q.json?q=hello

```json
{
    "results": [
        {
            "url": "https://fennel-lang.org",
            "rank": 1.9,
            "title": "The Fennel Programming Language"
        },
        {
            "url": "https://leiningen.org",
            "rank": 1.68,
            "title": "Leiningen"
        },
        {
            "url": "https://technomancy.us/202",
            "rank": 1.44,
            "title": "in which things once suspended are resumed - Technomancy"
        }
    ]
}
```

## Development

Install `tidy` from apt or whatever.

Run `make test-server` in the background before `make test`.

## Todo

* [x] indexing
* [x] web UI
* [x] save titles in index
* [x] partial reindexing
* [x] honor robots.txt
* [x] stack traces
* [x] serve robots.txt
* [x] error responses for 404 and 500 (moonmint bug)
* [x] put SQL somewhere better
* [x] use moonmint agent for fetching
* [x] tests
* [x] capabilitize
* [x] why page
* [x] opensearch https://www.hanselman.com/blog/on-the-importance-of-opensearch
* [x] repl!!!
* [x] source filtering
* [x] json API
* [x] storing remote sources
* [x] basic distributed searches
* [ ] add-remote from opensearch.xml?
* [ ] index run summary
* [ ] crawl table?
  * [ ] url
  * [ ] crawled_at
  * [ ] content_type
  * [ ] status (200/404/500/blocked/not-indexable)
* [ ] send PDFs to pandoc
* [ ] hugsql style SQL parameters
* [ ] cache robots?
* [-] ranking

## Schema

* url
* title
* body
* last crawled
* source

## License

Copyright © 2025 Phil Hagelberg

Released under the [MIT license](LICENSE).

Dependencies:

* [fennel](https://fennel-lang.org)
* [moonmint](https://github.com/bakpakin/moonmint) (included)
* [RobotsTXT](https://zadzmo.org/code/robotstxt/) (included)
* [capabilities.fnl](https://git.sr.ht/~technomancy/capabilities.fnl) (included)
* [dkjson](http://dkolf.de/dkjson-lua/) (included)
* [lua-https](https://github.com/love2d/lua-https) (submodule)
* [sqlite](https://www.sqlite.org/) (apt)
* [luv](https://github.com/luvit/luv) (apt)
* [lua-sql](https://lunarmodules.github.io/luasql/) (apt)
* [pandoc](https://pandoc.org) (apt)
