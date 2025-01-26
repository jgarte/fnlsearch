URL_FILE ?= urls.txt

run: ; fennel main.fnl start 8082
index: ; fennel main.fnl index $(URL_FILE)
copy: ; rsync data.db home:src/search/data.db
