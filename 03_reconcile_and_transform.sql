-- ============================================================================
-- STEP 3 — RECONCILE PLAYERS, THEN TRANSFORM STAGING -> YOUR REAL SCHEMA
-- ============================================================================
-- Run this in SSMS against BadmintonDB AFTER step 2 has loaded the staging
-- tables. This is the heart of the project: it turns raw, messy, duplicated
-- staging data into clean rows in your real players / matches tables.
--
-- IMPORTANT: the column names below in [[ DOUBLE BRACKETS ]] are PLACEHOLDERS.
-- Replace them with the REAL column names you saw when you ran 01_inspect.py.
-- Different datasets call them different things (winner / Winner / p1_name etc).
-- ============================================================================


-- ----------------------------------------------------------------------------
-- 3A. Collect every player NAME that appears anywhere in staging, into one list
-- ----------------------------------------------------------------------------
-- We pull names from both staging tables and both sides of each match.
-- Adjust the column names and UNION in however many name columns each table has
-- (singles has 2 players; doubles rows may have 4 name columns).

IF OBJECT_ID('stg_all_names') IS NOT NULL DROP TABLE stg_all_names;

SELECT DISTINCT LTRIM(RTRIM(raw_name)) AS raw_name
INTO stg_all_names
FROM (
    SELECT [[winner_name_column]] AS raw_name FROM stg_superseries
    UNION
    SELECT [[loser_name_column]]  AS raw_name FROM stg_superseries
    UNION
    SELECT [[winner_name_column]] AS raw_name FROM stg_worldtour
    UNION
    SELECT [[loser_name_column]]  AS raw_name FROM stg_worldtour
) x
WHERE raw_name IS NOT NULL AND LTRIM(RTRIM(raw_name)) <> '';


-- ----------------------------------------------------------------------------
-- 3B. Build the ALIAS table — this is the correctness step
-- ----------------------------------------------------------------------------
-- player_alias maps EVERY raw spelling -> ONE canonical player_id.
-- First pass: give every distinct raw name its own new player_id automatically.
-- Then you MANUALLY merge the duplicates (the real work — see 3C).

IF OBJECT_ID('player_alias') IS NOT NULL DROP TABLE player_alias;
CREATE TABLE player_alias (
    raw_name   NVARCHAR(200) PRIMARY KEY,
    player_id  INT NULL          -- which canonical player this spelling means
);

-- Seed: insert every distinct raw name. player_id starts NULL; we assign below.
INSERT INTO player_alias (raw_name)
SELECT raw_name FROM stg_all_names;

-- Create a canonical player for each name that doesn't already exist in players.
-- (Assumes your players table has player_id + full_name. Adjust if needed.)
DECLARE @next_id INT = (SELECT ISNULL(MAX(player_id), 500) + 1 FROM players);

;WITH new_names AS (
    SELECT a.raw_name,
           ROW_NUMBER() OVER (ORDER BY a.raw_name) - 1 AS rn
    FROM player_alias a
    LEFT JOIN players p ON p.full_name = a.raw_name
    WHERE p.player_id IS NULL
)
INSERT INTO players (player_id, full_name, status)
SELECT @next_id + rn, raw_name, 'active'
FROM new_names;

-- Point every alias at the matching canonical player.
UPDATE a
SET a.player_id = p.player_id
FROM player_alias a
JOIN players p ON p.full_name = a.raw_name;


-- ----------------------------------------------------------------------------
-- 3C. MERGE DUPLICATES  (do this by hand — it's the part that makes data correct)
-- ----------------------------------------------------------------------------
-- Find suspected duplicates: same person, different spelling.
-- Eyeball this list, then repoint the bad aliases to the correct player_id.

-- See likely dupes (names that are similar):
SELECT raw_name, player_id FROM player_alias ORDER BY raw_name;

-- Example fix: "An Se Young", "An Seyoung", "An Se-young" are ONE person.
-- Decide the correct player_id (say it's 601), then:
--
--   UPDATE player_alias SET player_id = 601
--   WHERE raw_name IN ('An Se Young', 'An Seyoung', 'An Se-young');
--
-- Repeat for each duplicate cluster you find. This is tedious but it is THE
-- step that determines whether your win-rate numbers are right.


-- ----------------------------------------------------------------------------
-- 3D. TRANSFORM matches -> your real matches table
-- ----------------------------------------------------------------------------
-- Now insert clean rows into your real schema, translating raw names to the
-- canonical player_id via player_alias. Replace placeholders with real columns
-- and map to YOUR matches table's actual column list.

INSERT INTO matches
    (edition_id, discipline_id, round, match_date,
     side1_player1_id, side2_player1_id, winner_side, score_summary, source_file)
SELECT
    NULL                       AS edition_id,        -- map later if you build editions
    NULL                       AS discipline_id,     -- map from the discipline text column
    s.[[round_column]]         AS round,
    TRY_CONVERT(date, s.[[date_column]]) AS match_date,
    w.player_id                AS side1_player1_id,   -- winner
    l.player_id                AS side2_player1_id,   -- loser
    1                          AS winner_side,        -- winner is side 1 by convention
    s.[[score_column]]         AS score_summary,
    s.source_file
FROM stg_worldtour s
JOIN player_alias w ON w.raw_name = LTRIM(RTRIM(s.[[winner_name_column]]))
JOIN player_alias l ON l.raw_name = LTRIM(RTRIM(s.[[loser_name_column]]));

-- Repeat the same INSERT for stg_superseries.


-- ----------------------------------------------------------------------------
-- 3E. VALIDATE — catch bad rows before you trust the data
-- ----------------------------------------------------------------------------
-- Rows where a name failed to map (should be zero):
SELECT s.[[winner_name_column]]
FROM stg_worldtour s
LEFT JOIN player_alias a ON a.raw_name = LTRIM(RTRIM(s.[[winner_name_column]]))
WHERE a.player_id IS NULL;

-- Matches where dates failed to parse:
SELECT COUNT(*) AS bad_dates FROM matches WHERE match_date IS NULL;

-- Sanity check: total matches loaded
SELECT COUNT(*) AS total_matches FROM matches;
