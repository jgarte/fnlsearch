;; account-id 01G4Z3A1V3F77HEWC8RMZ4EWDD

(fn urls-for [db query]
  (let [cursor (assert (db:execute query))
        out []]
    (each [content #(cursor:fetch)]
      (collect [url (content:gmatch "https://[^%s\"<#)]+") &into out] url true))
    out))

(local status-query (.. "select content from statuses s join accounts a"
                        " on s.account_id = a.id where a.username = '%s'"
                        " and domain is null and content like '%%https%%'"
                        " and visibility = 2"))

(fn statuses [sqlite db-path username]
  (let [db (: (sqlite.sqlite3) :connect db-path)]
    (urls-for db (status-query:format (db:escape username)))))

(local boosts-query (.. "select s.content from statuses b join accounts a"
                        " on b.account_id = a.id join statuses s"
                        " on b.boost_of_id = s.id"
                        " where a.username = '%s' and b.visibility = 2"
                        " and domain is null and s.content like '%%https%%';"))

(fn boosts [sqlite db-path username]
  (let [db (: (sqlite.sqlite3) :connect db-path)]
    (urls-for db (boosts-query:format (db:escape username)))))

{: statuses : boosts}
