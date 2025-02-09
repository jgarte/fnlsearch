(local fennel (require :fennel))
(local moonmint (require :moonmint))
(local capabilities (require :capabilities))
(local https (require :https))
(local luv (require :luv))

(set debug.traceback fennel.traceback)

(local dbg (if (os.getenv "DEBUG") print #nil))
(local log (if (os.getenv "SILENT") #nil print))
(local slow? (os.getenv "SLOW"))

(fn read [path] (with-open [f (io.open path)] (f:read :*all)))

(local caps (capabilities.for _G {:os {:time os.time :tmpname os.tmpname
                                       :exit [0 1]}
                                  :io {:open {:write ["/tmp/"]
                                              :read ["data.db" "*.txt" "about.html"
                                                     "sql/" "/tmp/"]}
                                       :write io.write :flush io.flush
                                       :stdin io.stdin :lines io.lines
                                       :popen ["pandoc"]}}
                              {: dbg : log : moonmint
                               :static {:opensearch (read "static/opensearch.xml")
                                        :about (read "static/about.html")
                                        :favicon (read "static/favicon.ico")}
                               :sleep #(os.execute "sleep 1")
                               :robotstxt (require :robotstxt)
                               :sqlite (require :luasql.sqlite3)}))

(local arg _G.arg)

(local _ENV (capabilities.env))

(local index (require :index))
(local responses (require :responses))
(local sql (require :sql))

(set caps.db (sql.init caps "data.db"))
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
                   (coroutine.resume repl {:readChunk read-chunk})
                   (luv.read_start stdin #(coroutine.resume repl $2))
                   (router:get "/" (partial responses.home caps))
                   (router:get "/q" (partial responses.search caps))
                   (router:get "/about" (partial responses.about caps))
                   (router:get "/opensearch.xml" (partial responses.static caps
                                                          :opensearch "text/xml"))
                   (router:get "/favicon.ico" (partial responses.static caps
                                                       :favicon "image/x-icon"))
                   (router:get "/robots.txt" (partial responses.robots caps))
                   (-> (moonmint)
                       (: :use router)
                       (: :start {: port})))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE SOURCE_NAME\n")
        (os.exit 1)))
