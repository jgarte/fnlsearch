SELECT distinct url, title
FROM pages
WHERE body MATCH '%s'
ORDER BY rank;
