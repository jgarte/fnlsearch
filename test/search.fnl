(local t (require :test.faith))
(local search (require :search))

(local db-path "test/data/data.db")
(local urls-path "test/urls.txt")

(fn test-search []
  (os.remove db-path)
  (search.index urls-path db-path (os.time))
  (let [results (search.results db-path "technomancy")
        urls (collect [_ [url title] (ipairs results)] url title)]
    (t.is (. urls "http://localhost:8733/technomancy.html"))))

{: test-search}
