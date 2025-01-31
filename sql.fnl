(local sqlite (require :luasql.sqlite3))

(λ read [path] (with-open [f (assert (io.open path))] (f:read :*all)))

(λ open [db-path]
  (case (io.open db-path)
    f (do (f:close) (: (sqlite.sqlite3) :connect db-path))
    _ (let [schema (read "sql/schema.sql")]
        (-> (: (sqlite.sqlite3) :connect db-path)
            (doto (: :execute schema))))))

(λ search [{: conn : queries} q]
  (let [query (queries.search:format (conn:escape q))
        cursor (assert (conn:execute query))]
    #(cursor:fetch)))

(fn insert-sql [{: conn : queries} url body title crawled-at source]
  (queries.insert:format (conn:escape url) (conn:escape (or title url))
                         (conn:escape body) (conn:escape source)
                         (conn:escape crawled-at)))

(λ insert [db url {: body : title : crawled-at : source}]
  (assert (db.conn:execute (insert-sql db url body title crawled-at source))))

(λ init [db-path ...]
  {:conn (open db-path) : search : insert
   :queries (collect [_ name (ipairs [...])]
              name (read (string.format "sql/%s.sql" name)))})

{: init}
