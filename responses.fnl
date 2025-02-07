(local layout (require :layout))

(local form [:form {:action "/q" :method "GET"}
             [:input {:type "text" :name "q" :placeholder "query"}]
             [:input {:type "submit" :value "search"}]])

(fn home [{: moonmint} _req]
  (moonmint.response (layout.layout form)))

(fn reload [{: moonmint : hotswap} _req]
  (hotswap :search)
  (moonmint.response.redirect "/"))

(fn search [{: db : log : moonmint} {: rawQuery}]
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

(fn robots [{: moonmint}]
  (moonmint.response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

{: home : robots : search : reload}
