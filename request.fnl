;; making an HTTPS request from lua requires choosing among a list of very
;; bad options:
;; * the luvit stuff that comes with moonmint depends on deleted openssl APIs
;; * lua-curl requires lua 5.1 or 5.2
;; * lua-http doesn't work with 5.4
;; * luasec does not validate certs by default
;; * love2d's lua-https is not packaged in apt and is not documented

;; of these, for the simple kind of requests we are making here, love2d's client
;; poses the least severe problems

(fn normalize-headers [headers]
  (collect [k v (pairs headers)] (k:lower) v))

(fn get [https url]
  ;; with one arg, it gives us a "simplified" response which omits headers
  (let [(status body headers) (https.request url {})]
    {: status : body :headers (normalize-headers headers)}))

{: get}
