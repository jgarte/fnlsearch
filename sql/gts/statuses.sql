SELECT content
  FROM statuses s
  JOIN accounts a ON s.account_id = a.id
 WHERE a.username = ?
   AND domain is null
   AND content LIKE '%https%'
   AND visibility = 2
