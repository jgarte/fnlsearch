(local fennel (require :fennel))
(local t (require :test.faith))
(local index (require :index))
(local request (require :request))
(local responses (require :responses))
(local json (require :dkjson))

(local db-path "test/data.db")

(local resources (require :resources))

(fn setup-all []
  (os.remove db-path)
  (let [caps {: io :os {:time os.time :tmpname os.tmpname}
              :log #nil :dbg #nil :sleep #nil
              :sources [{:name "test"} {:name "test2"}]
              :static {:why "because"}
              :robotstxt (require :robotstxt) : json
              :resource #(. resources $)
              :sqlite (require :luasql.sqlite3)
              : request}]
    (set caps.db (fennel.dofile "db.fnl" {} db-path))
    ;; need to run `make test-server' in the background so these URLs work
    (index.index caps "test/urls.txt" "test")
    (index.index caps "test/urls2.txt" "test2")
    (when (not= 200 (. (caps.request.get "http://localhost:8733/robots.txt")
                       :status))
      (error "Ensure `make test-server` is running in the background!"))
    caps))

(fn test-search [caps]
  (let [urls (collect [_ {: url : title} (ipairs (caps.db.search "technomancy"))]
               title url)]
    (t.= "http://localhost:8733/leiningen.html" (. urls "Leiningen"))
    (t.= "http://localhost:8733/technomancy.html"
         (. urls "in which things once suspended are resumed - Technomancy"))
    (t.= nil (. urls "do not index me, bot!"))))

(fn test-sanitize [caps]
  (each [_ q (ipairs ["non-blocking" "non.blocking" "blocking!"])]
    (let [html (responses.search caps {:q [q]})]
      (t.match "once suspended are resumed" html))))

(fn test-source [caps]
  (let [urls (collect [url title (caps.db.search "a" "[\"test\"]")]
               title url)]
    (t.is (. urls "Leiningen"))
    (t.= nil (. urls "readme")))
  (let [urls (collect [url title (caps.db.search "a" "[\"test2\"]")]
               title url)]
    (t.= nil (. urls "Leiningen"))
    (t.is (. urls "readme"))))

(fn tidy? [body]
  (let [tidy (io.popen "tidy -q -e -" :w)]
    (tidy:write body)
    (tidy:close)))

(fn test-tidy [caps]
  (t.is (tidy? (responses.home caps)))
  (t.is (tidy? (responses.search caps {:q ["technomancy"]})))
  (t.is (tidy? (responses.snippet caps "static/why.html"))))

(fn test-responses [caps]
  (let [html (responses.search caps {:q ["technomancy"]})]
    (t.match "suspended" html)
    (t.match "readme" html)))

{: setup-all
 : test-search
 : test-sanitize
 : test-tidy
 : test-responses
 ;; : test-source
 }
