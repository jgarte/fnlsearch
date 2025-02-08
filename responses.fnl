(local {: html : unescaped} (require :html))

(fn layout [...]
  (.. "<!DOCTYPE html>\n"
      (html [:html {:lang "en"}
             [:head {}
              [:meta {:charset "UTF-8"}]
              [:style {}
               "body{margin:40px auto;max-width:650px;line-height:1.6;
font-size:18px;color:#444;padding:0 10px}h1,h2,h3{line-height:1.2}"]
              [:title {} "technomancy search"]]
             [:body {}
              [:h1 {} "technomancy search"]
              [:div {:id "contents"} ...]
              [:footer {}
               [:p {} "site © 2025 Phil Hagelberg | "
                [:a {:href "/about"}
                 "about"] "|"
                [:a {:href "https://git.sr.ht/~technomancy/search"}
                 "source"]]]]] true)))

(local form [:form {:action "/q" :method "GET"}
             [:input {:type "text" :name "q" :placeholder "query"}]
             [:input {:type "submit" :value "search"}]])

(fn home [{: moonmint} _req]
  (moonmint.response (layout form)))

(fn about [{: moonmint : io} _req]
  (moonmint.response (layout (unescaped (with-open [f (io.open "about.html")]
                                          (f:read :*all))))))

(fn search [{: db : log : moonmint} {: rawQuery}]
  (let [{: q} (moonmint.url.queryDecode rawQuery)
        _ (assert (and q (not= q "")) "query not found")
        results (icollect [url title (db:search q)]
                  [url title])
        html (layout [:p {} "Results for" [:kbd {} q]]
                     (if (next results)
                         (icollect [_ [url title] (ipairs results)
                                    &into [:ul {}]]
                           [:li {}
                            [:a {:href url}
                             (pick-values 1 (title:gsub "\\([,!|\"])" "%1"))]])
                         [:p {} "Not found."])
                     form
                     [:p {} [:a {:href "/"} "home"]])]
    (log :Q q)
    (moonmint.response html)))

(fn robots [{: moonmint}]
  (moonmint.response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

{: home : robots : search : about}
