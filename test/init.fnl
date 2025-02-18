(local fennel (require :fennel))
(local t (require :test.faith))
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))
(local https (require :https))

(local db-path "test/data.db")

(fn setup-all []
  (os.remove db-path)
  (let [caps {: io :os {:time os.time :tmpname os.tmpname}
              :log #nil :dbg #nil :sleep #nil
              :sources ["test" "test2"] :static {:why "because"}
              :robotstxt (require :robotstxt)
              :sqlite (require :luasql.sqlite3)
              :moonmint (require :moonmint)
              :request {:get (partial (. (require :request) :get) https)}}]
    (set caps.db (sql.init caps db-path))
    ;; need to run `make test-server' in the background so these URLs work
    (index.index caps "test/urls.txt" "test")
    (index.index caps "test/urls2.txt" "test2")
    caps))

(fn test-search [caps]
  (let [urls (collect [url title (caps.db:search "technomancy")]
               title url)]
    (t.= "http://localhost:8733/leiningen.html" (. urls "Leiningen"))
    (t.= "http://localhost:8733/technomancy.html"
         (. urls "in which things once suspended are resumed - Technomancy"))
    (t.= nil (. urls "do not index me, bot!"))))

(fn test-sanitize [caps]
  (each [_ q (ipairs ["non-blocking" "non.blocking" "blocking!"])]
    (t.is (pick-values 1 ((caps.db:search q)))
          (.. "expected results from " q))))

(fn test-source [caps]
  (let [urls (collect [url title (caps.db:search "a" ["test"])] title url)]
    (t.is (. urls "Leiningen"))
    (t.= nil (. urls "readme")))
  (let [urls (collect [url title (caps.db:search "a" ["test2"])] title url)]
    (t.= nil (. urls "Leiningen"))
    (t.is (. urls "readme"))))

(fn tidy? [{: body}]
  (let [tidy (io.popen "tidy -q -e -" :w)]
    (tidy:write body)
    (tidy:close)))

(fn test-tidy [caps]
  (t.is (tidy? (responses.home caps)))
  (t.is (tidy? (responses.search caps {:rawQuery "q=technomancy"} true)))
  (t.is (tidy? (responses.snippet caps :why))))

(fn test-responses [caps]
  ;; both sources
  (let [rawQuery "q=technomancy&source=test&source=test2"
        response (responses.search caps {: rawQuery} true)
        headers (collect [_ [k v] (ipairs response.headers)] k v)]
    (t.= 200 response.code)
    (t.= "text/html" (. headers "Content-Type"))
    (t.match "suspended" response.body)
    (t.match "readme" response.body))
  ;; just one source
  (let [rawQuery "q=technomancy&source=test"
        response (responses.search caps {: rawQuery} true)
        headers (collect [_ [k v] (ipairs response.headers)] k v)]
    (t.= 200 response.code)
    (t.= "text/html" (. headers "Content-Type"))
    (t.match "suspended" response.body)
    (t.not-match "readme" response.body))
  ;; the other source
  (let [rawQuery "q=technomancy&source=test2"
        response (responses.search caps {: rawQuery} true)
        headers (collect [_ [k v] (ipairs response.headers)] k v)]
    (t.= 200 response.code)
    (t.= "text/html" (. headers "Content-Type"))
    (t.not-match "suspended" response.body)
    (t.match "readme" response.body)))

{: setup-all
 : test-search
 : test-sanitize
 : test-source
 : test-tidy
 : test-responses}
