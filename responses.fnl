(local {: html : unescaped} (require :html))

(local title "technomancy search")

(fn layout [...]
  (.. "<!DOCTYPE html>\n"
      (html [:html {:lang "en"}
             [:head {}
              [:meta {:charset "UTF-8"}]
              [:link {:rel "search" : title :href "/opensearch.xml"
                      :type "application/opensearchdescription+xml"}]
              [:style {}
               "body{margin:40px auto;max-width:650px;line-height:1.6;
font-size:18px;color:#444;padding:0 10px}h1,h2,h3{line-height:1.2}"]
              [:title {} title]]
             [:body {}
              [:h1 {} title]
              [:div {:id "contents"} ...]
              [:footer {}
               [:p {} "site © 2025 Phil Hagelberg | "
                [:a {:href "/"} "home"] "|"
                [:a {:href "/why"} "why"] "|"
                [:a {:href "https://git.sr.ht/~technomancy/search"}
                 "source"]]]]] true)))

(fn form [sources]
  [:form {:action "/q" :method "GET"}
   [:input {:type "text" :name "q" :placeholder "query"}]
   [:input {:type "submit" :value "search"}]
   (if (. sources 2)
       [:details {} [:summary {} "sources"]
        (icollect [_ source (ipairs sources)
                   &into [:ul {}]]
          [:li {} [:label {}
                   [:input {:name "source" :type "checkbox" :value source
                            :checked :checked}]
                   source]])])])

(λ home [{: moonmint : sources} _req]
  (moonmint.response (layout (form sources))))

(λ search [{: db : log : sources : moonmint} {: rawQuery}]
  (let [{: q : source} (moonmint.url.queryDecodeMulti rawQuery)
        q (if q (. q 1))
        results (if (and q (not= q ""))
                    (icollect [url title (db:search q source)
                               &into [:ul {}]]
                      [:li {}
                       [:a {:href url}
                        (pick-values 1 (title:gsub "\\([,%?!|\"])" "%1"))]]))
        html (layout [:p {} "Results for" [:kbd {} q]]
                     (if (and results (. results 3))
                         results
                         [:p {} "Not found."])
                     (form sources))]
    (log :Q q)
    (moonmint.response html)))

(λ robots [{: moonmint} _req]
  (moonmint.response "user-agent: *\ndisallow: /q" 200 "text/plain\n"))

(λ snippet [{: moonmint : static} name _req]
  (moonmint.response (layout (unescaped (. static name)))))

(λ static [{: moonmint : static} file content-type _req]
  (moonmint.response (. static file) 200 content-type))

{: home : robots : search : snippet : static}
