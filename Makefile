GTS_DB ?= /var/gotosocial/sqlite.db
GTS_USERNAME ?= technomancy
URLS ?= urls.txt
PORT ?= 8082
SRC=*.fnl
DEPS=moonmint lume.lua robotstxt.lua

run: ; fennel main.fnl start $(PORT)
index: ; fennel main.fnl index $(URLS)
count: ; cloc $(SRC) ; cloc $(DEPS)
test: ; fennel test/faith.fnl --tests test
lint: ; fennel-ls --lint *.fnl

urls.txt: ; fennel main.fnl gts $(GTS_DB) $(GTS_USERNAME) > $@

update-moonmint: ; rsync -r ../moonmint/moonmint/ moonmint/

test-server: ; cd test/html && python3 -m http.server 8733

.PHONY: run index count lint test update-moonmint test-server
