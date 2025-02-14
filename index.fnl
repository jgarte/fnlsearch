(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

(local stale-time 604800) ; 1 week

(fn needs-refresh? [db url now]
  (case (db:refresh url)
    crawled-at (< (tonumber crawled-at) (- now stale-time))
    _ true))

(local pandoc-cmd (.. "pandoc -s -f html -t markdown "
                      "--request-header User-Agent:\"%s\" %q"))

(local robots-domains {})

(fn get-robots [request robotstxt prefix]
  (case (request.get (.. prefix "/robots.txt"))
    {:status 200 : body} (let [lines (icollect [l (body:gmatch "([^\n]+)")] l)
                               r (robotstxt.load_table lines)]
                           (r:set_agent user-agent)
                           (set (. robots-domains prefix) r))
    _ true))

(fn allowed? [request robotstxt dbg url]
  (let [[prefix path] [(url:match "^(https?://[^/]+)(.*)")]]
    (case (. robots-domains prefix)
      r (doto (r:check_allowed path)
          (dbg :allowed? url))
      _ (or (get-robots request robotstxt prefix)
            (allowed? request robotstxt dbg url)))))

(fn html->text [io tmp]
  (with-open [pandoc (assert (io.popen (pandoc-cmd:format user-agent tmp)))]
    (pandoc:read :*all)))

(fn normalize-type [content-type]
  (if (content-type:find "html") :html
      (content-type:find "text") :text))

(fn extract-metadata [body source] ; pandoc gives us a metadata header
  (let [metadata (body:match "---(.*)---")
        title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
    {: title : body : source}))

(fn index-body [io log body {: content-type} tmp db url now source]
  (case (and content-type (normalize-type (content-type:lower)))
    :text (do (db:insert url now {:title url : body : source})
              (log :indexed-text url))
    :html (do (with-open [f (io.open tmp :w)] (f:write body))
              (db:insert url now (extract-metadata (html->text io tmp) source))
              (log :indexed url))
    _ (log :not-indexable url content-type)))

(fn indexable? [url] (not (or (url:find "%.mp4$") (url:find "%.webm$"))))

(fn index-url [{: io : db : log : dbg : request : robotstxt} url tmp now source]
  (dbg :indexing url)
  (when (and (needs-refresh? db url now) (allowed? request robotstxt dbg url)
             (indexable? url))
    (case (request.get url)
      {:status 200 : body : headers} (index-body io log body headers
                                                 tmp db url now source)
      {: status} (dbg :fail status))))

(λ index [{: os : sleep : io &as caps}
          url-file source ?slowly?]
  (each [line (io.lines url-file)]
    (let [url (line:match "([^ #]+)")
          tmp (os.tmpname)]
      (index-url caps url tmp (os.time) source)
      (when ?slowly?
        (sleep)))))

{: index}
