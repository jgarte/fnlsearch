URLS ?= urls.txt
PORT ?= 8082
SRC=main.fnl html.fnl request.fnl sql.fnl index.fnl responses.fnl
DEPS=moonmint robotstxt.lua capabilities.fnl dkjson.lua

run: https.so; fennel main.fnl start $(PORT)
repl: https.so; fennel main.fnl repl $(PORT)
runloop: run ; sleep 2; $(MAKE) runloop
repll: repl ; sleep 2; $(MAKE) repll

test: https.so; fennel test/faith.fnl --tests test
testall: https.so; fennel test/faith.fnl --tests test test.request
index: ; fennel main.fnl index $(URLS) $(URLS)
count: ; cloc $(SRC) ; cloc $(DEPS)
lint: ; fennel-ls --lint $(SRC)

update-moonmint: ; rsync -r ../moonmint/moonmint/ moonmint/

lua-https/build/https.so:
	git submodule update --init
	cd lua-https && cmake -Bbuild -S. -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/lua-https/build
	cd lua-https && cmake --build build --target install

https.so: lua-https/build/https.so ; cp $< $@

DESTDIR ?=
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

search: $(SRC)
	echo "#!/usr/bin/env lua" > $@
	fennel --compile --require-as-include main.fnl >> search

test-server: ; cd test/html && python3 -m http.server 8733

clean:
	rm -f https.so
	cd lua-https && git clean -f

.PHONY: run runloop index count lint test update-moonmint test-server clean
