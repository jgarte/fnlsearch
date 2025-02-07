;; SPDX-License-Identifier: MIT
;; SPDX-FileCopyrightText: Phil Hagelberg and contributors

;; down with ambient authority!
(local fennel (require :fennel))

(when _G.unpack (set table.unpack _G.unpack)) ; luajit compatibility

(fn find [tbl x ?i]
  (match (. tbl (or ?i 1))
    x (or ?i 1)
    y_ (find tbl x (+ (or ?i 1) 1))))

(fn find-fuzzy [tbl x ?i]
  (match (. tbl (or ?i 1))
    (where pattern (x:find pattern)) (or ?i 1)
    y_ (find-fuzzy tbl x (+ (or ?i 1) 1))))

(fn iterator-for [iterate raw ?wrap]
  (fn []
    (let [t [] wrap (or ?wrap (fn [x] x))]
      (each [k v (iterate raw)]
        (tset t k (if (= (type v) :table) (wrap v) v)))
      (values next t nil))))

(fn read-only [source ?name]
  (setmetatable {} {:__index (fn [_ key]
                               (if (= (type (. source key)) :table)
                                   (read-only (. source key))
                                   (. source key)))
                    :__newindex #(error (.. (or ?name "table") ": read only"))
                    :__pairs (iterator-for pairs source read-only)
                    :__ipairs (iterator-for ipairs source read-only)
                    :__maxn (partial (. table :maxn) source)}))

(local safe-fennel-keys [:version :doc :gensym :mangle :unmangle :path :view
                         :traceback :syntax :parser])
(fn safe-fennel [env]
  (fn eval [str options]
    (fennel.eval str (doto (collect [k v (pairs options)] k v)
                       (tset :env env))))
  (read-only (collect [_ k (ipairs safe-fennel-keys) :into {: eval}]
               (values k (. fennel k))) :fennel))

(local safe-globals [:assert :error :next :pcall :xpcall :pairs :ipairs :select
                     :tonumber :tostring :type :coroutine :math :table :string
                     ;; technically it's I/O but without it debugging is awful
                     :print :utf8 :_VERSION])

(fn preload [env modname]
  (case (. env.package.preload modname)
    chunk (chunk)))

(fn file-exists? [path]
  (case (io.open path)
    f (do (f:close) true)))

(fn require-for [env]
  (fn [modname]
    (or (. env.package.loaded modname)
        ;; TODO: should really be a full-fledged searchers setup here
        (let [pmod (modname:gsub "%." "/")
              mod (or (preload env modname)
                      (if (file-exists? (.. pmod ".lua"))
                          ((assert (loadfile (.. pmod ".lua") :bt env)))
                          (fennel.dofile (.. pmod ".fnl") {: env})))]
          (tset env.package.loaded modname mod)
          mod))))

(fn env [?extra]
  "Return an environment table under which it's safe to run untrusted code.

The globals in this environment cannot access the outside world; this access
must be done thru capabilities which are passed lexically instead of thru
ambient authority."
  (let [env {:package {:loaded {:capabilities (require :capabilities)}
                       :preload {}}
             :getmetatable #nil
             :debug {:traceback fennel.traceback}}]
    (set env._G env)
    (set env.require (require-for env))
    (set env.package.loaded.fennel (safe-fennel env))
    (each [_ g (ipairs safe-globals)]
      (if (= :table (type (. _G g)))
          (tset env g (read-only (. _G g) g))
          (tset env g (. _G g))))
    (each [k v (pairs (or ?extra {}))]
      (tset env k v))
    env))

;; the actual capability functions

(fn wrap-allowed [f allowed-args]
  "Return a function that guards the given one-arg function f.

If the function is called with an argument that is in the allowed-args sequence
then call f with that arg; otherwise error."
  (fn [arg]
    (assert (find allowed-args arg) (.. "disallowed wrapped arg: "
                                        (tostring arg)))
    (f arg)))

(local builtins {:os {} :io {}})

(fn ok-path? [paths path]
  ;; TODO: normalize first!
  (and (not (path:find "%.%."))
       (accumulate [ok? false _ p (ipairs paths) :until ok?]
         (if (p:find "/$")
             (= p (path:sub 1 (length p)))
             (= p path)))))

(fn builtins.os.getenv [{: os} vars]
  (fn [v]
    (assert (find vars v) (.. "disallowed getenv: " v))
    (os.getenv v)))

(fn builtins.os.execute [{: os} commands]
  (fn [command]
    (assert (find-fuzzy commands command) (.. "disallowed os.execute: " command))
    (os.execute command)))

(fn builtins.os.remove [{: os} paths]
  (fn [path]
    (assert (ok-path? paths path) (.. "disallowed os.remove: " path))
    (os.remove path)))

(fn builtins.os.exit [{: os} allowed-codes]
  (wrap-allowed os.exit allowed-codes))

(fn builtins.os.date [{: os} ?date] (or ?date os.date))
(fn builtins.os.time [{: os} ?time] (or ?time os.time))
(fn builtins.os.tmpname [{: os} ?tmpname] (or ?tmpname os.tmpname))

(fn builtins.io.open [{: io} {: read : write}]
  (fn [path ?mode]
    (assert (ok-path? (if (= :r (: (or ?mode :r) :sub 1 1)) read write) path)
            (.. "disallowed io.open: " path))
    (io.open path ?mode)))

(fn builtins.io.popen [{: io} commands]
  (fn [command]
    (assert (find-fuzzy commands command) (.. "disallowed io.popen: " command))
    (io.popen command)))

(fn builtins.io.stdin [_ stdin] stdin)
(fn builtins.io.lines [_ lines] lines)

(fn for* [_g descriptor ?extra]
  "Return a capabilities table based on the capabilities descriptors provided.

Right now only the :io and :os keys are accepted; under each key there should be
a sequence of arguments which the given function may be called using. Calls that
do not match these allowlists will result in errors.

* os.exit: allowed exit codes
* os.getenv: allowed env var names
* os.remove: paths that are allowed to be removed
* os.execute: patterns of commands that are allowed to be executed
* os.date, os.time: no args; all calls allowed if provided
* io.open: a table of :read and :write paths
* io.popen: patterns of commands like os.execute

If file paths for io.open and os.remove end in a slash, then anything under the
given directory will be allowed; otherwise it must be an exact match."
  (collect [gname mod (pairs descriptor) &into (or ?extra {})]
    gname (let [builtin (assert (. builtins gname)
                                (.. "Unknown capability descriptor: " gname))]
            (collect [fname data (pairs mod)]
              fname ((assert (. builtin fname)
                             (.. "Unknown capability descriptor: "
                                 gname " " fname))
                     _g data)))))

{:for for* : wrap-allowed : env}
