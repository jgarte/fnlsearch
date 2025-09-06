(local fennel (require :fennel))
(local capabilities (require :capabilities))
(local request (require :request))
(local http-server (require :http.server))
(local http-headers (require :http.headers))
(local http-util (require :http.util))

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
                                              :read [db-path "/tmp/"]}
                                       :write io.write :flush io.flush
                                       :stdin io.stdin :lines io.lines
                                       :popen ["pandoc"]}}
                              {: dbg : log : request : resource
                               :sleep #(os.execute "sleep 1")
                               :robotstxt (require :robotstxt)
                               :sqlite (require :luasql.sqlite3)}))

(set _G.caps caps) ; for repl

(local arg _G.arg)
(local _ENV (capabilities.env))

;; these run in the sandbox
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))

(set caps.db (sql.init caps db-path))

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

(fn start [port]
  (set caps.sources (caps.db:sources))
  (let [server (assert (http-server.listen {:host "localhost"
                                            : port : onstream}))]
    (assert (server:listen))
    (assert (server:loop))))

(case arg
  ["index" url-file source] (index.index caps url-file source slow?)
  ["add-remote" url name home ?desc] (caps.db:add-remote url name home ?desc)
  ["start" port] (start port)
  _ (do (print "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE SOURCE_NAME
fennel main.fnl add-remote URL NAME HOME [DESCRIPTION]")
        (caps.os.exit 1)))
