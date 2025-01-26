# Technomancy Search

My own personal search engine.

Installation:

    sudo apt install fennel lua-sql-sqlite3 lua-luv pandoc

Create a file of URLs, then index it with:

    fennel main.fnl index /path/to/urls

Run server:

    fennel main.fnl start 8080

## Todo

* [x] indexing
* [x] web UI
* [x] save titles in index
* [x] partial reindexing
* [x] source URLs from gotosocial
* [ ] source URLs from feeds
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
* [luv](https://github.com/luvit/luv) (dependency of moonmint, use apt or whatever)
* [lua-sql](https://lunarmodules.github.io/luasql/)
* [pandoc](https://pandoc.org)
