(local _fennel (require :fennel))
(local t (require :test.faith))
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))
(local json (require :dkjson))
(local request (require :request))

(local db-path "test/data.db")

(fn setup-all []
  (os.remove db-path)
  (let [caps {: io :os {:time os.time :tmpname os.tmpname}
              :log #nil :dbg #nil :sleep #nil
              :sources [{:name "test"} {:name "test2"}]
              :static {:why "because"}
              :robotstxt (require :robotstxt) : json
              :sqlite (require :luasql.sqlite3)
              : request}]
    (set caps.db (sql.init caps db-path))
    ;; need to run `make test-server' in the background so these URLs work
    (index.index caps "test/urls.txt" "test")
    (index.index caps "test/urls2.txt" "test2")
    (when (not= 200 (. (caps.request.get "http://localhost:8733/robots.txt")
                       :status))
      (error "Ensure `make test-server` is running in the background!"))
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
  (let [urls (collect [url title (caps.db:search "a" [{:name "test"}])]
               title url)]
    (t.is (. urls "Leiningen"))
    (t.= nil (. urls "readme")))
  (let [urls (collect [url title (caps.db:search "a" [{:name "test2"}])]
               title url)]
    (t.= nil (. urls "Leiningen"))
    (t.is (. urls "readme"))))

(fn tidy? [body]
  (let [tidy (io.popen "tidy -q -e -" :w)]
    (tidy:write body)
    (tidy:close)))

(fn test-tidy [caps]
  (t.is (tidy? (responses.home caps)))
  (t.is (tidy? (responses.search caps {:q "technomancy"})))
  (t.is (tidy? (responses.snippet caps "static/why.html"))))

(fn test-responses [caps]
  ;; both sources
  (let [html (responses.search caps {:q "technomancy"
                                     :source ["test" "test2"]})]
    (t.match "suspended" html)
    (t.match "readme" html))
  ;; just one source
  (let [html (responses.search caps {:q "technomancy" :source "test"})]
    (t.match "suspended" html)
    (t.not-match "readme" html))
  ;; no sources specified means all
  (let [html (responses.search caps {:q "technomancy"})]
    (t.match "suspended" html)
    (t.match "readme" html))
  ;; the other source
  (let [html (responses.search caps {:q "technomancy" :source "test2"})]
    (t.not-match "suspended" html)
    (t.match "readme" html)))

{: setup-all
 : test-search
 : test-sanitize
 : test-source
 : test-tidy
 : test-responses}
