GTS_DB ?= /var/gotosocial/sqlite.db
GTS_USERNAME ?= technomancy
URLS ?= urls.txt

run: ; fennel main.fnl start 8082
index: ; fennel main.fnl index $(URLS)
count: ; cloc *fnl
test: ; fennel test/faith.fnl --tests test.search
lint: ; fennel-ls --lint *.fnl

urls.txt: ; fennel main.fnl gts $(GTS_DB) $(GTS_USERNAME) > $@

update-moonmint: ; rsync -r ../moonmint/moonmint/ moonmint/

test-server: ; cd test/html && python3 -m http.server 8733

.PHONY: run index count lint test update-moonmint test-server
