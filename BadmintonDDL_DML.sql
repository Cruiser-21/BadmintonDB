-- ============================================================================
-- BADMINTON ANALYTICS DATABASE — SQL SERVER BUILD SCRIPT
-- Run this entire script in SSMS
-- Requires SQL Server 2016 or later
-- ============================================================================

-- Step 1: Create and select the database
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'BadmintonDB')
    CREATE DATABASE BadmintonDB;
GO
USE BadmintonDB;
GO

-- ============================================================================
-- SECTION A — SCHEMA (CREATE STATEMENTS)
-- ============================================================================

-- Drop in reverse dependency order so foreign keys don't block the drops
DROP TABLE IF EXISTS player_season_stats;
DROP TABLE IF EXISTS player_rankings;
DROP TABLE IF EXISTS match_games;
DROP TABLE IF EXISTS matches;
DROP TABLE IF EXISTS tournament_results;
DROP TABLE IF EXISTS tournament_editions;
DROP TABLE IF EXISTS tournaments;
DROP TABLE IF EXISTS player_coach;
DROP TABLE IF EXISTS coaches;
DROP TABLE IF EXISTS partnerships;
DROP TABLE IF EXISTS player_equipment;
DROP TABLE IF EXISTS sponsorships;
DROP TABLE IF EXISTS equipment;
DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS equipment_categories;
DROP TABLE IF EXISTS disciplines;
DROP TABLE IF EXISTS brands;
DROP TABLE IF EXISTS countries;


-- 1. countries
CREATE TABLE countries (
    country_id     INTEGER      PRIMARY KEY,
    country_name   VARCHAR(60)  NOT NULL,
    country_code   CHAR(3)      NOT NULL,
    confederation  VARCHAR(40)
);

-- 2. brands
CREATE TABLE brands (
    brand_id              INTEGER      PRIMARY KEY,
    brand_name            VARCHAR(60)  NOT NULL,
    country_of_origin_id  INTEGER,
    founded_year          INTEGER,
    specialty             VARCHAR(120),
    FOREIGN KEY (country_of_origin_id) REFERENCES countries (country_id)
);

-- 3. disciplines (MS, WS, MD, WD, XD)
CREATE TABLE disciplines (
    discipline_id    INTEGER      PRIMARY KEY,
    discipline_code  CHAR(2)      NOT NULL,
    discipline_name  VARCHAR(30)  NOT NULL
);

-- 4. equipment_categories (Racket, Shoes, String, etc)
CREATE TABLE equipment_categories (
    category_id    INTEGER      PRIMARY KEY,
    category_name  VARCHAR(30)  NOT NULL
);

-- 5. players
CREATE TABLE players (
    player_id        INTEGER      PRIMARY KEY,
    full_name        VARCHAR(80)  NOT NULL,
    country_id       INTEGER      NOT NULL,
    gender           CHAR(1)      NOT NULL,             -- 'M' / 'F'
    date_of_birth    DATE,
    height_cm        INTEGER,
    handedness       CHAR(1),                           -- 'R' / 'L'
    turned_pro_year  INTEGER,
    status           VARCHAR(10)  NOT NULL,             -- 'active' / 'retired'
    retired_date     DATE,
    FOREIGN KEY (country_id) REFERENCES countries (country_id)
);

-- 6. equipment (rackets, shoes, strings, shuttlecocks, apparel, bags, grips)
CREATE TABLE equipment (
    equipment_id  INTEGER       PRIMARY KEY,
    brand_id      INTEGER       NOT NULL,
    category_id   INTEGER       NOT NULL,
    model_name    VARCHAR(60)   NOT NULL,
    release_year  INTEGER,
    balance_type  VARCHAR(20),                          -- rackets only
    flex_rating   VARCHAR(20),                          -- rackets only
    weight_class  VARCHAR(10),                          -- rackets only (e.g. '4U')
    msrp_usd      DECIMAL(8,2),
    FOREIGN KEY (brand_id)    REFERENCES brands (brand_id),
    FOREIGN KEY (category_id) REFERENCES equipment_categories (category_id)
);

-- 7. sponsorships (formal brand deals)
CREATE TABLE sponsorships (
    sponsorship_id     INTEGER      PRIMARY KEY,
    player_id          INTEGER      NOT NULL,
    brand_id           INTEGER      NOT NULL,
    start_year         INTEGER,
    end_year           INTEGER,                          -- NULL = ongoing
    deal_type          VARCHAR(20),                      -- Full / Racket / Footwear / Apparel
    is_signature_line  SMALLINT     DEFAULT 0,           -- 1 = has own product line
    FOREIGN KEY (player_id) REFERENCES players (player_id),
    FOREIGN KEY (brand_id)  REFERENCES brands (brand_id)
);

-- 8. player_equipment (actual gear in the bag)
CREATE TABLE player_equipment (
    player_equipment_id  INTEGER   PRIMARY KEY,
    player_id            INTEGER   NOT NULL,
    equipment_id         INTEGER   NOT NULL,
    is_primary           SMALLINT  DEFAULT 0,            -- 1 = main gamer
    since_year           INTEGER,
    tension_main_lbs     INTEGER,                        -- main (vertical) string tension, lbs; racket rows only, NULL = not documented
    tension_cross_lbs    INTEGER,                        -- cross (horizontal) string tension, lbs; NULL if no documented split
    FOREIGN KEY (player_id)    REFERENCES players (player_id),
    FOREIGN KEY (equipment_id) REFERENCES equipment (equipment_id)
);

-- 9. partnerships (doubles teams)
CREATE TABLE partnerships (
    partnership_id  INTEGER      PRIMARY KEY,
    discipline_id   INTEGER      NOT NULL,               -- MD / WD / XD
    player1_id      INTEGER      NOT NULL,
    player2_id      INTEGER      NOT NULL,
    formed_year     INTEGER,
    status          VARCHAR(10),                         -- 'active' / 'disbanded'
    FOREIGN KEY (discipline_id) REFERENCES disciplines (discipline_id),
    FOREIGN KEY (player1_id)    REFERENCES players (player_id),
    FOREIGN KEY (player2_id)    REFERENCES players (player_id)
);

-- 10. coaches
CREATE TABLE coaches (
    coach_id    INTEGER      PRIMARY KEY,
    full_name   VARCHAR(80)  NOT NULL,
    country_id  INTEGER,
    FOREIGN KEY (country_id) REFERENCES countries (country_id)
);

-- 11. player_coach (many-to-many over time)
CREATE TABLE player_coach (
    player_id   INTEGER   NOT NULL,
    coach_id    INTEGER   NOT NULL,
    start_year  INTEGER   NOT NULL,
    end_year    INTEGER,                                 -- NULL = current
    PRIMARY KEY (player_id, coach_id, start_year),
    FOREIGN KEY (player_id) REFERENCES players (player_id),
    FOREIGN KEY (coach_id)  REFERENCES coaches (coach_id)
);

-- 12. tournaments (the recurring series)
CREATE TABLE tournaments (
    tournament_id    INTEGER       PRIMARY KEY,
    tournament_name  VARCHAR(60)   NOT NULL,
    tier             VARCHAR(30),                         -- Olympics / Super 1000 / ...
    prize_money_usd  DECIMAL(12,2)
);

-- 13. tournament_editions (a specific year of a series)
CREATE TABLE tournament_editions (
    edition_id       INTEGER      PRIMARY KEY,
    tournament_id    INTEGER      NOT NULL,
    edition_year     INTEGER      NOT NULL,
    start_date       DATE,
    end_date         DATE,
    host_country_id  INTEGER,
    host_city        VARCHAR(50),
    FOREIGN KEY (tournament_id)   REFERENCES tournaments (tournament_id),
    FOREIGN KEY (host_country_id) REFERENCES countries (country_id)
);

-- 14. tournament_results (final standings; player OR partnership)
CREATE TABLE tournament_results (
    result_id       INTEGER      PRIMARY KEY,
    edition_id      INTEGER      NOT NULL,
    discipline_id   INTEGER      NOT NULL,
    player_id       INTEGER,                              -- singles
    partnership_id  INTEGER,                              -- doubles
    finish          VARCHAR(20),                          -- Champion / Runner-up / Bronze / Semi-finalist
    FOREIGN KEY (edition_id)     REFERENCES tournament_editions (edition_id),
    FOREIGN KEY (discipline_id)  REFERENCES disciplines (discipline_id),
    FOREIGN KEY (player_id)      REFERENCES players (player_id),
    FOREIGN KEY (partnership_id) REFERENCES partnerships (partnership_id)
);

-- 15. matches (singles leave side*_player2_id NULL)
CREATE TABLE matches (
    match_id          INTEGER      PRIMARY KEY,
    edition_id        INTEGER      NOT NULL,
    discipline_id     INTEGER      NOT NULL,
    round             VARCHAR(20),
    match_date        DATE,
    side1_player1_id  INTEGER      NOT NULL,
    side1_player2_id  INTEGER,                            -- doubles partner
    side2_player1_id  INTEGER      NOT NULL,
    side2_player2_id  INTEGER,                            -- doubles partner
    winner_side       SMALLINT,                           -- 1 or 2
    score_summary     VARCHAR(40),
    duration_minutes  INTEGER,
    FOREIGN KEY (edition_id)       REFERENCES tournament_editions (edition_id),
    FOREIGN KEY (discipline_id)    REFERENCES disciplines (discipline_id),
    FOREIGN KEY (side1_player1_id) REFERENCES players (player_id),
    FOREIGN KEY (side1_player2_id) REFERENCES players (player_id),
    FOREIGN KEY (side2_player1_id) REFERENCES players (player_id),
    FOREIGN KEY (side2_player2_id) REFERENCES players (player_id)
);

-- 16. match_games (set-by-set detail)
CREATE TABLE match_games (
    game_id       INTEGER   PRIMARY KEY,
    match_id      INTEGER   NOT NULL,
    game_number   INTEGER   NOT NULL,
    side1_points  INTEGER,
    side2_points  INTEGER,
    FOREIGN KEY (match_id) REFERENCES matches (match_id)
);

-- 17. player_rankings (dated snapshots; player OR partnership)
CREATE TABLE player_rankings (
    ranking_id      INTEGER   PRIMARY KEY,
    player_id       INTEGER,                              -- singles
    partnership_id  INTEGER,                              -- doubles
    discipline_id   INTEGER   NOT NULL,
    rank_position   INTEGER,
    ranking_points  INTEGER,
    ranking_date    DATE,
    FOREIGN KEY (player_id)      REFERENCES players (player_id),
    FOREIGN KEY (partnership_id) REFERENCES partnerships (partnership_id),
    FOREIGN KEY (discipline_id)  REFERENCES disciplines (discipline_id)
);

-- 18. player_season_stats (aggregate season form)
CREATE TABLE player_season_stats (
    stat_id         INTEGER   PRIMARY KEY,
    player_id       INTEGER   NOT NULL,
    season_year     INTEGER   NOT NULL,
    discipline_id   INTEGER   NOT NULL,
    matches_played  INTEGER,
    matches_won     INTEGER,
    matches_lost    INTEGER,
    titles          INTEGER,
    finals_reached  INTEGER,
    FOREIGN KEY (player_id)     REFERENCES players (player_id),
    FOREIGN KEY (discipline_id) REFERENCES disciplines (discipline_id)
);


-- ============================================================================
-- BADMINTON ANALYTICS DATABASE — SEED DATA (INSERT STATEMENTS ONLY) -- AI Gathered
-- ----------------------------------------------------------------------------
-- Data accuracy notes:
--   [REAL]        Verified from public sources (BWF rankings ~Apr 2026, brand
--                 sponsorship announcements, Olympic/World Champs/All England
--                 results).
--   [REPRESENTATIVE]  Plausible, illustrative values — NOT a factual claim.
--                 Used for some birthdates/heights of doubles players, season
--                 win/loss totals, non-final match scorelines, footwear usage,
--                 and a few coach assignments. Safe for a portfolio/demo DB.
--
-- Column lists are written out in every INSERT so the schema is self-documenting
-- even without the CREATE TABLE statements. Booleans use 1/0. Dates are ISO.
-- Insert order respects foreign-key dependencies (parents before children).
-- ============================================================================


-- ============================================================================
-- 1. countries  [REAL]
-- ============================================================================
INSERT INTO countries (country_id, country_name, country_code, confederation) VALUES
(1,  'Denmark',        'DEN', 'Badminton Europe'),
(2,  'China',          'CHN', 'Badminton Asia'),
(3,  'Thailand',       'THA', 'Badminton Asia'),
(4,  'South Korea',    'KOR', 'Badminton Asia'),
(5,  'Japan',          'JPN', 'Badminton Asia'),
(6,  'Indonesia',      'INA', 'Badminton Asia'),
(7,  'Malaysia',       'MAS', 'Badminton Asia'),
(8,  'India',          'IND', 'Badminton Asia'),
(9,  'Chinese Taipei', 'TPE', 'Badminton Asia'),
(10, 'Spain',          'ESP', 'Badminton Europe'),
(11, 'France',         'FRA', 'Badminton Europe'),
(12, 'Singapore',      'SGP', 'Badminton Asia'),
(13, 'Canada',         'CAN', 'Badminton Pan Am'),
(14, 'United States',  'USA', 'Badminton Pan Am'),
(15, 'Vietnam',        'VIE', 'Badminton Asia'),
(16, 'England',        'ENG', 'Badminton Europe'),
(17, 'Germany',        'GER', 'Badminton Europe'),
(18, 'Hong Kong',      'HKG', 'Badminton Asia');


-- ============================================================================
-- 2. brands  [REAL]
-- ============================================================================
INSERT INTO brands (brand_id, brand_name, country_of_origin_id, founded_year, specialty) VALUES
(1, 'Yonex',    5,  1946, 'Rackets, Shoes, Strings, Shuttlecocks'),
(2, 'Victor',   9,  1968, 'Rackets, Shoes, Apparel'),
(3, 'Li-Ning',  2,  1990, 'Rackets, Shoes, Apparel'),
(4, 'ASICS',    5,  1949, 'Shoes, Apparel'),
(5, 'FZ Forza', 1,  1971, 'Rackets, Shoes, Apparel'),
(6, 'Babolat',  11, 1875, 'Rackets, Strings'),
(7, 'Felet',    7,  1995, 'Rackets, Apparel'),
(8, 'Kawasaki', 2,  1986, 'Rackets, Accessories');


-- ============================================================================
-- 3. disciplines  [REAL]
-- ============================================================================
INSERT INTO disciplines (discipline_id, discipline_code, discipline_name) VALUES
(1, 'MS', 'Men''s Singles'),
(2, 'WS', 'Women''s Singles'),
(3, 'MD', 'Men''s Doubles'),
(4, 'WD', 'Women''s Doubles'),
(5, 'XD', 'Mixed Doubles');


-- ============================================================================
-- 4. equipment_categories  [REAL]
-- ============================================================================
INSERT INTO equipment_categories (category_id, category_name) VALUES
(1, 'Racket'),
(2, 'Shoes'),
(3, 'String'),
(4, 'Shuttlecock'),
(5, 'Apparel'),
(6, 'Grip'),
(7, 'Bag');


-- ============================================================================
-- 5. players
--    Singles bios [REAL]. Some doubles players' DOB/height [REPRESENTATIVE].
--    status: 'active' / 'retired'.  handedness: 'R' / 'L'.
-- ============================================================================
INSERT INTO players (player_id, full_name, country_id, gender, date_of_birth, height_cm, handedness, turned_pro_year, status, retired_date) VALUES
-- Men's singles
(1,  'Shi Yuqi',              2,  'M', '1996-01-04', 184, 'R', 2014, 'active',  NULL),
(2,  'Kunlavut Vitidsarn',    3,  'M', '2001-05-11', 175, 'R', 2018, 'active',  NULL),
(3,  'Anders Antonsen',       1,  'M', '1997-04-27', 182, 'R', 2014, 'active',  NULL),
(4,  'Christo Popov',         11, 'M', '2002-08-07', 180, 'R', 2019, 'active',  NULL),
(5,  'Jonatan Christie',      6,  'M', '1997-09-15', 178, 'R', 2014, 'active',  NULL),
(6,  'Chou Tien-chen',        9,  'M', '1990-01-08', 180, 'R', 2008, 'active',  NULL),
(7,  'Li Shifeng',            2,  'M', '1999-12-08', 180, 'R', 2016, 'active',  NULL),
(8,  'Lin Chun-yi',           9,  'M', '1998-07-31', 181, 'R', 2017, 'active',  NULL),
(9,  'Kodai Naraoka',         5,  'M', '2001-06-25', 173, 'R', 2019, 'active',  NULL),
(10, 'Alex Lanier',           11, 'M', '2005-04-15', 188, 'R', 2022, 'active',  NULL),
(11, 'Lakshya Sen',           8,  'M', '2001-08-16', 178, 'R', 2018, 'active',  NULL),
(12, 'Loh Kean Yew',          12, 'M', '1997-06-26', 175, 'R', 2015, 'active',  NULL),
(13, 'Viktor Axelsen',        1,  'M', '1994-01-04', 194, 'R', 2011, 'retired', '2026-04-15'),  -- [REAL] retired 15 Apr 2026
(14, 'Lee Zii Jia',           7,  'M', '1998-03-29', 180, 'R', 2016, 'active',  NULL),
(15, 'Kenta Nishimoto',       5,  'M', '1994-07-24', 175, 'R', 2013, 'active',  NULL),
-- Women's singles
(16, 'An Seyoung',            4,  'F', '2002-02-05', 170, 'R', 2017, 'active',  NULL),
(17, 'Wang Zhiyi',            2,  'F', '2000-04-29', 172, 'R', 2017, 'active',  NULL),
(18, 'Akane Yamaguchi',       5,  'F', '1997-06-06', 156, 'R', 2012, 'active',  NULL),
(19, 'Chen Yufei',            2,  'F', '1998-03-01', 171, 'R', 2014, 'active',  NULL),
(20, 'Han Yue',               2,  'F', '1999-11-18', 168, 'R', 2016, 'active',  NULL),
(21, 'Putri Kusuma Wardani',  6,  'F', '2006-05-19', 165, 'R', 2021, 'active',  NULL),
(22, 'Ratchanok Intanon',     3,  'F', '1995-02-05', 169, 'R', 2009, 'active',  NULL),
(23, 'Pornpawee Chochuwong',  3,  'F', '1998-01-22', 172, 'R', 2016, 'active',  NULL),
(24, 'Tomoka Miyazaki',       5,  'F', '2006-01-13', 165, 'R', 2022, 'active',  NULL),
(25, 'Carolina Marin',        10, 'F', '1993-06-15', 172, 'L', 2009, 'active',  NULL),
(26, 'Tai Tzu-ying',          9,  'F', '1994-06-20', 163, 'R', 2011, 'retired', '2024-12-31'),  -- [REAL] retired after Paris 2024
(27, 'P V Sindhu',            8,  'F', '1995-07-05', 179, 'R', 2013, 'active',  NULL),
(28, 'Michelle Li',           13, 'F', '1991-08-12', 168, 'R', 2008, 'active',  NULL),
(29, 'Beiwen Zhang',          14, 'F', '1990-07-12', 168, 'R', 2008, 'active',  NULL),
(50, 'He Bingjiao',           2,  'F', '1997-03-21', 169, 'L', 2013, 'active',  NULL),
-- Men's doubles  (DOB/height [REPRESENTATIVE] where not widely published)
(30, 'Kim Won-ho',            4,  'M', '2002-09-04', 178, 'R', 2020, 'active',  NULL),
(31, 'Seo Seung-jae',         4,  'M', '1997-04-09', 180, 'R', 2016, 'active',  NULL),
(32, 'Aaron Chia',            7,  'M', '1997-02-17', 172, 'R', 2015, 'active',  NULL),
(33, 'Soh Wooi Yik',          7,  'M', '1998-01-05', 175, 'R', 2015, 'active',  NULL),
(34, 'Goh Sze Fei',           7,  'M', '1997-06-26', 170, 'R', 2017, 'active',  NULL),
(35, 'Nur Izzuddin',          7,  'M', '1997-11-12', 173, 'R', 2017, 'active',  NULL),
(36, 'Satwiksairaj Rankireddy',8, 'M', '2000-08-13', 180, 'R', 2017, 'active',  NULL),
(37, 'Chirag Shetty',         8,  'M', '1997-07-04', 183, 'R', 2017, 'active',  NULL),
(38, 'Liang Weikeng',         2,  'M', '1999-12-29', 178, 'R', 2017, 'active',  NULL),
(39, 'Wang Chang',            2,  'M', '2001-02-08', 182, 'R', 2018, 'active',  NULL),
-- Women's doubles
(40, 'Liu Shengshu',          2,  'F', '2000-03-12', 170, 'R', 2018, 'active',  NULL),
(41, 'Tan Ning',              2,  'F', '2002-07-19', 168, 'R', 2019, 'active',  NULL),
(42, 'Baek Ha-na',            4,  'F', '1999-12-06', 172, 'R', 2018, 'active',  NULL),
(43, 'Lee So-hee',            4,  'F', '1994-07-24', 167, 'R', 2012, 'active',  NULL),
(44, 'Chen Qingchen',         2,  'F', '1997-05-22', 162, 'R', 2014, 'active',  NULL),
(45, 'Jia Yifan',             2,  'F', '1997-04-10', 172, 'R', 2014, 'active',  NULL),
-- Mixed doubles
(46, 'Feng Yanzhe',           2,  'M', '2000-09-08', 180, 'R', 2018, 'active',  NULL),
(47, 'Huang Dongping',        2,  'F', '1996-12-26', 170, 'R', 2014, 'active',  NULL),
(48, 'Jiang Zhenbang',        2,  'M', '2002-01-15', 181, 'R', 2019, 'active',  NULL),
(49, 'Wei Yaxin',             2,  'F', '2003-03-30', 168, 'R', 2020, 'active',  NULL);


-- ============================================================================
-- 6. equipment
--    Rackets/shoes are real product lines [REAL]. balance/flex/weight_class
--    apply to rackets; NULL for non-rackets. msrp_usd is approximate.
-- ============================================================================
INSERT INTO equipment (equipment_id, brand_id, category_id, model_name, release_year, balance_type, flex_rating, weight_class, msrp_usd) VALUES
-- Rackets
(1,  1, 1, 'Astrox 100 ZZ',              2025, 'Head-Heavy', 'Extra Stiff', '4U', 259.00),
(2,  1, 1, 'Astrox 100 VA Edition',      2025, 'Head-Heavy', 'Extra Stiff', '4U', 279.00),
(3,  1, 1, 'Astrox 99 Pro (3rd Gen)',    2025, 'Head-Heavy', 'Stiff',       '4U', 245.00),
(4,  1, 1, 'Nanoflare 800 Pro',          2023, 'Head-Light', 'Stiff',       '4U', 235.00),
(5,  1, 1, 'Astrox 88 D Pro (3rd Gen)',  2024, 'Head-Heavy', 'Medium',      '4U', 219.00),
(6,  2, 1, 'Thruster Ryuga Metallic',    2023, 'Head-Heavy', 'Extra Stiff', '4U', 225.00),
(7,  2, 1, 'Auraspeed 90K II',           2024, 'Head-Light', 'Stiff',       '4U', 205.00),
(8,  2, 1, 'Brave Sword 12',             2022, 'Even',       'Medium',      '4U', 159.00),
(9,  2, 1, 'Thruster K Falcon',          2024, 'Head-Heavy', 'Stiff',       '4U', 189.00),
(10, 3, 1, 'Axforce 100',                2023, 'Head-Heavy', 'Stiff',       '4U', 229.00),
(11, 3, 1, 'Aeronaut 9000C',             2022, 'Head-Heavy', 'Stiff',       '3U', 209.00),
(12, 3, 1, 'Axforce 90 Dragon Max',      2024, 'Head-Heavy', 'Stiff',       '4U', 239.00),
(13, 3, 1, 'Bladex 900 Sun Max',         2024, 'Head-Heavy', 'Stiff',       '4U', 235.00),
(14, 6, 1, 'Satelite Gravity 74',        2023, 'Even',       'Medium',      '5U', 179.00),
(15, 5, 1, 'Power 988 M',                2022, 'Head-Heavy', 'Stiff',       '4U', 149.00),
(31, 2, 1, 'Thruster Ryuga II Pro',      2025, 'Head-Heavy', 'Extra Stiff', '4U', 239.00),   -- [REAL] Naraoka''s racket (victorsport.com)
-- Shoes
(16, 1, 2, 'Power Cushion 65 Z3',        2023, NULL, NULL, NULL, 149.00),
(17, 1, 2, 'Power Cushion Aerus Z2',     2024, NULL, NULL, NULL, 169.00),
(18, 4, 2, 'Gel-Blade 8',                2023, NULL, NULL, NULL, 109.00),
(19, 4, 2, 'Court Control FF 3',         2024, NULL, NULL, NULL, 129.00),
(20, 4, 2, 'Upcourt 6',                  2023, NULL, NULL, NULL, 69.00),
(21, 2, 2, 'A970 Nitro',                 2024, NULL, NULL, NULL, 139.00),
(22, 3, 2, 'Ranger Pro',                 2023, NULL, NULL, NULL, 119.00),
-- Strings
(23, 1, 3, 'BG65',                       1995, NULL, NULL, NULL, 11.00),
(24, 1, 3, 'Exbolt 65',                  2021, NULL, NULL, NULL, 17.00),
(25, 2, 3, 'VBS-70',                     2020, NULL, NULL, NULL, 14.00),
-- Shuttlecocks
(26, 1, 4, 'Aerosensa 50 (AS-50)',       2019, NULL, NULL, NULL, 35.00),
(27, 2, 4, 'Master Ace',                 2021, NULL, NULL, NULL, 30.00),
-- Apparel / Bag / Grip
(28, 4, 5, 'Court Performance Tee',      2025, NULL, NULL, NULL, 45.00),
(29, 1, 7, 'Pro Racket Bag 92429',       2024, NULL, NULL, NULL, 119.00),
(30, 1, 6, 'AC102 Super Grap (3-pack)',  2015, NULL, NULL, NULL, 5.00);


-- ============================================================================
-- 7. sponsorships  (formal brand deals)
--    Racket/full deals [REAL]. ASICS footwear rows marked [REPRESENTATIVE].
--    end_year NULL = current/ongoing.  is_signature_line: 1 = has own line.
-- ============================================================================
INSERT INTO sponsorships (sponsorship_id, player_id, brand_id, start_year, end_year, deal_type, is_signature_line) VALUES
(1,  13, 1, 2013, 2026, 'Full',     1),   -- [REAL] Axelsen Yonex, Astrox 100 VA signature line
(2,  1,  1, 2017, NULL, 'Racket',   0),   -- [REAL CORRECTION] Shi Yuqi uses Yonex Astrox 100ZZ (wears Li-Ning team apparel/shoes)
(3,  2,  1, 2019, NULL, 'Full',     0),   -- [REAL] Vitidsarn -> Yonex
(4,  3,  3, 2021, NULL, 'Full',     0),   -- [REAL] Antonsen -> Li-Ning
(5,  5,  1, 2015, NULL, 'Full',     0),   -- [REAL] Jonatan Christie -> Yonex
(6,  6,  2, 2010, NULL, 'Full',     0),   -- [REAL] Chou Tien-chen -> Victor
(7,  7,  3, 2017, NULL, 'Full',     0),   -- [REAL] Li Shifeng -> Li-Ning
(8,  8,  2, 2018, NULL, 'Full',     0),   -- [REAL] Lin Chun-yi -> Victor
(9,  9,  2, 2025, NULL, 'Full',     0),   -- [REAL CORRECTION] Naraoka -> Victor (Victor website confirms Team Victor, Thruster Ryuga II Pro)
(10, 10, 1, 2023, NULL, 'Racket',   0),   -- [REAL] Alex Lanier -> Yonex (Astrox 99 Pro)
(11, 11, 1, 2018, NULL, 'Full',     0),   -- [REAL] Lakshya Sen -> Yonex
(12, 12, 2, 2016, NULL, 'Full',     0),   -- [REAL] Loh Kean Yew -> Victor
(13, 14, 2, 2022, NULL, 'Full',     1),   -- [REAL] Lee Zii Jia -> Victor (signature)
(14, 15, 1, 2014, NULL, 'Full',     0),   -- [REAL] Nishimoto -> Yonex
(15, 16, 1, 2018, NULL, 'Full',     0),   -- [REAL] An Seyoung -> Yonex
(16, 17, 3, 2018, NULL, 'Full',     0),   -- [REAL] Wang Zhiyi -> Li-Ning
(17, 18, 1, 2013, NULL, 'Full',     0),   -- [REAL] Yamaguchi -> Yonex
(18, 19, 3, 2015, NULL, 'Full',     0),   -- [REAL] Chen Yufei -> Li-Ning
(19, 20, 3, 2017, NULL, 'Full',     0),   -- [REAL] Han Yue -> Li-Ning
(20, 22, 1, 2010, NULL, 'Full',     0),   -- [REAL] Ratchanok -> Yonex
(21, 25, 1, 2014, NULL, 'Full',     0),   -- [REAL] Carolina Marin -> Yonex
(22, 26, 2, 2011, 2024, 'Full',     1),   -- [REAL] Tai Tzu-ying -> Victor (signature, to retirement)
(23, 27, 1, 2018, NULL, 'Racket',   0),   -- [REAL] PV Sindhu -> Yonex racket
(24, 28, 1, 2012, NULL, 'Full',     0),   -- [REAL] Michelle Li -> Yonex
(25, 36, 1, 2018, NULL, 'Full',     0),   -- [REAL] Satwiksairaj -> Yonex
(26, 37, 1, 2018, NULL, 'Full',     0),   -- [REAL] Chirag Shetty -> Yonex
(27, 9,  4, 2022, NULL, 'Footwear', 0),   -- [REPRESENTATIVE] Naraoka ASICS footwear
(28, 11, 4, 2021, NULL, 'Footwear', 0);   -- [REPRESENTATIVE] Lakshya Sen ASICS footwear


-- ============================================================================
-- 8. player_equipment  (actual gear in the bag)
--    Racket/brand pairings [REAL]; shoe rows partly [REPRESENTATIVE].
--    is_primary: 1 = main gamer.  Many players carry brand + ASICS shoes.
-- ============================================================================
INSERT INTO player_equipment (player_equipment_id, player_id, equipment_id, is_primary, since_year, tension_main_lbs, tension_cross_lbs) VALUES
-- tension tags: [REAL] = player/official/dedicated article; [REPORTED] = single secondary compilation; NULL = not documented
(1,  13, 2,  1, 2025, 32, 34),     -- Axelsen -> Astrox 100 VA            [REAL] 32/34 lbs (BG-80, 10% prestretch; his own posts)
(2,  13, 17, 1, 2024, NULL, NULL), -- Axelsen -> Yonex Aerus Z2 shoes
(3,  1,  1,  1, 2023, 30, NULL),   -- Shi Yuqi -> Yonex Astrox 100ZZ      [REAL] ~30 lbs (BG-80 Power); no documented main/cross split
(4,  1,  22, 1, 2023, NULL, NULL), -- Shi Yuqi -> Li-Ning shoes
(5,  2,  5,  1, 2024, NULL, NULL), -- Vitidsarn -> Astrox 88 D Pro        (not documented)
(6,  3,  12, 1, 2024, NULL, NULL), -- Antonsen -> Li-Ning Axforce 90 DM   (not documented)
(7,  14, 6,  1, 2023, 31, 33),     -- Lee Zii Jia -> Thruster Ryuga       [REAL] 31/33 lbs (Team Victor / Galaxy Sports)
(8,  14, 21, 1, 2024, NULL, NULL), -- Lee Zii Jia -> Victor A970 shoes
(9,  26, 7,  1, 2022, 30, NULL),   -- Tai Tzu-ying -> Victor Auraspeed    [REPORTED] ~29-31 lbs range; no clean split
(10, 16, 3,  1, 2025, 28, 29),     -- An Seyoung -> Astrox 99 Pro         [REPORTED] 28/29 lbs (BG-80)
(11, 16, 16, 1, 2024, NULL, NULL), -- An Seyoung -> Yonex PC 65 Z3 shoes
(12, 27, 3,  1, 2025, 31, NULL),   -- PV Sindhu -> Astrox 99 Pro          [REPORTED] ~31 lbs; no documented split
(13, 27, 19, 0, 2024, NULL, NULL), -- PV Sindhu -> ASICS Court Control shoes
(14, 10, 3,  1, 2024, NULL, NULL), -- Alex Lanier -> Astrox 99 Pro        (not documented)
(15, 18, 1,  1, 2025, 24, 26),     -- Yamaguchi -> Astrox 100 ZZ          [REPORTED] 24/26 lbs (Exbolt 63)
(16, 19, 11, 1, 2022, 27, 29),     -- Chen Yufei -> Li-Ning Aeronaut 9000 [REPORTED] 27/29 lbs (BG-80 Power)
(17, 25, 1,  1, 2025, NULL, NULL), -- Carolina Marin -> Astrox 100 ZZ     (not documented)
(18, 11, 1,  1, 2023, NULL, NULL), -- Lakshya Sen -> Astrox 100 ZZ        (not documented)
(19, 11, 18, 0, 2022, NULL, NULL), -- Lakshya Sen -> ASICS Gel-Blade 8 shoes
(20, 12, 9,  1, 2024, NULL, NULL), -- Loh Kean Yew -> Victor Thruster K   (not documented)
(21, 6,  8,  1, 2022, NULL, NULL), -- Chou Tien-chen -> Victor Brave Sword(not documented)
(22, 8,  6,  1, 2023, NULL, NULL), -- Lin Chun-yi -> Victor Thruster Ryuga(not documented)
(23, 9,  31, 1, 2025, NULL, NULL), -- Naraoka -> Victor Thruster Ryuga II Pro (not documented)
(24, 9,  19, 0, 2022, NULL, NULL), -- Naraoka -> ASICS Court Control shoes
(25, 17, 13, 1, 2024, NULL, NULL), -- Wang Zhiyi -> Li-Ning Bladex 900    (not documented)
(26, 20, 10, 1, 2023, NULL, NULL), -- Han Yue -> Li-Ning Axforce 100      (not documented)
(27, 36, 5,  1, 2023, NULL, NULL), -- Satwiksairaj -> Astrox 88 D Pro     (not documented)
(28, 37, 5,  1, 2023, NULL, NULL), -- Chirag Shetty -> Astrox 88 D Pro    (not documented)
(29, 13, 24, 0, 2024, NULL, NULL), -- Axelsen -> Exbolt 65 string
(30, 16, 24, 0, 2024, NULL, NULL), -- An Seyoung -> Exbolt 65 string
(31, 14, 25, 0, 2024, NULL, NULL); -- Lee Zii Jia -> Victor VBS-70 string


-- ============================================================================
-- 9. partnerships  (doubles teams)  [REAL pairings]
-- ============================================================================
INSERT INTO partnerships (partnership_id, discipline_id, player1_id, player2_id, formed_year, status) VALUES
(1,  3, 30, 31, 2023, 'active'),   -- Kim Won-ho / Seo Seung-jae (MD)
(2,  3, 32, 33, 2017, 'active'),   -- Aaron Chia / Soh Wooi Yik (MD)
(3,  3, 34, 35, 2019, 'active'),   -- Goh Sze Fei / Nur Izzuddin (MD)
(4,  3, 36, 37, 2017, 'active'),   -- Satwiksairaj / Chirag Shetty (MD)
(5,  3, 38, 39, 2021, 'active'),   -- Liang Weikeng / Wang Chang (MD)
(6,  4, 40, 41, 2023, 'active'),   -- Liu Shengshu / Tan Ning (WD)
(7,  4, 42, 43, 2022, 'active'),   -- Baek Ha-na / Lee So-hee (WD)
(8,  4, 44, 45, 2015, 'active'),   -- Chen Qingchen / Jia Yifan (WD)
(9,  5, 46, 47, 2022, 'active'),   -- Feng Yanzhe / Huang Dongping (XD)
(10, 5, 48, 49, 2022, 'active');   -- Jiang Zhenbang / Wei Yaxin (XD)


-- ============================================================================
-- 10. coaches  ([REAL] names; some pairings below are [REPRESENTATIVE])
-- ============================================================================
INSERT INTO coaches (coach_id, full_name, country_id) VALUES
(1, 'Kenneth Jonassen', 1),   -- long-time Axelsen coach
(2, 'Park Tae-sang',    4),   -- coached PV Sindhu
(3, 'Indra Wijaya',     6),   -- Lee Zii Jia's coach
(4, 'Mathias Boe',      1);   -- former MD player, now a coach


-- ============================================================================
-- 11. player_coach  (end_year NULL = current)
-- ============================================================================
INSERT INTO player_coach (player_id, coach_id, start_year, end_year) VALUES
(13, 1, 2016, 2026),   -- Axelsen / Jonassen           [REAL]
(14, 3, 2022, NULL),   -- Lee Zii Jia / Indra Wijaya   [REAL]
(27, 2, 2021, 2022),   -- PV Sindhu / Park Tae-sang    [REAL]
(11, 4, 2024, NULL);   -- Lakshya Sen / Mathias Boe    [REPRESENTATIVE]


-- ============================================================================
-- 12. tournaments  (the series itself)  [REAL]
--    tier: Olympics / World Championships / World Tour Finals / Super 1000 /
--          Super 750 / Super 500.  prize_money_usd is approximate.
-- ============================================================================
INSERT INTO tournaments (tournament_id, tournament_name, tier, prize_money_usd) VALUES
(1,  'Olympic Games',          'Olympics',           NULL),
(2,  'BWF World Championships','World Championships', 850000),
(3,  'All England Open',       'Super 1000',         1250000),
(4,  'Malaysia Open',          'Super 1000',         1300000),
(5,  'Indonesia Open',         'Super 1000',         1300000),
(6,  'China Open',             'Super 1000',         2000000),
(7,  'BWF World Tour Finals',  'World Tour Finals',  2500000),
(8,  'Denmark Open',           'Super 750',          850000),
(9,  'Japan Open',             'Super 750',          850000),
(10, 'India Open',             'Super 750',          950000),
(11, 'Thailand Open',          'Super 500',          475000),
(12, 'Hong Kong Open',         'Super 500',          500000);


-- ============================================================================
-- 13. tournament_editions  (a specific year of a series)  [REAL dates/hosts]
-- ============================================================================
INSERT INTO tournament_editions (edition_id, tournament_id, edition_year, start_date, end_date, host_country_id, host_city) VALUES
(1,  1,  2024, '2024-07-27', '2024-08-05', 11, 'Paris'),
(2,  2,  2023, '2023-08-21', '2023-08-27', 1,  'Copenhagen'),
(3,  2,  2025, '2025-08-25', '2025-08-31', 11, 'Paris'),
(4,  3,  2024, '2024-03-12', '2024-03-17', 16, 'Birmingham'),
(5,  3,  2025, '2025-03-11', '2025-03-16', 16, 'Birmingham'),
(6,  3,  2026, '2026-03-10', '2026-03-15', 16, 'Birmingham'),
(7,  4,  2026, '2026-01-06', '2026-01-11', 7,  'Kuala Lumpur'),
(8,  5,  2025, '2025-06-03', '2025-06-08', 6,  'Jakarta'),
(9,  6,  2025, '2025-09-16', '2025-09-21', 2,  'Changzhou'),
(10, 7,  2025, '2025-12-10', '2025-12-14', 2,  'Hangzhou'),
(11, 8,  2025, '2025-10-14', '2025-10-19', 1,  'Odense'),
(12, 9,  2025, '2025-07-15', '2025-07-20', 5,  'Tokyo'),
(13, 10, 2026, '2026-01-13', '2026-01-18', 8,  'New Delhi'),
(14, 11, 2026, '2026-05-13', '2026-05-18', 3,  'Bangkok'),
(15, 12, 2025, '2025-09-09', '2025-09-14', 18, 'Hong Kong');


-- ============================================================================
-- 14. tournament_results  (final standings; player_id for singles,
--     partnership_id for doubles — the unused one is NULL)
--     finish: 'Champion' / 'Runner-up' / 'Bronze' / 'Semi-finalist'
-- ============================================================================
INSERT INTO tournament_results (result_id, edition_id, discipline_id, player_id, partnership_id, finish) VALUES
-- Paris 2024 Olympics                                                  [REAL]
(1,  1, 1, 13, NULL, 'Champion'),     -- Axelsen MS gold
(2,  1, 1, 2,  NULL, 'Runner-up'),    -- Vitidsarn MS silver
(3,  1, 1, 14, NULL, 'Bronze'),       -- Lee Zii Jia MS bronze
(4,  1, 1, 11, NULL, 'Semi-finalist'),-- Lakshya Sen 4th
(5,  1, 2, 16, NULL, 'Champion'),     -- An Seyoung WS gold
(6,  1, 2, 50, NULL, 'Runner-up'),    -- He Bingjiao WS silver
(7,  1, 2, 25, NULL, 'Semi-finalist'),-- Carolina Marin (retired injured in SF)
-- 2023 World Championships (Copenhagen)                                [REAL]
(8,  2, 1, 2,  NULL, 'Champion'),     -- Vitidsarn MS
(9,  2, 2, 25, NULL, 'Champion'),     -- Carolina Marin WS
-- 2025 World Championships (Paris)                                     [REAL]
(10, 3, 2, 18, NULL, 'Champion'),     -- Yamaguchi WS (3rd world title)
-- 2026 All England                                                     [REAL]
(11, 6, 1, 8,  NULL, 'Champion'),     -- Lin Chun-yi MS
(12, 6, 1, 11, NULL, 'Runner-up'),    -- Lakshya Sen MS
-- Selected series winners                                  [REPRESENTATIVE]
(13, 9,  1, 1,  NULL, 'Champion'),    -- Shi Yuqi China Open 2025
(14, 10, 1, 1,  NULL, 'Champion'),    -- Shi Yuqi WT Finals 2025
(15, 10, 2, 16, NULL, 'Champion'),    -- An Seyoung WT Finals 2025
(16, 8,  3, NULL, 4,  'Champion'),    -- Satwik/Chirag Indonesia Open 2025
(17, 9,  4, NULL, 8,  'Champion');    -- Chen Qingchen/Jia Yifan China Open 2025


-- ============================================================================
-- 15. matches
--     Singles: side1_player2_id / side2_player2_id are NULL.
--     winner_side: 1 or 2.  Olympic & All England finals/bronze are [REAL]
--     scorelines; other rows are [REPRESENTATIVE] match scores.
-- ============================================================================
INSERT INTO matches (match_id, edition_id, discipline_id, round, match_date, side1_player1_id, side1_player2_id, side2_player1_id, side2_player2_id, winner_side, score_summary, duration_minutes) VALUES
(1, 1, 1, 'Final',         '2024-08-05', 13, NULL, 2,  NULL, 1, '21-11, 21-11',        52),   -- [REAL]
(2, 1, 1, 'Bronze',        '2024-08-05', 14, NULL, 11, NULL, 1, '13-21, 21-16, 21-11', 65),   -- [REAL]
(3, 1, 2, 'Final',         '2024-08-05', 16, NULL, 50, NULL, 1, '21-8, 21-13',         41),   -- [REAL]
(4, 6, 1, 'Final',         '2026-03-15', 8,  NULL, 11, NULL, 1, '21-18, 19-21, 21-16', 71),   -- [REPRESENTATIVE score], [REAL result]
(5, 9, 1, 'Final',         '2025-09-21', 1,  NULL, 3,  NULL, 1, '21-15, 21-18',        58),   -- [REPRESENTATIVE]
(6, 10,1, 'Final',         '2025-12-14', 1,  NULL, 2,  NULL, 1, '21-19, 18-21, 21-17', 79),   -- [REPRESENTATIVE]
(7, 10,2, 'Final',         '2025-12-14', 16, NULL, 17, NULL, 1, '21-16, 21-14',        49),   -- [REPRESENTATIVE]
(8, 12,1, 'Semi-final',    '2025-07-19', 9,  NULL, 5,  NULL, 1, '21-17, 21-19',        54),   -- [REPRESENTATIVE]
(9, 12,1, 'Final',         '2025-07-20', 9,  NULL, 7,  NULL, 2, '19-21, 21-15, 21-12', 68),   -- [REPRESENTATIVE]
(10,8, 3, 'Final',         '2025-06-08', 36, 37,  34, 35,   1, '21-18, 21-16',        47),   -- [REPRESENTATIVE]
(11,9, 4, 'Final',         '2025-09-21', 44, 45,  40, 41,   1, '21-19, 23-21',        56),   -- [REPRESENTATIVE]
(12,11,5, 'Final',         '2025-10-19', 46, 47,  48, 49,   1, '21-17, 21-19',        44),   -- [REPRESENTATIVE]
(13,5, 1, 'Quarter-final', '2025-03-13', 10, NULL, 6,  NULL, 1, '21-18, 21-23, 21-19', 73),  -- [REPRESENTATIVE]
(14,5, 2, 'Semi-final',    '2025-03-14', 18, NULL, 19, NULL, 1, '21-15, 17-21, 21-18', 66),  -- [REPRESENTATIVE]
(15,14,1, 'Quarter-final', '2026-05-16', 11, NULL, 12, NULL, 2, '18-21, 21-16, 21-14', 70);   -- [REPRESENTATIVE]


-- ============================================================================
-- 16. match_games  (set-by-set detail for the matches above)
--     [REAL] for matches 1-3, [REPRESENTATIVE] otherwise.
-- ============================================================================
INSERT INTO match_games (game_id, match_id, game_number, side1_points, side2_points) VALUES
(1,  1, 1, 21, 11), (2,  1, 2, 21, 11),                       -- [REAL]
(3,  2, 1, 13, 21), (4,  2, 2, 21, 16), (5,  2, 3, 21, 11),   -- [REAL]
(6,  3, 1, 21, 8),  (7,  3, 2, 21, 13),                       -- [REAL]
(8,  4, 1, 21, 18), (9,  4, 2, 19, 21), (10, 4, 3, 21, 16),
(11, 5, 1, 21, 15), (12, 5, 2, 21, 18),
(13, 6, 1, 21, 19), (14, 6, 2, 18, 21), (15, 6, 3, 21, 17),
(16, 7, 1, 21, 16), (17, 7, 2, 21, 14),
(18, 9, 1, 19, 21), (19, 9, 2, 21, 15), (20, 9, 3, 21, 12);


-- ============================================================================
-- 17. player_rankings  (snapshots; singles use player_id, doubles use
--     partnership_id).  Ranks/points ~Apr 2026 are [REAL] unless noted.
--     Historical rows included so you can chart performance trends.
-- ============================================================================
INSERT INTO player_rankings (ranking_id, player_id, partnership_id, discipline_id, rank_position, ranking_points, ranking_date) VALUES
-- Men's singles, 2026-04-13                                            [REAL]
(1,  1,  NULL, 1, 1,  105967, '2026-04-13'),
(2,  2,  NULL, 1, 2,  97179,  '2026-04-13'),
(3,  3,  NULL, 1, 3,  93829,  '2026-04-13'),
(4,  4,  NULL, 1, 4,  84705,  '2026-04-13'),
(5,  5,  NULL, 1, 5,  84174,  '2026-04-13'),
(6,  6,  NULL, 1, 6,  81689,  '2026-04-13'),
(7,  7,  NULL, 1, 7,  75128,  '2026-04-13'),
(8,  8,  NULL, 1, 8,  72838,  '2026-04-13'),
(9,  9,  NULL, 1, 9,  69654,  '2026-04-13'),
(10, 10, NULL, 1, 10, 68565,  '2026-04-13'),
(11, 11, NULL, 1, 11, 67057,  '2026-04-13'),
(12, 12, NULL, 1, 12, 65980,  '2026-04-13'),
(13, 15, NULL, 1, 16, 56099,  '2026-04-13'),
-- Women's singles, 2026-04-13                                          [REAL except noted]
(14, 16, NULL, 2, 1,  115000, '2026-04-13'),   -- [REPRESENTATIVE points] An Seyoung #1 [REAL rank]
(15, 17, NULL, 2, 2,  107689, '2026-04-13'),
(16, 18, NULL, 2, 3,  96876,  '2026-04-13'),
(17, 19, NULL, 2, 4,  90251,  '2026-04-13'),
(18, 20, NULL, 2, 5,  86288,  '2026-04-13'),
(19, 21, NULL, 2, 6,  75223,  '2026-04-13'),
(20, 22, NULL, 2, 7,  72616,  '2026-04-13'),
(21, 23, NULL, 2, 8,  64977,  '2026-04-13'),
(22, 24, NULL, 2, 9,  61076,  '2026-04-13'),
(23, 28, NULL, 2, 10, 58577,  '2026-04-13'),
(24, 27, NULL, 2, 11, 58051,  '2026-04-13'),
-- Historical singles snapshots for trend analysis
(25, 13, NULL, 1, 1,  104500, '2024-08-06'),   -- [REAL] Axelsen #1 post-Paris
(26, 13, NULL, 1, 2,  98300,  '2025-12-16'),   -- [REPRESENTATIVE] pre-retirement slide
(27, 26, NULL, 2, 1,  98000,  '2024-01-09'),   -- [REPRESENTATIVE] Tai Tzu-ying #1 pre-retirement
(28, 25, NULL, 2, 9,  64796,  '2025-02-04'),   -- [REAL] Carolina Marin comeback ranking
-- Men's doubles, ~2026-04-14                                           [REAL pairings]
(29, NULL, 1, 3, 1, 120000, '2026-04-14'),     -- [REPRESENTATIVE points] Kim Won-ho/Seo Seung-jae #1 (near record)
(30, NULL, 3, 3, 2, 95000,  '2026-04-14'),     -- [REPRESENTATIVE] Goh Sze Fei/Nur Izzuddin
(31, NULL, 2, 3, 3, 91000,  '2026-04-14'),     -- [REPRESENTATIVE] Aaron Chia/Soh Wooi Yik
(32, NULL, 4, 3, 4, 88000,  '2026-04-14'),     -- [REPRESENTATIVE] Satwik/Chirag
-- Women's doubles & mixed doubles, ~2026-04                            [REAL pairings]
(33, NULL, 6, 4, 1, 102000, '2026-04-14'),     -- [REPRESENTATIVE] Liu Shengshu/Tan Ning
(34, NULL, 8, 4, 2, 97000,  '2026-04-14'),     -- [REPRESENTATIVE] Chen Qingchen/Jia Yifan
(35, NULL, 9, 5, 1, 99000,  '2026-04-14'),     -- [REPRESENTATIVE] Feng Yanzhe/Huang Dongping
(36, NULL, 10,5, 2, 96000,  '2026-04-14');     -- [REPRESENTATIVE] Jiang Zhenbang/Wei Yaxin


-- ============================================================================
-- 18. player_season_stats  (aggregate season form — all [REPRESENTATIVE])
--     Use these for win-rate and performance-trend queries.
-- ============================================================================
INSERT INTO player_season_stats (stat_id, player_id, season_year, discipline_id, matches_played, matches_won, matches_lost, titles, finals_reached) VALUES
(1,  1,  2025, 1, 62, 51, 11, 5, 7),
(2,  2,  2025, 1, 58, 44, 14, 3, 5),
(3,  3,  2025, 1, 55, 40, 15, 2, 4),
(4,  13, 2025, 1, 41, 33, 8,  3, 5),
(5,  14, 2025, 1, 57, 39, 18, 2, 4),
(6,  11, 2025, 1, 60, 41, 19, 1, 3),
(7,  16, 2025, 2, 64, 57, 7,  8, 10),
(8,  17, 2025, 2, 59, 46, 13, 4, 6),
(9,  18, 2025, 2, 56, 43, 13, 3, 5),
(10, 19, 2025, 2, 54, 40, 14, 2, 4),
(11, 27, 2025, 2, 48, 30, 18, 1, 2),
(12, 1,  2024, 1, 60, 47, 13, 4, 6),
(13, 16, 2024, 2, 55, 50, 5,  9, 11),
(14, 13, 2024, 1, 50, 42, 8,  4, 6);
