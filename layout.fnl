(local {: html} (require :html))

(fn layout [...]
  (html [:html {:lang "en"}
         [:head {}
          [:meta {:charset "UTF-8"}]
          [:style {:type "text/css"}
           "body{margin:40px
      auto;max-width:650px;line-height:1.6;font-size:18px;color:#444;padding:0
      10px}h1,h2,h3{line-height:1.2}"]
          [:title {} "technomancy search"]]
         [:body {}
          [:h1 {} "technomancy search"]
          [:div {:id "contents"} ...]
          [:footer {}
           [:p {} "site © 2025 Phil Hagelberg, contents of search results "
            "are copyright their authors"]
           [:p {} [:a {:href "https://git.sr.ht/~technomancy/search"}
                   "site source"]]]]]))

{: layout}
