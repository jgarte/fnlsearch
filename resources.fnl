(macro resources [paths]
  (collect [_ path (ipairs paths)]
    path (with-open [f (assert (io.open path))] (f:read :*all))))

(fn __call [self path] (assert (. self path) (.. "resource not found: " path)))

(setmetatable (resources ["sql/search.sql"
                          "sql/remotes/add.sql"
                          "sql/remotes/list.sql"
                          "sql/pages/insert.sql"
                          "sql/pages/delete.sql"
                          "sql/pages/refresh.sql"
                          "sql/pages/sources.sql"
                          "sql/migrations/pages.sql"
                          "sql/migrations/remotes.sql"
                          "static/favicon.ico"
                          "static/opensearch.xml"
                          "static/robots.txt"
                          "static/why.html"])
              {: __call})
