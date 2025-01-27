GTS_DB ?= /var/gotosocial/sqlite.db
GTS_USERNAME ?= technomancy

run: ; fennel main.fnl start 8082
index: urls.txt; fennel main.fnl index urls.txt
count: ; cloc *fnl

urls.txt: ; fennel main.fnl gts $(GTS_DB) $(GTS_USERNAME) > $@

.PHONY: run index count
