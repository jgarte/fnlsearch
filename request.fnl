;; making an HTTPS request from lua requires choosing among a list of very
;; bad options:
;; * the luvit stuff that comes with moonmint depends on deleted openssl APIs
;; * lua-curl requires lua 5.1 or 5.2
;; * lua-http doesn't work with 5.4
;; * luasec does not validate certs by default

;; of these, I've chosen to work around the terrible defaults in lua-sec, but
;; I can't really recommend it because if they can't even get something as basic
;; as this right there's probably a bunch of other problems lurking.

(local https (require :ssl.https))
(local http (require :socket.http))

(local cafile "/etc/ssl/certs/ca-certificates.crt")

(fn get [url]
  (let [req (if (url:find "^https://") https.request http.request)
        ;; the ltn12 API sucks but you have to use it because the simple API
        ;; doesn't let you set cert verification
        out []
        sink #(doto out (table.insert $))
        (_ status headers) (req {: url : sink :verify :peer : cafile})]
    {:body (table.concat out "\n") : status : headers}))

{: get}
