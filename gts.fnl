(fn bad-url? [url]
  (or (url:find "/tags/") (url:find "https://youtube.com")))

(fn add-urls [results urls]
  (each [_ {: content} (ipairs results)]
    (collect [url (content:gmatch "https://[^%s\"<#)]+") &into urls]
      (if (not (bad-url? url))
          (values url true)))))

(fn print-urls [lsqlite3 path username]
  (let [litehug (require :litehug)
        db (litehug.init path {:gts {:statuses :n :boosts :n}}
                         [] io lsqlite3)
        urls []]
    (add-urls (db.gts.statuses username) urls)
    (add-urls (db.gts.boosts username) urls)
    (each [url (pairs urls)]
      (print url))))

{: print-urls}
