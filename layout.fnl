(local {: html} (require :html))

(fn layout [...]
  (.. "<!DOCTYPE html>\n"
      (html [:html {:lang "en"}
             [:head {}
              [:meta {:charset "UTF-8"}]
              [:style {}
               "body{margin:40px
      auto;max-width:650px;line-height:1.6;font-size:18px;color:#444;padding:0
      10px}h1,h2,h3{line-height:1.2}"]
              [:title {} "technomancy search"]]
             [:body {}
              [:h1 {} "technomancy search"]
              [:div {:id "contents"} ...]
              [:footer {}
               [:p {} "site © 2025 Phil Hagelberg | "
                [:a {:href "https://git.sr.ht/~technomancy/search"}
                 "source"]]]]])))

{: layout}
