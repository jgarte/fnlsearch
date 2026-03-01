SELECT distinct url, title
  FROM pages
 WHERE body MATCH ?
--   AND source IN (?)
 ORDER BY rank
