(local robots (require :robotstxt))
(local log (if (os.getenv "DEBUG") print #nil))
(local request (require :request))

(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

(local stale-time 604800) ; 1 week

(fn needs-refresh? [db url now]
  (case (db:refresh url)
    crawled-at (< (tonumber crawled-at) (- now stale-time))
    _ true))

(local pandoc-cmd (.. "pandoc -s -f html -t markdown "
                      "--request-header User-Agent:\"%s\" %q"))

(local robots-domains {})

(fn get-robots [prefix]
  (case (request.get (.. prefix "/robots.txt"))
    nil false
    {:status 200 : body} (let [lines (icollect [l (body:gmatch "([^\n]+)")] l)
                               r (robots.load_table lines)]
                           (r:set_agent user-agent)
                           (set (. robots-domains prefix) r))))

(fn allowed? [url]
  (let [[prefix path] [(url:match "^(https?://[^/]+)(.*)")]]
    (case (. robots-domains prefix)
      r (doto (r:check_allowed path)
          (log :allowed? url))
      _ (do (get-robots prefix)
            (allowed? url)))))

(fn html->text [tmp]
  (with-open [pandoc (assert (io.popen (pandoc-cmd:format user-agent tmp)))]
    (pandoc:read :*all)))

(fn normalize-type [content-type]
  (if (content-type:find "html") :html
      (content-type:find "text") :text))

(fn extract-metadata [body source] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {: title : body : source}))

(fn index-body [body {: content-type} tmp db url now source]
  (case (and content-type (normalize-type (content-type:lower)))
    :text (do (db:insert url now {:title url : body : source})
              (log :indexed-text url))
    :html (do ; tacky; can we go straight from HTTP -> pandoc?
            (with-open [f (io.open tmp :w)] (f:write body))
            (db:insert url now (extract-metadata (html->text tmp) source))
            (log :indexed url))
    _ (log :skipped url content-type)))

(fn index-url [db url tmp now source]
  (when (and (needs-refresh? db url now) (allowed? url))
    (case (request.get url)
      {:status 200 : body : headers} (index-body body headers tmp db url now source)
      {: status} (log :fail status))))

(λ index [{: db : os} url-file source ?slowly?]
  (each [line (io.lines url-file)]
    (let [url (line:match "([^ ]+)")
          tmp (os.tmpname)]
      (index-url db url tmp (os.time) source)
      (when ?slowly?
        (os.execute "sleep 1")))))

{: index}
