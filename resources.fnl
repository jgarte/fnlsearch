(macro resources [paths]
  (collect [_ path (ipairs paths)]
    path (with-open [f (assert (io.open path))] (f:read :*all))))

(resources ["sql/add-remote.sql"
            "sql/delete.sql"
            "sql/insert.sql"
            "sql/refresh.sql"
            "sql/remotes.sql"
            "sql/schema.sql"
            "sql/search-source.sql"
            "sql/search.sql"
            "sql/sources.sql"
            "static/favicon.ico"
            "static/opensearch.xml"
            "static/robots.txt"
            "static/why.html"])
