CREATE VIRTUAL TABLE pages
USING fts5(url, title, body, source, crawled_at, tokenize = 'porter ascii');

CREATE TABLE remotes (url, name, home, description);
