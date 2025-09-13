(local http-request (case (pcall require :http.request)
                      (true request) request
                      _ (do
                          ;; work around a bug in Debian packaging for lua-http:
                          ;; https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=1081208
                          (set package.path (.. package.path ";/usr/share/lua/5.2/?.lua"))
                          (require :http.request))))

(local user-agent "technomancy-search 0.1 (https://search.technomancy.us)")

(fn get [url]
  (let [request (http-request.new_from_uri url)
        _ (request.headers:append "user-agent" user-agent)
        (headers stream) (assert (request:go 256))
        body (assert (stream:get_body_as_string))
        status (tonumber (headers:get ":status"))]
    {: status : body : headers}))

{: get : user-agent}
