(λ read [io path] (with-open [f (assert (io.open path))] (f:read :*all)))

(λ open [io sqlite db-path]
  (case (io.open db-path)
    f (do (f:close) (: (sqlite.sqlite3) :connect db-path))
    _ (let [schema (read io "sql/schema.sql")
            db (: (sqlite.sqlite3) :connect db-path)]
        (each [table (schema:gmatch "[^;]+")]
          (db:execute table))
        db)))

(fn sanitize [q]
  ;; way overly paranoid but yeah, whatever; good enough for now
  (q:gsub "[^a-zA-Z0-9/]+" " "))

(fn source->sql [source]
  ;; we've already validated that every source name must exist by this point
  (table.concat (icollect [_ {: name} (ipairs source)] (.. "'" name "'")) ","))

(λ search [{: conn : queries} q ?source]
  (let [query (if ?source
                  (queries.search-source:format (conn:escape (sanitize q))
                                                (source->sql ?source))
                  (queries.search:format (conn:escape (sanitize q))))
        cursor (assert (conn:execute query))]
    #(cursor:fetch)))

(λ sources [{: conn : queries}]
  (let [cursor (assert (conn:execute queries.sources))
        remotes-cursor (assert (conn:execute queries.remotes))
        out []]
    (icollect [s #(cursor:fetch) &into out] {:name s})
    (icollect [url name home description #(remotes-cursor:fetch)
               &into out]
      {: name : url : home : description})))

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

(λ add-remote [{: conn : queries} url name home description]
  (assert (conn:execute
           (queries.add-remote:format (conn:escape url)
                                      (conn:escape name)
                                      (conn:escape home)
                                      (conn:escape description)))))

(λ init [{: io : sqlite} db-path]
  {:conn (open io sqlite db-path)
   : search : insert : refresh : sources : add-remote
   :queries (collect [_ name (ipairs [:insert :search :refresh
                                      :sources :search-source
                                      :remotes :add-remote])]
              name (read io (string.format "sql/%s.sql" name)))})

{: init}
