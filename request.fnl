(local http-request (case (pcall require :http.request)
                      (true request) request
                      _ (do
                          ;; work around a bug in Debian packaging for lua-http:
                          ;; https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1081208
                          (set package.path (.. package.path ";/usr/share/lua/5.2/?.lua"))
                          (require :http.request))))

(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

;; https://github.com/daurnimator/lua-http/issues/235
(fn set-headers [request method ?headers]
  (request.headers:append ":method" method)
  (request.headers:append "user-agent" user-agent)
  (each [k v (pairs (or ?headers []))] (request.headers:append k v)))

(fn get [url ?headers]
  (let [request (doto (http-request.new_from_uri url)
                  (set-headers :GET ?headers))
        (headers stream) (assert (request:go 256))
        body (assert (stream:get_body_as_string))
        status (tonumber (headers:get ":status"))]
    {: status : body : headers}))

{: get : user-agent}
