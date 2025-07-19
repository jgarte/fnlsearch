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

(fn source-selector [{: name : home : description}]
  [:li {} [:label {:title description}
           [:input {:name "source" :type "checkbox" :value name}]
           (if home
               [:a {:href home} name]
               name)]])

(fn form [sources]
  [:form {:action "/q" :method "GET"}
   [:input {:type "text" :name "q" :placeholder "query"}]
   [:input {:type "submit" :value "search"}]
   (if (. sources 2)
       [:details {:id "sources"}
        [:summary {} "search only specific sources"]
        (icollect [_ source (ipairs sources)
                   &into [:ul {}]]
          (source-selector source))])])

(λ home [{: sources}]
  (layout (form sources)))

(fn categorize-sources [sources requested]
  (let [locals [] unknown []
        sources-by-name (collect [_ {: name &as s} (ipairs sources)] name s)]
    (each [_ name (ipairs requested)]
      (case (. sources-by-name name)
        {:name name_ &as s} (table.insert locals s)
        _ (table.insert unknown name)))
    (when (not (next requested))
      (each [_ s (pairs sources)]
        (case s {:url nil :name name_} (table.insert locals s))))
    (values locals unknown)))

(fn clean-title [title]
  (pick-values 1 (title:gsub "\\([,%?!|\"])" "%1")))

(fn local-results [db q locals]
  (let [results (if (and q (not= q ""))
                    (icollect [url title (db:search q locals)
                               &into [:ul {}]]
                      [:li {} [:a {:href url} (clean-title title)]]))]
    (if (and results (. results 3))
        results
        [:p {} "Not found."])))

(λ search [{: db : log : sources} args]
  (let [{:q [q] : source} args
        (locals unknown) (categorize-sources sources (or source []))
        html (layout [:p {} "Results for" [:kbd {} q]]
                     (local-results db q locals)
                     (form sources))]
    (log :Q q)
    (each [_ name (ipairs unknown)] (log :unknown-source name))
    html))

(λ snippet [{: io} name]
  (with-open [f (io.open name)]
    (layout (unescaped (f:read :*all)))))

(λ err [status msg]
  {: status :body (layout [:h2 {} "Error"] [:p {} msg])})

(λ static [{: io} path]
  (assert (not (path:find "%.%.")) "bad path")
  (case (io.open (.. "static" path))
    f {:body (let [content (f:read :*all)]
               (f:close)
               content)
       :headers {:content-type (case (path:match "%.[a-z]+")
                                 :xml "text/xml"
                                 :ico "image/x-icon"
                                 :txt "text/plain")}}))

{: home : search : snippet : err : static}
