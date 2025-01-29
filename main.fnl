(local fennel (require :fennel))
(local lume (require :lume))
(local moonmint (require :moonmint))
(local layout (require :layout))
(local search (require :search))
(local gts (require :gts))

(set debug.traceback fennel.traceback)

(local db-path "data.db")
(local form [:form {:action "/q" :method "GET"}
             [:input {:type "text" :name "q" :placeholder "query"}]
             [:input {:type "submit" :value "search"}]])

(fn home [_req]
  (moonmint.response (layout.layout form)))

(fn reload [_req]
  (lume.hotswap :search)
  (moonmint.response.redirect "/"))

(fn search-html [{: rawQuery}]
  (let [{: q} (moonmint.url.queryDecode rawQuery)
        _ (assert q "query not found")
        results (search.results db-path q)
        html (layout.layout [:p {} "Results for" [:kbd {} q]]
                            (if (next results)
                                (icollect [_ [url title] (ipairs results)
                                           &into [:ul {}]]
                                  [:li {} [:a {:href url} title]])
                                [:p {} "Not found."])
                            form
                            [:p {} [:a {:href "/"} "home"]])]
    (print :Q q)
    (moonmint.response html)))

(fn robots []
  (moonmint.response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

(local router (moonmint.router))

(router:get "/" home)
(router:get "/q" search-html)
(router:get "/reload" reload)
(router:get "/robots.txt" robots)

(case arg
  ["index" file] (search.index file db-path (os.time))
  ["gts" db-path username] (each [url (pairs (gts.urls db-path username))]
                             (print url))
  ["start" port] (-> (moonmint)
                     (: :use router)
                     (: :start {: port}))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE
fennel main.fnl gts GTS_SQLITE_DB USERNAME\n")
        (os.exit 1)))
