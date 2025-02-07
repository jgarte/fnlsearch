(local t (require :test.faith))
(local https (require :https))
(local request (require :request))

(fn test-https []
  (let [url "https://search.technomancy.us"
        response (request.get https url)]
    (t.= 200 response.status)
    (t.match "text/html" response.headers.content-type)
    (t.match "search" response.body)))

(fn test-bad-ssl []
  (let [url "https://wrong.host.badssl.com"
        response (request.get https url)]
    (t.= 0 response.status)))

{: test-https : test-bad-ssl}
