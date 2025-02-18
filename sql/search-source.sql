SELECT distinct url, title
FROM pages
WHERE body MATCH '%s'
AND source IN (%s)
ORDER BY rank;
