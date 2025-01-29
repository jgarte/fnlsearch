(local t (require :test.faith))
(local search (require :search))

;; need to run `make test-server' in the background so these URLs work
(local urls-path "test/urls.txt")
(local db-path "test/data/data.db")

(fn test-search []
  (os.remove db-path)
  (search.index urls-path db-path (os.time))
  (let [results (search.results db-path "technomancy")
        urls (collect [_ [url title] (ipairs results)] url title)]
    (t.= "Leiningen" (. urls "http://localhost:8733/leiningen.html"))
    (t.= "in which things once suspended are resumed - Technomancy"
         (. urls "http://localhost:8733/technomancy.html"))
    (t.= nil (. urls "http://localhost:8733/evil.html"))))

{: test-search}
