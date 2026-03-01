URLS ?= urls.txt
PORT ?= 8082
SRC=main.fnl html.fnl request.fnl sql.fnl index.fnl responses.fnl
DEPS=robotstxt.lua capabilities.fnl dkjson.lua

all: technomancy-search

run: ; fennel --no-compiler-sandbox main.fnl start $(PORT)
repl: ; fennel --no-compiler-sandbox main.fnl start $(PORT) -
runloop: run ; sleep 2; $(MAKE) runloop
repll: repl ; sleep 2; $(MAKE) repll

test: ; fennel --no-compiler-sandbox test/faith.fnl --tests test
testall: ; fennel --no-compiler-sandbox test/faith.fnl --tests test test.request
index: ; fennel --no-compiler-sandbox main.fnl index $(URLS) $(URLS)
count: ; cloc $(SRC) ; cloc $(DEPS)
lint: ; fennel-ls --lint $(SRC)

DESTDIR ?=
PREFIX ?= /usr/local
BIN_DIR ?= $(PREFIX)/bin

technomancy-search: $(SRC)
	echo "#!/usr/bin/env lua" > $@
	fennel --no-compiler-sandbox --compile --require-as-include main.fnl >> $@
	chmod 755 $@

install: technomancy-search
	mkdir -p $(DESTDIR)$(BIN_DIR) && cp $< $(DESTDIR)$(BIN_DIR)/
	mkdir -p $(DESTDIR)/etc/systemd/system/
	install -m 644 technomancy-search.service $(DESTDIR)/etc/systemd/system/

uninstall:
	rm -f $(DESTDIR)$(BIN_DIR)/technomancy-search

test-server: ; cd test/html && python3 -m http.server 8733

clean: ; rm -f search

.PHONY: run runloop index count lint test test-server clean
