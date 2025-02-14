(λ read [io path] (with-open [f (assert (io.open path))] (f:read :*all)))

(λ open [io sqlite db-path]
  (case (io.open db-path)
    f (do (f:close) (: (sqlite.sqlite3) :connect db-path))
    _ (let [schema (read io "sql/schema.sql")]
        (-> (: (sqlite.sqlite3) :connect db-path)
            (doto (: :execute schema))))))

(fn sanitize [q]
  ;; way overly paranoid but yeah, whatever; good enough for now
  (q:gsub "[^a-zA-Z0-9]+" " "))

(λ search [{: conn : queries} q]
  (let [query (queries.search:format (conn:escape (sanitize (tostring q))))
        cursor (assert (conn:execute query))]
    #(cursor:fetch)))

(λ refresh [{: conn : queries} url]
  (let [query (queries.refresh:format (conn:escape url))
        cursor (assert (conn:execute query))]
    (cursor:fetch)))

(fn insert-sql [{: conn : queries} url body title crawled-at source]
  (queries.insert:format (conn:escape url) (conn:escape (or title url))
                         (conn:escape body) (conn:escape source)
                         (conn:escape crawled-at)))

(λ insert [db url crawled-at {: body :title ?title : source}]
  (assert (db.conn:execute (insert-sql db url body ?title crawled-at source))))

(λ init [{: io : sqlite} db-path]
  {:conn (open io sqlite db-path) : search : insert : refresh
   :queries (collect [_ name (ipairs [:insert :search :refresh])]
              name (read io (string.format "sql/%s.sql" name)))})

{: init}
