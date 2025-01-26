GTS_DB ?= /var/gotosocial/sqlite.db
GTS_USERNAME ?= technomancy

run: data.db; fennel main.fnl start 8082
index: urls.txt; fennel main.fnl index urls.txt

urls.txt: ; fennel main.fnl gts $(GTS_DB) $(GTS_USERNAME) > $@
data.db: index
