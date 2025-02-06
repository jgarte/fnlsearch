(local lume (require :lume))
(local layout (require :layout))
(local moonmint (require :moonmint))

(local form [:form {:action "/q" :method "GET"}
             [:input {:type "text" :name "q" :placeholder "query"}]
             [:input {:type "submit" :value "search"}]])

(fn home [_caps _req]
  (moonmint.response (layout.layout form)))

(fn reload [_caps _req]
  (lume.hotswap :search)
  (moonmint.response.redirect "/"))

(fn search [{: db : log} {: rawQuery}]
  (let [{: q} (moonmint.url.queryDecode rawQuery)
        _ (assert (and q (not= q "")) "query not found")
        results (icollect [url title (db:search q)]
                  [url title])
        html (layout.layout [:p {} "Results for" [:kbd {} q]]
                            (if (next results)
                                (icollect [_ [url title] (ipairs results)
                                           &into [:ul {}]]
                                  [:li {} [:a {:href url} title]])
                                [:p {} "Not found."])
                            form
                            [:p {} [:a {:href "/"} "home"]])]
    (log :Q q)
    (moonmint.response html)))

(fn robots [_caps]
  (moonmint.response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

{: home : robots : search : reload}
