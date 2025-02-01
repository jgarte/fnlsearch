(local moonmint (require :moonmint))
(local robots (require :robotstxt))
(local log (if (os.getenv "DEBUG") print #nil))

(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

(fn extract-metadata [body now] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {:crawled-at now : title : body :source "bookmarks"}))

(local stale-time 604800) ; 1 week

(fn needs-refresh? [db url now]
  (case (db:refresh url)
    crawled-at (< (tonumber crawled-at) (- now stale-time))
    _ true))

(local pandoc-cmd (.. "pandoc -s -f html -t markdown "
                      "--request-header User-Agent:\"%s\" %q"))

;; pointing pandoc to a webm does NOT go well (just hangs forever)
(fn skip? [url] (or (url:find "%.webm$") (url:find "%.mp[34]$")))

(local robots-domains {})

(fn get-robots [prefix]
  (case (: (moonmint.agent.get (.. prefix "/robots.txt")) :sendSync)
    nil false
    {:code 200 : body} (let [lines (icollect [l (body:gmatch "([^\n]+)")] l)
                             r (robots.load_table lines)]
                         (r:set_agent user-agent)
                         (set (. robots-domains prefix) r))))

(fn allowed? [url]
  (let [[prefix path] [(url:match "^(https?://[^/]+)(.*)")]]
    (case (. robots-domains prefix)
      r (doto (r:check_allowed path)
          (log :allowed?))
      _ (do (get-robots prefix)
            (allowed? url)))))

(fn convert-and-save [body tmp db url now]
  ;; this is tacky; could we use luv here to stream from HTTP -> pandoc?
  (with-open [f (io.open tmp :w)] (f:write body))
  (with-open [pandoc (assert (io.popen (pandoc-cmd:format user-agent tmp)))]
    (db:insert url (extract-metadata (pandoc:read :*all) now)))
  (log :indexed url))

(fn index-url [db url tmp now]
  (when (and (needs-refresh? db url now)
             (not (skip? url))
             (allowed? url))
    (case (: (moonmint.agent.get url) :sendSync)
      {:code 200 : body} (convert-and-save body tmp db url now)
      {: code} (log :fail code))))

(λ index [{: db : os} url-file ?slowly?]
  (each [line (io.lines url-file)]
    (let [url (line:match "([^ ]+)")
          tmp (os.tmpname)]
      (index-url db url tmp (os.time))
      (when ?slowly?
        (os.execute "sleep 1")))))

{: index}
