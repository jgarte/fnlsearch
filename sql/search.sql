SELECT distinct url, title, rank
FROM pages
WHERE body MATCH '%s'
ORDER BY rank;
