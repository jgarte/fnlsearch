(local fennel (require :fennel))
(local t (require :test.faith))
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))
(local https (require :https))

;; need to run `make test-server' in the background so these URLs work
(local urls-path "test/urls.txt")
(local db-path "test/data/data.db")

(fn setup-all []
  (os.remove db-path)
  (let [caps {: io :os {:time os.time :tmpname os.tmpname}
              :log #nil :dbg #nil :sleep #nil
              :robotstxt (require :robotstxt)
              :sqlite (require :luasql.sqlite3)
              :moonmint (require :moonmint)
              :request {:get (partial (. (require :request) :get) https)}}]
    (set caps.db (sql.init caps db-path))
    (index.index caps urls-path "test")
    caps))

(fn test-search [caps]
  (let [urls (collect [url title (caps.db:search "technomancy")]
               url title)]
    (t.= "Leiningen" (. urls "http://localhost:8733/leiningen.html"))
    (t.= "in which things once suspended are resumed - Technomancy"
         (. urls "http://localhost:8733/technomancy.html"))
    (t.= nil (. urls "http://localhost:8733/evil.html")))
  (each [_ q (ipairs ["non-blocking" "non.blocking" "blocking!"])]
    (t.is (pick-values 1 ((caps.db:search q)))
          (.. "expected results from " q))))

(fn tidy? [{: body}]
  (let [tidy (io.popen "tidy -q -e -" :w)]
    (tidy:write body)
    (tidy:close)))

(fn test-responses [caps]
  (t.is (tidy? (responses.home caps)))
  (t.is (tidy? (responses.search caps {:rawQuery "q=technomancy"} true))))

{: setup-all
 : test-search
 : test-responses}
