(local sqlite (require :luasql.sqlite3))
(local log (if (os.getenv "DEBUG") print #nil))

(local schema (.. "CREATE VIRTUAL TABLE pages "
                  "USING fts5(url, title, body, source, crawled_at);"))

(fn init []
  (case (io.open "data.db")
    f (do (f:close) (: (sqlite.sqlite3) :connect "data.db"))
    _ (-> (: (sqlite.sqlite3) :connect "data.db")
          (doto (: :execute schema)))))

(fn results [{: q}]
  (let [db (init)
        query (: "SELECT distinct url, title FROM pages('%s');"
                 :format (db:escape q))
        cursor (assert (db:execute query))]
    (icollect [url title #(cursor:fetch)]
      [:a {:href url} title])))

(fn extract-metadata [body now] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {:crawled-at now : title : body :source "bookmarks"}))

(fn insert-sql [db url {: body : title : crawled-at : source}]
  (: "INSERT INTO pages VALUES ('%s', '%s', '%s', '%s', '%s');" :format
     (db:escape url) (db:escape (or title url)) (db:escape body)
     (db:escape source) (db:escape crawled-at)))

(local stale-time 604800) ; 1 week

(fn needs-refresh? [db url now]
  (let [query (: "SELECT crawled_at FROM pages WHERE url = '%s'"
                 :format (db:escape url))
        cursor (assert (db:execute query))]
    (case (cursor:fetch)
      crawled-at (< (tonumber crawled-at) (- now stale-time))
      _ true)))

(local pandoc-cmd "pandoc -s -f html -t markdown %s")

;; pointing pandoc to a webm does NOT go well (just hangs forever)
(fn skip? [url] (or (url:find "%.webm$") (url:find "%.mp[34]$")))

(fn index-url [db url now]
  (when (and (needs-refresh? db url now)
             (not (skip? url)))
    (log :GET url)
    (with-open [pandoc (assert (io.popen (pandoc-cmd:format url)))]
      (let [sql (insert-sql db url
                            (extract-metadata (pandoc:read :*all) now))]
        (assert (db:execute sql))))))

(fn index [file now]
  (let [db (init)]
    (each [line (io.lines file)]
      (let [url (line:match "([^ ]+)")]
        (index-url db url now)
        (when (os.getenv "SLOW")
          (os.execute "sleep 1"))))))

{: results : index}
