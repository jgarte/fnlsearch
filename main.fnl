(local fennel (require :fennel))
(local capabilities (require :capabilities))
(local request (require :request))
(local http-server (require :http.server))
(local http-headers (require :http.headers))
(local http-util (require :http.util))
(local lsqlite3 (require :lsqlite3))
(local cqueues (require :cqueues))
(local cqueues-socket (require :cqueues.socket))
(local lpeg (require :lpeg))

(set debug.traceback fennel.traceback)

(local dbg (if (os.getenv "DEBUG") print #nil))
(local log (if (os.getenv "SILENT") #nil print))
(local slow? (os.getenv "SLOW"))
(local db-path (or (os.getenv "DB_PATH") "data.db"))

(local resources (require :resources))
(fn resource [path] (. resources path))

(local caps (capabilities.for _G {:os {:time os.time :tmpname os.tmpname
                                       :exit [0 1]}
                                  :io {:open {:write ["/tmp/"]
                                              :read [db-path "/tmp/" "sql/"]}
                                       :write io.write :flush io.flush
                                       :stdin io.stdin :lines io.lines
                                       :popen ["pandoc"]}}
                              {: log : request : resource
                               :sleep #(os.execute "sleep 1")}))

(set _G.caps caps) ; for repl

(local arg _G.arg)
;; TODO: get rid of rawset
(local _ENV (capabilities.env {: setmetatable : getmetatable : dbg : rawset}
                              {: lpeg}))

;; these run in the sandbox
(local index (require :index))
(local responses (require :responses))

(set caps.db (fennel.dofile "db.fnl" {} db-path caps.io lsqlite3))

(fn parse-query [path]
  (case (path:match "^([^%?]+)%?(.*)")
    (path query) (values path (let [args {}]
                                (each [k v (http-util.query_args query)]
                                  (case (. args k)
                                    nil (tset args k [v])
                                    _ (table.insert (. args k) v)))
                                args))
    _ path))

(fn handle [stream]
  (let [req-headers (assert (stream:get_headers))]
    (case (parse-query (req-headers:get ":path"))
      "/" (responses.home caps)
      "/why" (responses.snippet caps "static/why.html")
      ("/q" q) (responses.search caps q)
      path (or (responses.static caps path)
               (responses.err 404 "not found")))))

(fn respond [stream response]
  (let [headers (http-headers.new)]
    (headers:append ":status" (tostring (or response.status 200)))
    (if response.headers
        (each [k v (pairs response.headers)]
          (headers:append k v))
        (headers:append "content-type" "text/html"))
    (stream:write_headers headers false)
    (if (= :string (type response))
        (stream:write_chunk response true)
        (stream:write_chunk response.body true))))

(fn onstream [_server stream]
  (case (pcall handle stream)
    (true response) (respond stream response)
    (_ msg) (respond stream (responses.err 500 msg))))

(fn repl [path]
  (print "repl on" path)
  ;; arbitrarily accept only a single connection instead of continuing to listen
  (let [client (if (= path "-")
                   (cqueues-socket.fdopen 0)
                   (: (cqueues-socket.listen {: path :unlink true}) :accept))]
    (fn onValues [xs]
      (client:write (table.concat xs "\t"))
      (client:write "\n"))
    (fn onError [errtype err]
      (client:write
       (case errtype
         "Runtime" (.. (fennel.traceback (tostring err) 4) "\n")
         _ (: "%s error: %s\n" :format errtype (tostring err)))))
    (fn readChunk []
      (client:write ">> ")
      (client:flush)
      (case (client:read)
        input (.. input "\n")
        nil (do (caps.db.close)
                (caps.os.exit 0))))
    (fennel.repl {: readChunk : onValues : onError
                  :allowedGlobals (icollect [n (pairs _ENV) &into [:caps]] n)
                  :env (setmetatable {: caps} {:__index _ENV})})))

(fn start [port ?repl-path]
  (set caps.sources (caps.db.pages.sources))
  (let [cq (cqueues.new)
        server (assert (http-server.listen {:host "localhost" : cq
                                            : port : onstream}))]
    (when ?repl-path
      (cq:wrap (partial repl ?repl-path)))
    (assert (server:listen))
    (assert (server:loop))))

(case arg
  ["index" url-file source] (index.index caps url-file source slow?)
  ["gts" path username] (let [gts (require :gts)]
                          (gts.print-urls caps.io lsqlite3 path username))
  ["start" port ?repl-path] (start port ?repl-path)
  _ (do (print "USAGE:
fennel main.fnl start PORT [REPL_SOCKET]
fennel main.fnl index URL_FILE SOURCE_NAME
fennel main.fnl gts PATH_TO_GTS_DB GTS_USERNAME > urls.txt")
        (caps.os.exit 1)))
