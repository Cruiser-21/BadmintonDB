-- Tier 1 — Foundational (joins + GROUP BY)

--Brand sponsorship footprint — How many players does each brand sponsor, split by gender? (JOIN, COUNT, GROUP BY)
SELECT b.brand_name, count(s.player_id) AS "Number_of_Sponsorships", p.gender
FROM brands b LEFT JOIN sponsorships s ON b.brand_id = s.brand_id
LEFT JOIN players p ON s.player_id = p.player_id
GROUP BY b.brand_name, gender
ORDER BY Number_of_Sponsorships DESC;



--Paris 2024 medal table — Gold/silver/bronze count by country. (JOIN, CASE, GROUP BY)
with Points AS(
	SELECT SUM(CASE 
		WHEN tr.finish = 'Champion'  THEN 3 
		WHEN tr.finish = 'Runner-up' THEN 2 
		WHEN tr.finish = 'Bronze'    THEN 1 
		ELSE 0 
	END) AS Total_Points
	FROM tournament_results tr
)
SELECT c.country_name, 
	SUM(CASE WHEN tr.finish = 'Champion' THEN 1 ELSE 0 END) AS Gold,
	SUM(CASE WHEN tr.finish = 'Runner-up' THEN 1 ELSE 0 END) AS Silver,
	SUM(CASE WHEN tr.finish = 'Bronze' THEN 1 ELSE 0 END) AS Bronze
FROM tournament_results tr LEFT JOIN players ps ON tr.player_id = ps.player_id
LEFT JOIN partnerships part ON part.partnership_id = tr.partnership_id
LEFT JOIN players pd1 ON pd1.player_id = part.player1_id
LEFT JOIN players pd2 ON pd2.player_id = part.player2_id
JOIN tournament_editions te ON te.edition_id = tr.edition_id
JOIN tournaments t ON t.tournament_id = te.tournament_id
JOIN countries c ON c.country_id IN(ps.country_id, pd1.country_id)
WHERE    t.tournament_name = 'Olympic Games' AND    te.edition_year = 2024 AND tr.finish IN ('Champion', 'Runner-up', 'Bronze')
GROUP BY c.country_name
ORDER BY SUM(CASE 
		WHEN tr.finish = 'Champion'  THEN 3 
		WHEN tr.finish = 'Runner-up' THEN 2 
		WHEN tr.finish = 'Bronze'    THEN 1 
		ELSE 0 
	END) DESC;



--Roster by country — Player count per country, men vs women. (GROUP BY, conditional COUNT)
SELECT c.country_name,
	SUM(CASE WHEN p.gender = 'M' THEN 1 ELSE 0 END) AS Male_Count,
	SUM(CASE WHEN p.gender = 'F' THEN 1 ELSE 0 END) AS Female_Count
FROM countries c LEFT JOIN players p on c.country_id = p.country_id
GROUP BY c.country_name
ORDER BY count(p.player_id) DESC;


--Tier 2 — Intermediate (multi-join, CASE, subqueries)


	

--Does brand correlate with performance? — Average season win rate grouped by each player's primary racket brand. (join player_equipment → equipment → brands, filter is_primary, AVG)


SELECT b.brand_name,
round(SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 3) AS win_rate
FROM brands b
JOIN equipment e ON b.brand_id = e.brand_id
JOIN player_equipment pe ON pe.equipment_id = e.equipment_id
JOIN players p ON p.player_id = pe.player_id
JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
WHERE e.category_id = 1 AND pe.is_primary = 1
GROUP BY b.brand_name
ORDER BY win_rate DESC;


--Tension profiles — Average string tension by brand, by discipline, and men vs women (remember some players have a main/cross split — average them). (JOIN, AVG, COALESCE, GROUP BY)

/*
SELECT dis.discipline_name, b.brand_name, 
	CASE WHEN p.gender = 'M' THEN AVG((pe.tension_main_lbs + pe.tension_cross_lbs)/2) ELSE 0 END AS Men_Average,
	CASE WHEN p.gender = 'W' THEN AVG((pe.tension_main_lbs + pe.tension_cross_lbs)/2) ELSE 0 END AS Women_Average
FROM player_equipment pe
JOIN equipment e ON pe.equipment_id = e.equipment_id
JOIN brands b ON b.brand_id = e.brand_id
JOIN players p on p.player_id = pe.player_equipment_id
JOIN partnerships part ON p.player_id IN(part.player1_id, part.player2_id) 
JOIN disciplines dis ON dis.discipline_id = part.discipline_id
GROUP BY b.brand_name, p.gender, dis.discipline_name
ORDER BY Men_Average DESC, Women_Average DESC;
*/

SELECT b.brand_name, 
	ROUND(AVG(CASE WHEN p.gender = 'M' THEN (pe.tension_main_lbs + COALESCE(pe.tension_cross_lbs, pe.tension_main_lbs))/2.0 END),2) AS Men_Average,
	ROUND(AVG(CASE WHEN p.gender = 'F' THEN (pe.tension_main_lbs + COALESCE(pe.tension_cross_lbs, pe.tension_main_lbs))/2.0 END),2) AS Women_Average
FROM player_equipment pe
JOIN equipment e ON pe.equipment_id = e.equipment_id
JOIN brands b ON b.brand_id = e.brand_id
JOIN players p on p.player_id = pe.player_id
WHERE e.category_id = 1
GROUP BY b.brand_name
ORDER BY Men_Average DESC, Women_Average DESC;


--Tier 2 (continued):

--Win rate from matches — uses the four-slot unfold trick, since a player can sit in any slot.
WITH appearance AS (
	SELECT side1_player1_id AS player_id, CASE WHEN winner_side = 1 THEN 1 ELSE 0 END as won FROM matches
	UNION ALL SELECT side1_player2_id, CASE WHEN winner_side = 1 THEN 1 ELSE 0 END FROM matches
	UNION ALL SELECT side2_player1_id, CASE WHEN winner_side = 2 THEN 1 ELSE 0 END FROM matches
	UNION ALL SELECT side2_player2_id, CASE WHEN winner_side = 2 THEN 1 ELSE 0 END FROM matches
)
SELECT p.full_name, c.country_name, p.gender,
	count(*) as num_matches, 
	SUM(a.won) as Wins,
	SUM(a.won)*1.00/count(*) AS win_rate
FROM players p join countries c ON p.country_id = c.country_id
join appearance a ON a.player_id = p.player_id
GROUP BY p.full_name, c.country_name, p.gender
ORDER BY win_rate desc;


--Win rate from raw matches — Compute each player's win % directly from the matches table, not the pre-aggregated stats. 
--The trick: a player can sit in any of four slots (side1/side2, player1/player2), so you have to find every match they appeared in and whether their side won. 
--(CASE, OR conditions or UNION, aggregation)

SELECT p.full_name, 
SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) AS Wins,
SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id)) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id)) THEN 1 ELSE 0 END) AS Num_Matches,
round(SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) * 1.0 / COUNT(*), 3) AS win_rate
FROM players p JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
GROUP BY p.full_name
ORDER BY win_rate DESC;



--Head-to-head between two named players, with both a match list and a W-L summary. Just change the two names at the top.


With top_Results AS(
SELECT TOP (2) p.player_id
FROM players p JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
WHERE p.gender = 'M'
GROUP BY p.player_id
ORDER BY SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) DESC
)
SELECT p.full_name, 
SUM(CASE WHEN (p.player_id = m.side1_player1_id AND m.winner_side = 1) OR (p.player_id = m.side2_player1_id AND m.winner_side = 2) THEN 1 ELSE 0 END) as Wins,
SUM(CASE WHEN (p.player_id = m.side1_player1_id AND m.winner_side = 2) OR (p.player_id = m.side2_player1_id AND m.winner_side = 1) THEN 1 ELSE 0 END) as Losses
FROM matches m JOIN players p ON p.player_id IN(m.side1_player1_id, m.side2_player1_id)
WHERE m.side1_player1_id IN(SELECT player_id from top_Results)
AND 
m.side2_player1_id IN(SELECT player_id from top_Results)
GROUP BY p.full_name;




--Matches per tournament edition.


SELECT t.tournament_name, count(*) AS num_Matches FROM tournaments t
JOIN tournament_editions te on t.tournament_id = te.tournament_id 
JOIN matches m on te.edition_id = m.edition_id
GROUP BY t.tournament_name, te.edition_year
ORDER BY te.edition_year DESC;

--Tier 3:

--Win rate per season with year-over-year change using LAG, computed over match dates.
SELECT p.full_name, YEAR(m.match_date) AS season,
	SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*) AS win_rate,
	lag(SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*)) OVER (PARTITION BY p.full_name ORDER BY YEAR(m.match_date)) AS previous_win_rate,
	SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*) - lag(SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*)) OVER (PARTITION BY p.full_name ORDER BY YEAR(m.match_date)) AS change_in_rate
FROM players p JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
GROUP BY p.full_name, YEAR(m.match_date);

--Rank players within their country by total wins, using RANK.
SELECT c.country_name, RANK() over (PARTITION BY c.country_name ORDER BY SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) DESC) AS country_rank, p.full_name, 
	SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END) AS wins
	FROM players p JOIN countries c ON p.country_id = c.country_id JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
	GROUP BY p.full_name, c.country_name
	ORDER BY c.country_name, wins DESC;

-- Rank doubles pairs by titles won, separately within each event (men's, women's, and mixed doubles).


SELECT p1.full_name AS Player1, p2.full_name AS Player2, d.discipline_name,
SUM(CASE WHEN finish = 'Champion' THEN 1 ELSE 0 END) AS wins
FROM partnerships part JOIN disciplines d ON part.discipline_id = d.discipline_id
JOIN players p1 ON p1.player_id = part.player1_id
JOIN players p2 ON p2.player_id = part.player2_id
join tournament_results tr ON tr.partnership_id = part.partnership_id
GROUP BY  p1.full_name, p2.full_name, d.discipline_name
ORDER BY SUM(CASE WHEN finish = 'Champion' THEN 1 ELSE 0 END) DESC;



-- Show each player's average string tension next to their win rate to see whether tension relates to winning.



SELECT p.full_name, 
AVG((pe.tension_main_lbs + pe.tension_cross_lbs)/2.0) AS Average_String_Tension,
SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*) AS win_rate,
p.gender
FROM players p JOIN player_equipment pe ON p.player_id = pe.player_id JOIN matches m ON p.player_id IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
WHERE pe.tension_main_lbs IS NOT NULL AND pe.tension_cross_lbs IS NOT NULL
GROUP BY p.full_name, p.gender
ORDER BY SUM(CASE WHEN (p.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1) OR (p.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2) THEN 1 ELSE 0 END)*1.0/COUNT(*) DESC;

-- Count how many titles each country won in each of the five disciplines, to see which nation dominates which event.

SELECT c.country_name AS Country,
d.discipline_name AS Discipline,
COUNT(tr.finish) AS Wins
FROM tournament_results tr JOIN disciplines d ON tr.discipline_id = d.discipline_id
LEFT JOIN players sp ON sp.player_id = tr.player_id
LEFT JOIN partnerships part ON tr.partnership_id = part.partnership_id
LEFT JOIN players dp ON dp.player_id = part.player1_id
JOIN countries c ON c.country_id = COALESCE(sp.country_id, dp.country_id)
WHERE tr.finish = 'Champion'
GROUP BY c.country_name, discipline_name
ORDER BY discipline_name ASC, COUNT(tr.finish) DESC;




-- For each racket model, show how many players use it and the combined win rate of those players.

SELECT e.model_name, 
count(DISTINCT pe.player_id) AS Users,
SUM(CASE WHEN pe.player_id IN(m.side1_player1_id, m.side1_player2_id) AND m.winner_side = 1 OR pe.player_id IN(m.side2_player1_id, m.side2_player2_id) AND m.winner_side = 2 THEN 1 ELSE 0 END)*1.00/COUNT(*) AS Win_Rate
FROM equipment e JOIN player_equipment pe ON e.equipment_id = pe.equipment_id
JOIN matches m ON pe.player_ID IN(m.side1_player1_id, m.side1_player2_id, m.side2_player1_id, m.side2_player2_id)
GROUP BY e.model_name
ORDER BY Win_Rate DESC, Users DESC;


-- Find any player or pair that won 3 or more titles in a single calendar year, ranked within that year.

SELECT	te.edition_year, 
		COALESCE((pd1.full_name +' & '+ pd2.full_name), p.full_name) as "Name(s)",
		d.discipline_name,
		count(tr.finish) AS Wins
FROM tournament_editions te JOIN tournament_results tr ON te.edition_id = tr.edition_id
LEFT JOIN players p ON p.player_id = tr.player_id
LEFT JOIN partnerships part on part.partnership_id = tr.partnership_id
LEFT JOIN players pd1 ON pd1.player_id = part.player1_id
LEFT JOIN players pd2 ON pd2.player_id = part.player2_id
LEFT JOIN disciplines d ON d.discipline_id = tr.discipline_id
WHERE tr.finish = 'Champion'
GROUP BY te.edition_year, COALESCE((pd1.full_name +' & '+ pd2.full_name), p.full_name), d.discipline_name
HAVING count(tr.finish) >= 3
ORDER BY te.edition_year ASC, Wins DESC;



-- Count how many titles players won while training under each coach.

SELECT co.full_name,
COUNT(DISTINCT CASE WHEN tr.finish = 'Champion' THEN tr.result_id END) AS Wins
FROM coaches co 
JOIN player_coach pc ON co.coach_id = pc.coach_id
JOIN players p ON p.player_id = pc.player_id
LEFT JOIN partnerships part ON p.player_id IN(part.player1_id, part.player2_id)
JOIN tournament_results tr ON tr.player_id = p.player_id OR tr.partnership_id = part.partnership_id
GROUP BY co.full_name
ORDER BY Wins DESC, co.full_name ASC;