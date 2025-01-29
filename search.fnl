(local robots (require :robotstxt))
(local log (if (os.getenv "DEBUG") print #nil))
(local sql (require :sql))

(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

(λ results [db-path q]
  (icollect [url title (sql.query (sql.init db-path) q)]
    [url title]))

(fn extract-metadata [body now] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {:crawled-at now : title : body :source "bookmarks"}))

(local stale-time 604800) ; 1 week

(fn needs-refresh? [db url now]
  (let [query (: "SELECT crawled_at FROM pages WHERE url = '%s'"
                 :format (db:escape url))
        cursor (assert (db:execute query))]
    (case (cursor:fetch)
      crawled-at (< (tonumber crawled-at) (- now stale-time))
      _ true)))

(local pandoc-cmd (.. "pandoc -s -f html -t markdown "
                      "--request-header User-Agent:\"%s\" %q"))

;; pointing pandoc to a webm does NOT go well (just hangs forever)
(fn skip? [url] (or (url:find "%.webm$") (url:find "%.mp[34]$")))

(local robots-domains {})

(fn allowed? [url]
  (let [[prefix path] [(url:match "^(https?://[^/]+)(.*)")]]
    (case (. robots-domains prefix)
      r (doto (r:check_allowed path)
          (log :allowed?))
      _ (let [r (robots.load_stream (io.popen (.. "curl -s " prefix "/robots.txt")))]
          (r:set_agent user-agent)
          (set (. robots-domains prefix) r)
          (allowed? url)))))

(fn index-url [db url now]
  (when (and (needs-refresh? db url now)
             (not (skip? url))
             (allowed? url))
    (log :GET url)
    ;; TODO: error handling
    (with-open [pandoc (assert (io.popen (pandoc-cmd:format user-agent url)))]
      (sql.insert-page db url (extract-metadata (pandoc:read :*all) now)))))

(λ index [file db-path now ?slowly?]
  (let [db (sql.init db-path)]
    (each [line (io.lines file)]
      (let [url (line:match "([^ ]+)")]
        (index-url db url now)
        (when ?slowly?
          (os.execute "sleep 1"))))))

{: results : index}
