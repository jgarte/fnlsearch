# Technomancy Search

My own [personal search engine](https://search.technomancy.us).

Installation:

    sudo apt install fennel lua-sql-sqlite3 lua-luv pandoc

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
media account (we can help with that one, maybe). Doesn't matter.

Point the indexer at this file, and it will crawl it. For each
successfully-fetched response, if it's text, it will toss it straight
into SQLite's [full-text search](https://www.sqlite.org/fts5.html). If
it's HTML, it'll pass it thru [pandoc](https://pandoc.org) first to
get something a little more palatable.

Once the indexing is done, you can launch a web server that will serve
up a search page and give you responses in your browser! You probably
want to put [Caddy](https://caddyserver.com/) in front of it to give
it TLS, but this isn't strictly required.

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
  * [x] robots.txt
  * [x] html generation?
* [x] capabilitize
* [ ] hugsql style SQL parameters
* [ ] cache robots?
* [ ] cache failures
* [-] ranking
* [-] source URLs from
  * [x] gotosocial database
  * [ ] RSS feeds
  * [ ] mastodon export
  * [ ] firefox history
* [ ] unescape titles

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
* [lume](https://github.com/rxi/lume) (included)
* [RobotsTXT](https://zadzmo.org/code/robotstxt/) (included)
* [capabilities.fnl](https://git.sr.ht/~technomancy/capabilities.fnl) (included)
* [lua-https](https://github.com/love2d/lua-https) (submodule)
* [luv](https://github.com/luvit/luv) (dependency of moonmint, use apt or whatever)
* [lua-sql](https://lunarmodules.github.io/luasql/)
* [pandoc](https://pandoc.org)
