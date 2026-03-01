;; SPDX-License-Identifier: MIT
;; SPDX-FileCopyrightText: Phil Hagelberg and contributors
;; URL: https://git.sr.ht/~technomancy/litehug

(λ read [io path] (with-open [f (assert (io.open path))] (f:read :*all)))

(λ open [io sqlite db-path]
  (case (io.open db-path)
    f (do (f:close) (sqlite.open db-path))
    _ (assert (sqlite.open db-path))))

(fn step [db stmt sqlite]
  (match (stmt:step)
    sqlite.ROW true
    sqlite.DONE false ; ugh, C programmers amirite
    _ (error (db:errmsg))))

(fn execute [sqlite db kind stmt ...]
  (match (stmt:bind_values ...)
    sqlite.OK (case kind
                :! (do (step db stmt sqlite)
                       ;; the lsqlite3 docs don't explain this at all, but you
                       ;; will get some nasty data loss if you don't reset after
                       ;; each write!
                       (assert (= sqlite.OK (stmt:reset))))
                :1 (let [row? (step db stmt sqlite)
                         row (if row? (stmt:get_named_values))]
                     (assert (= sqlite.OK (stmt:reset)))
                     row)
                :n (do (stmt:reset) (icollect [row (stmt:nrows)] row))
                :iterator (do (stmt:reset) (stmt:nrows))
                _ (error "unknown query type"))
    err-code (error (.. "litehug error: sqlite code " err-code))))

(λ prepare [db io sql-path name]
  (let [filename (sql-path:format name)]
    (or (db:prepare (read io filename))
        (error (string.format "statement error %s %s" filename (db:errmsg))))))

(fn make [sqlite db io sql-path what name]
  (if (= :table (type what))
      (collect [name2 what (pairs what)]
        name2 (make sqlite db io (sql-path:format (.. name "/%s")) what name2))
      (partial execute sqlite db what (prepare db io sql-path name))))

(fn migrate-prep [db]
  (db:execute "CREATE TABLE migrations (name TEXT NOT NULL) STRICT")
  (db:prepare "SELECT * FROM migrations WHERE name = ?"))

(fn migrate [sqlite db io check-migration-stmt sql-path name]
  (when (not (execute sqlite db :1 check-migration-stmt name))
    (io.write (.. "Running migration: " name "\n"))
    ((make sqlite db io (sql-path:format "migrations/%s") :! name))
    (execute sqlite db :! (db:prepare "INSERT INTO migrations VALUES (?)") name)))

(λ init [db-path queries ?migrations ?io ?sqlite ?sql-path]
  "Return a table of query functions corresponding to `queries`.
Each key should be the name of an SQL file in the sql-path; each value should
be one of :!, :1, :n, or :iterator."
  (let [io (or ?io _G.io)
        sqlite (or ?sqlite (require :lsqlite3))
        sql-path (or ?sql-path "sql/%s.sql")
        db (open io sqlite db-path)
        check-migration-stmt (and ?migrations (migrate-prep db))]
    (fn add-query [t name ?what] ; for repl use
      ;; TODO: splice into existing table, don't replace!
      (set (. t name) (make sqlite db io sql-path
                            (or ?what (. queries name)) name)))
    (each [_ migration-name (ipairs (or ?migrations []))]
      (migrate sqlite db io check-migration-stmt sql-path migration-name))
    (collect [name what (pairs queries) &into {:close #(db:close) : add-query}]
      name (if (not= :init name)
               (make sqlite db io sql-path what name)))))

{: init :version "0.2.1-dev"}
