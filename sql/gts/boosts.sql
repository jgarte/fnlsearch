SELECT s.content
  FROM statuses b
  JOIN accounts a ON b.account_id = a.id
  JOIN statuses s ON b.boost_of_id = s.id
 WHERE a.username = ?
   AND b.visibility = 2
   AND domain is null
   AND s.content like '%https%';
