URLS ?= urls.txt
PORT ?= 8082
SRC=main.fnl html.fnl request.fnl sql.fnl index.fnl responses.fnl
DEPS=robotstxt.lua capabilities.fnl dkjson.lua

run: ; fennel main.fnl start $(PORT)
repl: ; fennel main.fnl repl $(PORT)
runloop: run ; sleep 2; $(MAKE) runloop
repll: repl ; sleep 2; $(MAKE) repll

test: ; fennel test/faith.fnl --tests test
testall: ; fennel test/faith.fnl --tests test test.request
index: ; fennel main.fnl index $(URLS) $(URLS)
count: ; cloc $(SRC) ; cloc $(DEPS)
lint: ; fennel-ls --lint $(SRC)

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

search: $(SRC)
	echo "#!/usr/bin/env lua" > $@
	fennel --compile --require-as-include main.fnl >> search
	chmod 755 $@

test-server: ; cd test/html && python3 -m http.server 8733

clean: ; rm -f search

.PHONY: run runloop index count lint test test-server clean
