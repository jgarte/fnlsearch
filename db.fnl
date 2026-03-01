;; factored out so that the DB settings can be shared with tests, but
;; unfortunately it can't be a proper module because the path and caps
;; are different in test... see if we can share just the rest?

(local litehug (require :litehug))

(local [db-path io lsqlite3] [...])

(litehug.init db-path
              {:search :n ; TODO: :iterator giving some trouble here; why?
               :pages {:delete :! :insert :! :refresh :1 :sources :n}
               :remotes {:add :! :list :n}}
              [:pages :remotes]
              io lsqlite3)
