(local sqlite (require :luasql.sqlite3))

(local status-query (.. "select content from statuses s join accounts a"
                        " on s.account_id = a.id where a.username = '%s'"
                        " and domain is null and content like '%%https%%';"))

(fn urls [db-path username]
  (let [db (: (sqlite.sqlite3) :connect db-path)
        query (status-query:format (db:escape username))
        cursor (assert (db:execute query))
        out []]
    (each [content #(cursor:fetch)]
      (collect [url (content:gmatch "https://[^%s\"<#]+") &into out] url true))
    out))

{: urls}
