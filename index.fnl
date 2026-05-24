(local stale-time 604800) ; 1 week
(local robotstxt (require :robotstxt))
(local dbg (or _G.dbg #nil))

(local _fennel (require :fennel))

(fn needs-refresh? [db url now]
  (case (db.pages.refresh url)
    {: crawled_at} (< (tonumber crawled_at) (- now stale-time))
    _ :new))

(local pandoc-cmd "pandoc -s -f html -t markdown --sandbox %q")

(local robots-domains {})

(fn get-robots [request prefix]
  (case (request.get (.. prefix "/robots.txt"))
    {:status 200 : body} (let [lines (icollect [l (body:gmatch "([^\n]+)")] l)
                               r (robotstxt.load_table lines)]
                           (r:set_agent request.user-agent)
                           (set (. robots-domains prefix) r))
    _ true))

(fn allowed? [request url]
  (let [[prefix path] [(url:match "^(https?://[^/]+)(.*)")]]
    (case (. robots-domains prefix)
      r (doto (r:check_allowed path)
          (dbg :allowed? url))
      _ (or (get-robots request prefix)
            (allowed? request url)))))

(fn html->text [io tmp]
  (with-open [pandoc (assert (io.popen (pandoc-cmd:format tmp)))]
    (pandoc:read :*all)))

(fn normalize-type [content-type]
  (if (content-type:find "html") :html
      (content-type:find "text") :text))

(fn index-body [io log body content-type tmp db url now source]
  (case (and content-type (normalize-type (content-type:lower)))
    :text (do (db.pages.insert url url body source now)
              (log :indexed-text url))
    :html (let [_ (with-open [f (io.open tmp :w)] (f:write body))
                body (html->text io tmp)
                metadata (body:match "---(.*)---") ; pandoc gives us metadata
                title (and metadata (metadata:match "\ntitle: ([^\n]*)"))]
            (db.pages.insert url (or title url) body source now)
            (log :indexed url))
    _ (log :not-indexable url content-type)))

;; TODO: keep trarck of dead/blocked domains
(fn indexable? [url] (not (or (url:find "%.mp4$") (url:find "%.webm$")
                              (url:find "%.jpe?g$") (url:find "%.gif$")
                              (url:find "^https://youtu%.?be")
                              (url:find "^https://www%.youtu%.?be"))))

(fn index-url [{: io : db : log : request} url tmp now source]
  (dbg :indexing url)
  (let [refresh? (needs-refresh? db url now)]
    (when (and refresh? (allowed? request url) (indexable? url))
      (when (not= refresh? :new)
        (db.pages.delete url))
      ;; TODO: check content-type; skip non-textual
      (case (request.get url)
        {:status 200 : body : headers} (index-body io log body
                                                   (headers:get "content-type")
                                                   tmp db url now source)
        {: status} (dbg :fail status)))))

(λ index [{: os : sleep : io &as caps}
          url-file source ?slowly?]
  (each [line (io.lines url-file)]
    (let [url (line:match "([^ #]+)")
          tmp (os.tmpname)]
      (case (pcall index-url caps url tmp (os.time) source)
        (false msg) (print :ERR url msg))
      (when ?slowly?
        (sleep)))))

{: index}
