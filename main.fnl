(local fennel (require :fennel))
(local moonmint (require :moonmint))
(local capabilities (require :capabilities))
(local https (require :https))
(local luv (require :luv))

(set debug.traceback fennel.traceback)

(local dbg (if (os.getenv "DEBUG") print #nil))
(local log (if (os.getenv "SILENT") #nil print))
(local slow? (os.getenv "SLOW"))
(local db-path (or (os.getenv "DB_PATH") "data.db"))

(local caps (capabilities.for _G {:os {:time os.time :tmpname os.tmpname
                                       :exit [0 1]}
                                  :io {:open {:write ["/tmp/"]
                                              :read [db-path "*.txt" "sql/"
                                                     "static/why.html" "/tmp/"]}
                                       :write io.write :flush io.flush
                                       :stdin io.stdin :lines io.lines
                                       :popen ["pandoc"]}}
                              {: dbg : log : moonmint
                               :sleep #(os.execute "sleep 1")
                               :json (require :dkjson)
                               :robotstxt (require :robotstxt)
                               :sqlite (require :luasql.sqlite3)}))

(set _G.caps caps) ; for repl

(local env (setmetatable {: caps} {:__index _G})) ; for repl
(local arg _G.arg)
(local _ENV (capabilities.env))

;; these run in the sandbox
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))

(set caps.db (sql.init caps db-path))
(set caps.request (let [{: get : user-agent} (require :request)]
                    {:get (partial get https) : user-agent}))

(fn read-chunk []
  (caps.io.write ">> ")
  (caps.io.flush)
  (case (coroutine.yield)
    input (.. input "\n")
    nil (caps.os.exit 0)))

(fn start [port]
  (let [router (moonmint.router)]
    (set caps.sources (caps.db:sources))
    ;; can't use partial here because it would prevent reloads
    (router:get "/" #(responses.home caps $))
    (router:get "/q" #(responses.search caps $))
    ;; in case you don't want to mess with content-accept
    (router:get "/q.json" #(responses.search-json caps $))
    (router:get "/why" #(responses.snippet caps "static/why.html"))
    (router:get "/about" #(moonmint.response.redirect "/why"))
    (router:get "/opensearch.xml" #(moonmint.response.file
                                    "static/opensearch.xml"))
    (router:get "/favicon.ico" #(moonmint.response.file
                                 "static/favicon.ico"))
    (router:get "/robots.txt" #(moonmint.response.file
                                "static/robots.txt"))
    (-> (moonmint)
        (: :use router)
        (: :start {: port}))))

(case arg
  ["index" url-file source] (index.index caps url-file source slow?)
  ["add-remote" url name home ?desc] (caps.db:add-remote url name home ?desc)
  ["repl" port] (let [repl (coroutine.create (partial fennel.repl))
                      stdin (luv.new_tty 0 true)]
                  (coroutine.resume repl {:readChunk read-chunk : env
                                          :allowedGlobals false})
                  (start port)
    (luv.read_start stdin #(coroutine.resume repl $2)))
  ["start" port] (start port)
  _ (do (print "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE SOURCE_NAME
fennel main.fnl add-remote URL NAME HOME [DESCRIPTION]")
        (caps.os.exit 1)))
