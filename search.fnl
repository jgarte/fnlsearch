(local sqlite (require :luasql.sqlite3))

(local schema (.. "CREATE VIRTUAL TABLE pages "
                  "USING fts5(url, title, body, source, crawled_at);"))

(fn init []
  (case (io.open "data.db")
    f (do (f:close) (: (sqlite.sqlite3) :connect "data.db"))
    _ (-> (: (sqlite.sqlite3) :connect "data.db")
          (doto (: :execute schema)))))

(fn results [{: q}]
  (let [db (init)
        query (: "SELECT url, title FROM pages('%s');" :format (db:escape q))
        cursor (assert (db:execute query))]
    (icollect [url title #(cursor:fetch)]
      [:a {:href url} title])))

(fn extract-metadata [body] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {:crawled-at (os.time) : title : body :source "bookmarks"}))

(fn insert-sql [db url {: body : title : crawled-at : source}]
  (: "INSERT INTO pages VALUES ('%s', '%s', '%s', '%s', '%s');" :format
     (db:escape url) (db:escape (or title url)) (db:escape body)
     (db:escape source) (db:escape crawled-at)))

(fn index [file]
  (let [db (init)
        pandoc-cmd "pandoc -s -f html -t markdown %s"]
    (each [line (io.lines file)]
      (let [url (line:match "([^ ]+)")]
        (with-open [pandoc (assert (io.popen (pandoc-cmd:format url)))]
          (let [sql (insert-sql db url (extract-metadata (pandoc:read :*all)))]
            (assert (db:execute sql))))))))

{: results : index : extract-metadata}
