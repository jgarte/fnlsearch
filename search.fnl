(local sqlite (require :luasql.sqlite3))

(fn init []
  (case (io.open "data.db")
    f (do (f:close) (: (sqlite.sqlite3) :connect "data.db"))
    _ (-> (: (sqlite.sqlite3) :connect "data.db")
          (doto (: :execute "CREATE VIRTUAL TABLE pages USING fts5(url, body);")))))

(fn results [{: q}]
  (let [db (init)
        query (: "SELECT url FROM pages('%s');" :format (db:escape q))
        cursor (assert (db:execute query))]
    (icollect [url #(cursor:fetch)]
      [:a {:href url} url])))

(fn index [file]
  (let [db (init)
        pandoc-cmd "pandoc -f html -t markdown %s"]
    (each [line (io.lines file)]
      (let [url (line:match "([^ ]+)")]
        (with-open [pandoc (assert (io.popen (pandoc-cmd:format url)))]
          (db:execute (: "INSERT INTO pages VALUES ('%s', '%s')" :format
                         (db:escape url) (db:escape (pandoc:read :*all)))))))))

{: results : index}
