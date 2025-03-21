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
           [:input {:name "source" :type "checkbox" :value name
                    :checked :checked}]
           (if home
               [:a {:href home} name]
               name)]])

(fn form [sources]
  [:form {:action "/q" :method "GET"}
   [:input {:type "text" :name "q" :placeholder "query"}]
   [:input {:type "submit" :value "search"}]
   (if (. sources 2)
       [:details {:id "sources"} [:summary {} "sources"]
        (icollect [_ source (ipairs sources)
                   &into [:ul {}]]
          (source-selector source))])])

(λ home [{: moonmint : sources} _req]
  (moonmint.response (layout (form sources))))

(fn categorize-sources [sources requested]
  (let [locals [] remotes [] unknown []
        sources-by-name (collect [_ {: name &as s} (ipairs sources)] name s)]
    (each [_ name (ipairs requested)]
      (case (. sources-by-name name)
        {:url url_ &as s} (table.insert remotes s)
        {:name name_ &as s} (table.insert locals s)
        _ (table.insert unknown name)))
    (when (not (next requested))
      (each [_ s (pairs sources)]
        (case s {:url nil :name name_} (table.insert locals s))))
    (values locals remotes unknown)))

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

(fn remote-results [request json {: url : name : home} q]
  (let [response (request.get (url:format q) {"content-accept" "application/json"})
        {: results} (json.decode response.body)]
    (assert (<= 200 response.status 299) (.. "bad response " response.status))
    [:div {} "Results from " [:a {:href home} name] ":"
     (if (next results)
         (icollect [_ {: url : title} (ipairs results) &into [:ul {}]]
           [:li {} [:a {:href url} (clean-title title)]])
         [:ul {} [:li {} "none"]])]))

(fn remotes-results [request json log remotes q]
  (if (next remotes)
      (icollect [_ r (ipairs remotes) &into [:div {}]]
        (case (pcall remote-results request json r q)
          (true element) element
          (_ err) (do (log "remote error" err)
                      [:p {} "Error searching remote " r.name])))))

(λ search-html [{: db : log : sources : request : json : moonmint} {: rawQuery}]
  (let [{: q : source} (moonmint.url.queryDecodeMulti rawQuery)
        q (if q (. q 1))
        (locals remotes unknown) (categorize-sources sources (or source []))
        html (layout [:p {} "Results for" [:kbd {} q]]
                     (local-results db q locals)
                     (remotes-results request json log remotes q)
                     (form sources))]
    (log :Q q)
    (each [_ name (ipairs unknown)] (log :unknown-source name))
    (moonmint.response html)))

(λ search-json [{: db : log : json : moonmint} {: rawQuery}]
  ;; TODO: should the API let you specify sources too?
  (let [{: q} (moonmint.url.queryDecodeMulti rawQuery)
        q (if q (. q 1))
        body {:results
              (icollect [url title rank (db:search q)]
                {: url : title :rank (- rank)})}]
    (log :JQ q)
    (moonmint.response {:body (json.encode body)
                        :code 200
                        :headers {"content-type" "application/json"}})))

(λ search [caps req]
  (case (. req.headers "content-accept")
    "application/json" (search-json caps req)
    _ (search-html caps req)))

(λ snippet [{: moonmint : static} name _req]
  (moonmint.response (layout (unescaped (. static name)))))

{: home : search : snippet : search-json}
