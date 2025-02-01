(local t (require :test.faith))
(local index (require :index))
(local sql (require :sql))

;; need to run `make test-server' in the background so these URLs work
(local urls-path "test/urls.txt")
(local db-path "test/data/data.db")

(fn test-search []
  (os.remove db-path)
  (let [caps {: io :os {:time os.time :tmpname os.tmpname}
              :db (sql.init db-path :search :insert :refresh)}]
    (index.index caps urls-path)
    (let [urls (collect [url title (caps.db:search "technomancy")]
                 url title)]
      (t.= "Leiningen" (. urls "http://localhost:8733/leiningen.html"))
      (t.= "in which things once suspended are resumed - Technomancy"
           (. urls "http://localhost:8733/technomancy.html"))
      (t.= nil (. urls "http://localhost:8733/evil.html")))
    (let [urls (collect [url title (caps.db:search "non-blocking")]
                 url title)]
      (t.is (. urls "http://localhost:8733/technomancy.html")))))

{: test-search}
