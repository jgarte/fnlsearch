(local lume (require :lume))
(local moonmint (require :moonmint))
(local router ((require :moonmint.router)))
(local response (require :moonmint.response))
(local url (require :moonmint.url))

(local layout (require :layout))
(local search (require :search))

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
    (response (layout.layout [:p {} "Results"]
                             (icollect [_ r (ipairs (search.results query))
                                        &into [:ul {}]]
                               [:li {} r])
                             form
                             [:p {}
                              [:a {:href "/"} "home"]]))))

(router:get "/" home)
(router:get "/q" search-html)
(router:get "/reload" reload)

(case arg
  ["index" file] (search.index file (os.time))
  ["start" port] (-> (moonmint)
                     (: :use router)
                     (: :start {: port}))
  _ (do (io.stderr:write "USAGE:
fennel main.fnl start PORT
fennel main.fnl index URL_FILE\n")
        (os.exit 1)))
