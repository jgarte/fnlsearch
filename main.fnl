(local fennel (require :fennel))
(local moonmint (require :moonmint))

(local index (require :index))
(local gts (require :gts))
(local responses (require :responses))
(local sql (require :sql))

(set debug.traceback fennel.traceback)

(local dbg (if (os.getenv "DEBUG") print #nil))
(local log (if (os.getenv "SILENT") #nil print))

;; not going all-in on capabilities yet, but might as well start threading
;; things thru for when we do
(local caps {: io :os {:time os.time :tmpname os.tmpname} : dbg : log
             :db (sql.init "data.db") :sleep #(os.execute "sleep 1")})

(case arg
  ["index" url-file source] (index.index caps url-file source
                                         (os.getenv "SLOW"))
  ["gts" db-path username] (each [url (pairs (gts.urls db-path username))]
                             (print url))
  ["start" port] (let [router (moonmint.router)]
                   (router:get "/" (partial responses.home caps))
                   (router:get "/q" (partial responses.search caps))
                   (router:get "/reload" (partial responses.reload caps))
                   (router:get "/robots.txt" (partial responses.robots caps))
                   (-> (moonmint)
                       (: :use router)
                       (: :start {: port})))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE SOURCE_NAME
fennel main.fnl gts GTS_SQLITE_DB USERNAME\n")
        (os.exit 1)))
