(local fennel (require :fennel))
(local lume (require :lume))
(local moonmint (require :moonmint))
(local router ((require :moonmint.router)))
(local response (require :moonmint.response))
(local url (require :moonmint.url))

(local layout (require :layout))
(local search (require :search))
(local gts (require :gts))

(set debug.traceback fennel.traceback)

(local form [:form {:action "/q" :method "GET"}
             [:input {:type "text" :name "q" :placeholder "query"}]
             [:input {:type "submit" :value "search"}]])

(fn home [_req]
  (response (layout.layout form)))

(fn reload [_req]
  (lume.hotswap :search)
  (response.redirect "/"))

(fn search-html [{: rawQuery}]
  (let [query (url.queryDecode rawQuery)]
    (print :Q query.q)
    (response (layout.layout [:p {} "Results for" [:kbd {} query.q]]
                             (icollect [_ r (ipairs (search.results query))
                                        &into [:ul {}]]
                               [:li {} r])
                             form
                             [:p {} [:a {:href "/"} "home"]]))))

(fn robots [] (response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

(router:get "/" home)
(router:get "/q" search-html)
(router:get "/reload" reload)
(router:get "/robots.txt" robots)
(router:get "/error" (fn [] (error "oh no")))

(case arg
  ["index" file] (search.index file (os.time))
  ["gts" db-path username] (each [url (pairs (gts.urls db-path username))]
                             (print url))
  ["start" port] (-> (moonmint)
                     (: :use router)
                     (: :start {: port}))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE\n")
        (os.exit 1)))
