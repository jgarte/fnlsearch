(local t (require :test.faith))
(local request (require :request))

(fn test-https []
  (let [url "https://search.technomancy.us"
        response (request.get url)]
    (t.= 200 response.status)
    (t.= "text/html" response.headers.content-type)
    (t.match "search" response.body)))

(fn test-bad-ssl []
  (let [url "https://wrong.host.badssl.com"
        response (request.get url)]
    (t.= -100 response.status)))

{: test-https : test-bad-ssl}
