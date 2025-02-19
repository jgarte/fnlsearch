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

(fn read [path] (with-open [f (io.open path)] (f:read :*all)))

(local caps (capabilities.for _G {:os {:time os.time :tmpname os.tmpname
                                       :exit [0 1]}
                                  :io {:open {:write ["/tmp/"]
                                              :read [db-path "*.txt"
                                                     "sql/" "/tmp/"]}
                                       :write io.write :flush io.flush
                                       :stdin io.stdin :lines io.lines
                                       :popen ["pandoc"]}}
                              {: dbg : log : moonmint
                               :static {:opensearch (read "static/opensearch.xml")
                                        :why (read "static/why.html")
                                        :favicon (read "static/favicon.ico")}
                               :sleep #(os.execute "sleep 1")
                               :json (require :dkjson)
                               :robotstxt (require :robotstxt)
                               :sqlite (require :luasql.sqlite3)}))

(set _G.caps caps)

(local env (setmetatable {: caps} {:__index _G})) ; for repl
(local arg _G.arg)
(local _ENV (capabilities.env))

;; these run in the sandbox
(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))

(set caps.db (sql.init caps db-path))
(set caps.request {:get (partial (. (require :request) :get) https)})

(fn read-chunk []
  (caps.io.write ">> ")
  (caps.io.flush)
  (case (coroutine.yield)
    input (.. input "\n")
    nil (caps.os.exit 0)))

(case arg
  ["index" url-file source] (index.index caps url-file source slow?)
  ["start" port] (let [router (moonmint.router)
                       repl (coroutine.create (partial fennel.repl))
                       stdin (luv.new_tty 0 true)]
                   (coroutine.resume repl {:readChunk read-chunk : env
                                           :allowedGlobals false})
                   (luv.read_start stdin #(coroutine.resume repl $2))
                   (set caps.sources (caps.db:sources))
                   ;; can't use partial here because it would prevent reloads
                   (router:get "/" #(responses.home caps $))
                   (router:get "/q" #(responses.search caps $))
                   (router:get "/why" #(responses.snippet caps :why))
                   (router:get "/about" #(moonmint.response.redirect "/why"))
                   (router:get "/opensearch.xml" #(responses.static
                                                   caps :opensearch "text/xml"))
                   (router:get "/favicon.ico" #(responses.static
                                                caps :favicon "image/x-icon"))
                   (router:get "/robots.txt" #(responses.robots caps))
                   (-> (moonmint)
                       (: :use router)
                       (: :start {: port})))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE SOURCE_NAME\n")
        (os.exit 1)))
