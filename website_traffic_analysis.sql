-- =====================================================================
-- WEBSITE TRAFFIC ANALYSIS
-- Standard SQL (MySQL)
-- Author: Reha arif
-- =====================================================================
-- Dataset assumption: one row per (date, traffic_source, page_url)
-- combination that received traffic -- similar in grain to a daily
-- Google Analytics export. session_id / user_id are included as optional
-- raw identifiers a granular analytics feed might provide; this table
-- stores the pre-aggregated daily grain typically used for reporting.
-- =====================================================================


-- =====================================================================
-- SECTION 1: TABLE CREATION
-- =====================================================================

DROP TABLE IF EXISTS website_traffic;

CREATE TABLE website_traffic (
    record_id               SERIAL PRIMARY KEY,                -- surrogate key per row
    session_id                VARCHAR(50),                       -- optional raw session identifier (if available)
    user_id                     VARCHAR(50),                      -- optional raw user identifier (if available)
    traffic_date                  DATE            NOT NULL,        -- date of the traffic record
    traffic_source                  VARCHAR(30)     NOT NULL         -- acquisition channel
                                    CHECK (traffic_source IN ('Organic Search', 'Paid Search', 'Referral', 'Social', 'Direct')),
    page_url                          VARCHAR(255)    NOT NULL,       -- page path, e.g. '/checkout'
    sessions                            INT             CHECK (sessions >= 0),
    users                                  INT             CHECK (users >= 0),
    bounce_rate                             DECIMAL(5,4)    CHECK (bounce_rate BETWEEN 0 AND 1),  -- stored as a 0-1 fraction
    session_duration                          DECIMAL(7,2)    CHECK (session_duration >= 0),        -- avg duration, seconds
    pages_per_session                           DECIMAL(4,2)    CHECK (pages_per_session >= 0),
    conversions                                   INT             CHECK (conversions >= 0),
    goal_completions                                INT             CHECK (goal_completions >= 0),

    -- A given date + source + page combination should only appear once
    CONSTRAINT uq_date_source_page UNIQUE (traffic_date, traffic_source, page_url)
);

-- Helpful indexes for the analytical queries below
CREATE INDEX idx_wt_date   ON website_traffic (traffic_date);
CREATE INDEX idx_wt_source ON website_traffic (traffic_source);
CREATE INDEX idx_wt_page   ON website_traffic (page_url);


-- =====================================================================
-- SECTION 2: DATA CLEANING QUERIES
-- =====================================================================

-- 2.1 Find rows with NULL values in key metric columns
SELECT *
FROM website_traffic
WHERE sessions IS NULL
   OR bounce_rate IS NULL
   OR session_duration IS NULL
   OR pages_per_session IS NULL
   OR conversions IS NULL;

-- 2.2 Fill NULL bounce_rate with the (source, page) average bounce rate
UPDATE website_traffic wt
SET bounce_rate = (
    SELECT ROUND(AVG(wt2.bounce_rate), 4)
    FROM website_traffic wt2
    WHERE wt2.traffic_source = wt.traffic_source
      AND wt2.page_url = wt.page_url
      AND wt2.bounce_rate IS NOT NULL
)
WHERE wt.bounce_rate IS NULL;

-- 2.3 Fill NULL session_duration and pages_per_session with the overall average
UPDATE website_traffic
SET session_duration = (
    SELECT ROUND(AVG(session_duration), 2)
    FROM website_traffic
    WHERE session_duration IS NOT NULL
)
WHERE session_duration IS NULL;

UPDATE website_traffic
SET pages_per_session = (
    SELECT ROUND(AVG(pages_per_session), 2)
    FROM website_traffic
    WHERE pages_per_session IS NOT NULL
)
WHERE pages_per_session IS NULL;

-- 2.4 Fill NULL conversions with 0 (absence of a recorded conversion event
--     is treated as zero conversions, not an unknown value)
UPDATE website_traffic
SET conversions = 0
WHERE conversions IS NULL;

-- 2.5 Identify duplicate rows (same date + source + page appearing more than once)
SELECT traffic_date, traffic_source, page_url, COUNT(*) AS duplicate_count
FROM website_traffic
GROUP BY traffic_date, traffic_source, page_url
HAVING COUNT(*) > 1;

-- 2.6 Remove duplicate rows, keeping only the lowest record_id per (date, source, page)
DELETE FROM website_traffic
WHERE record_id NOT IN (
    SELECT MIN(record_id)
    FROM website_traffic
    GROUP BY traffic_date, traffic_source, page_url
);

-- 2.7 Identify invalid session/duration/bounce-rate values (data entry or tracking errors)
SELECT *
FROM website_traffic
WHERE sessions < 0
   OR session_duration < 0
   OR bounce_rate < 0 OR bounce_rate > 1;

-- 2.8 Correct invalid values: negative sessions/duration are data errors -> remove;
--     out-of-range bounce_rate is capped to the valid 0-1 bounds
DELETE FROM website_traffic
WHERE sessions < 0 OR session_duration < 0;

UPDATE website_traffic
SET bounce_rate = CASE
                      WHEN bounce_rate > 1 THEN 1
                      WHEN bounce_rate < 0 THEN 0
                      ELSE bounce_rate
                   END
WHERE bounce_rate > 1 OR bounce_rate < 0;

-- 2.9 Standardize text fields (trim whitespace, consistent casing)
UPDATE website_traffic
SET traffic_source = INITCAP(TRIM(traffic_source)); 


-- =====================================================================
-- SECTION 3: TOTAL SESSIONS, USERS, AND BOUNCE RATE BY DATE
-- =====================================================================

-- 3.1 Daily trend
SELECT
    traffic_date,
    SUM(sessions)                                          AS total_sessions,
    SUM(users)                                             AS total_users,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)  AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY traffic_date
ORDER BY traffic_date;

-- 3.2 Monthly trend
SELECT
    DATE_TRUNC('month', traffic_date)                       AS traffic_month,  
    SUM(sessions)                                           AS total_sessions,
    SUM(users)                                              AS total_users,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)   AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY DATE_TRUNC('month', traffic_date)
ORDER BY traffic_month;


-- =====================================================================
-- SECTION 4: TRAFFIC SOURCE-WISE PERFORMANCE
-- =====================================================================

-- Sessions, conversions, and conversion rate per traffic source
SELECT
    traffic_source,
    SUM(sessions)                                                    AS total_sessions,
    SUM(conversions)                                                 AS total_conversions,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(sessions), 0), 2)    AS conversion_rate_pct,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)            AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY traffic_source
ORDER BY total_sessions DESC;


-- =====================================================================
-- SECTION 5: TOP AND BOTTOM PERFORMING PAGES
-- =====================================================================

-- 5.1 Top 5 pages by total sessions (pageviews proxy)
SELECT
    page_url,
    SUM(sessions)                                            AS total_sessions,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)    AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY page_url
ORDER BY total_sessions DESC
LIMIT 5;

-- 5.2 Bottom 5 pages by total sessions
SELECT
    page_url,
    SUM(sessions)                                            AS total_sessions,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)    AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY page_url
ORDER BY total_sessions ASC
LIMIT 5;

-- 5.3 Top 5 pages by LOWEST bounce rate (best engagement / "exit" behavior)
SELECT
    page_url,
    SUM(sessions)                                            AS total_sessions,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)    AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY page_url
ORDER BY weighted_avg_bounce_rate ASC
LIMIT 5;

-- 5.4 Bottom 5 pages by HIGHEST bounce rate (worst engagement / "exit" behavior)
SELECT
    page_url,
    SUM(sessions)                                            AS total_sessions,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)    AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY page_url
ORDER BY weighted_avg_bounce_rate DESC
LIMIT 5;


-- =====================================================================
-- SECTION 6: USER ENGAGEMENT METRICS
-- =====================================================================

-- Average session duration and pages/session by traffic source
SELECT
    traffic_source,
    ROUND(SUM(session_duration * sessions) / SUM(sessions), 2)     AS weighted_avg_session_duration,
    ROUND(SUM(pages_per_session * sessions) / SUM(sessions), 2)    AS weighted_avg_pages_per_session,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)          AS weighted_avg_bounce_rate
FROM website_traffic
GROUP BY traffic_source
ORDER BY weighted_avg_session_duration DESC;


-- =====================================================================
-- SECTION 7: CONVERSION RATE AND GOAL COMPLETION ANALYSIS
-- =====================================================================

-- 7.1 By traffic source
SELECT
    traffic_source,
    SUM(sessions)                                                   AS total_sessions,
    SUM(conversions)                                                AS total_conversions,
    SUM(goal_completions)                                           AS total_goal_completions,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(sessions), 0), 2)   AS conversion_rate_pct
FROM website_traffic
GROUP BY traffic_source
ORDER BY conversion_rate_pct DESC;

-- 7.2 By page
SELECT
    page_url,
    SUM(sessions)                                                   AS total_sessions,
    SUM(conversions)                                                AS total_conversions,
    SUM(goal_completions)                                           AS total_goal_completions,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(sessions), 0), 2)   AS conversion_rate_pct
FROM website_traffic
GROUP BY page_url
ORDER BY conversion_rate_pct DESC;


-- =====================================================================
-- SECTION 8: MONTH-OVER-MONTH TRAFFIC GROWTH / DECLINE
-- =====================================================================

-- Uses a window function (LAG) to compare each month's sessions to the
-- previous month's sessions and compute percentage growth/decline.
WITH monthly_sessions AS (
    SELECT
        DATE_TRUNC('month', traffic_date)  AS traffic_month,   -- MySQL: DATE_FORMAT(traffic_date, '%Y-%m-01')
        SUM(sessions)                      AS total_sessions
    FROM website_traffic
    GROUP BY DATE_TRUNC('month', traffic_date)
)
SELECT
    traffic_month,
    total_sessions,
    LAG(total_sessions) OVER (ORDER BY traffic_month)         AS prev_month_sessions,
    ROUND(
        100.0 * (total_sessions - LAG(total_sessions) OVER (ORDER BY traffic_month))
        / NULLIF(LAG(total_sessions) OVER (ORDER BY traffic_month), 0),
        2
    )                                                          AS mom_growth_pct
FROM monthly_sessions
ORDER BY traffic_month;


-- =====================================================================
-- SECTION 9: HIGH-BOUNCE, LOW-ENGAGEMENT PAGES NEEDING IMPROVEMENT
-- =====================================================================

-- Pages with above-average bounce rate AND below-average pages/session,
-- weighted by traffic volume -- these are the clearest improvement
-- candidates since they combine poor stickiness with meaningful reach.
WITH page_stats AS (
    SELECT
        page_url,
        SUM(sessions)                                                AS total_sessions,
        SUM(bounce_rate * sessions) / SUM(sessions)                  AS weighted_avg_bounce_rate,
        SUM(pages_per_session * sessions) / SUM(sessions)            AS weighted_avg_pages_per_session
    FROM website_traffic
    GROUP BY page_url
),
overall_avgs AS (
    SELECT
        SUM(bounce_rate * sessions) / SUM(sessions)         AS overall_avg_bounce_rate,
        SUM(pages_per_session * sessions) / SUM(sessions)   AS overall_avg_pages_per_session
    FROM website_traffic
)
SELECT
    ps.page_url,
    ps.total_sessions,
    ROUND(ps.weighted_avg_bounce_rate, 4)        AS avg_bounce_rate,
    ROUND(ps.weighted_avg_pages_per_session, 2)  AS avg_pages_per_session
FROM page_stats ps
CROSS JOIN overall_avgs oa
WHERE ps.weighted_avg_bounce_rate > oa.overall_avg_bounce_rate
  AND ps.weighted_avg_pages_per_session < oa.overall_avg_pages_per_session
ORDER BY ps.weighted_avg_bounce_rate DESC;


-- =====================================================================
-- SECTION 10: SUMMARY / KPI QUERY
-- =====================================================================

-- Single summary row combining total sessions, total conversions,
-- overall conversion rate, and average bounce rate.
SELECT
    SUM(sessions)                                                    AS total_sessions,
    SUM(users)                                                       AS total_users,
    SUM(conversions)                                                 AS total_conversions,
    ROUND(100.0 * SUM(conversions) / NULLIF(SUM(sessions), 0), 2)    AS overall_conversion_rate_pct,
    ROUND(SUM(bounce_rate * sessions) / SUM(sessions), 4)            AS avg_bounce_rate,
    ROUND(SUM(session_duration * sessions) / SUM(sessions), 2)       AS avg_session_duration,
    ROUND(SUM(pages_per_session * sessions) / SUM(sessions), 2)      AS avg_pages_per_session
FROM website_traffic;

-- =====================================================================
-- END OF FILE
-- =====================================================================
