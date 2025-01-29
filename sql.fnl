(local sqlite (require :luasql.sqlite3))

(local schema (.. "CREATE VIRTUAL TABLE pages "
                  "USING fts5(url, title, body, source, crawled_at);"))

(λ init [db-path]
  (case (io.open db-path)
    f (do (f:close) (: (sqlite.sqlite3) :connect db-path))
    _ (-> (: (sqlite.sqlite3) :connect db-path)
          (doto (: :execute schema)))))

(λ query [db q]
  (let [query (: "SELECT distinct url, title FROM pages('%s');"
                 :format (db:escape q))
        cursor (assert (db:execute query))]
    #(cursor:fetch)))

(fn insert-sql [db url body title crawled-at source]
  (: "INSERT INTO pages VALUES ('%s', '%s', '%s', '%s', '%s');" :format
     (db:escape url) (db:escape (or title url)) (db:escape body)
     (db:escape source) (db:escape crawled-at)))

(λ insert-page [db url {: body : title : crawled-at : source}]
  (assert (db:execute (insert-sql db url body title crawled-at source))))

{: init : query : insert-page}
