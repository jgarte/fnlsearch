GTS_DB ?= /var/gotosocial/sqlite.db
GTS_USERNAME ?= technomancy
URLS ?= urls.txt
PORT ?= 8082
SRC=*.fnl
DEPS=moonmint lume.lua robotstxt.lua

run: https.so; fennel main.fnl start $(PORT)
test: https.so; fennel test/faith.fnl --tests test test.request
index: ; fennel main.fnl index $(URLS)
count: ; cloc $(SRC) ; cloc $(DEPS)
lint: ; fennel-ls --lint *.fnl

urls.txt: ; fennel main.fnl gts $(GTS_DB) $(GTS_USERNAME) > $@

update-moonmint: ; rsync -r ../moonmint/moonmint/ moonmint/

lua-https/build/https.so:
	git submodule update --init
	cd lua-https && cmake -Bbuild -S. -DCMAKE_BUILD_TYPE=Release \
		-DCMAKE_INSTALL_PREFIX=$(PWD)/lua-https/build
	cd lua-https && cmake --build build --target install

https.so: lua-https/build/https.so ; cp $< $@

test-server: ; cd test/html && python3 -m http.server 8733

clean:
	rm -f https.so
	cd lua-https && git clean -f

.PHONY: run index count lint test update-moonmint test-server clean
