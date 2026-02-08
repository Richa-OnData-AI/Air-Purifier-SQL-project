create database AQI;
use AQI;
select * from aqi;
select * from idsp;	
select* from population_projection;
select * from vahan;

-- Question 1: Top 5 and bottom 5 areas with highest average AQI (Dec 2024 to May 2026)
 
select area, round(avg(aqi_value),2), count(*) as observation_count
from aqi 
where str_to_date(date,"%d-%m-%Y") between "2024-12-01" and "2026-05-31"
and aqi_value is not null 
group by area 
having observation_count >0 
order by observation_count asc 
limit 5; 
select area, round(avg(aqi_value),2), count(*) as observation_count
from aqi 
where str_to_date(date,"%d-%m-%Y") between "2024-12-01" and "2026-05-31"
and aqi_value is not null 
group by area 
having observation_count >0 
order by observation_count desc 
limit 5;
-- Question 2: Top 2 and bottom 2 prominent pollutants for each Southern state (2022 onward)
WITH PollutantCounts AS (
    SELECT 
        state,
        prominent_pollutants,
        COUNT(*) AS pollutant_count,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY COUNT(*) DESC) AS rn_desc,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY COUNT(*) ASC) AS rn_asc
    FROM aqi
    WHERE str_to_date(date,"%d-%m-%Y") >=2025
        AND state IN ('Andhra Pradesh', 'Telangana', 'Karnataka', 'Kerala', 'Tamil Nadu')
    GROUP BY state, prominent_pollutants
)
SELECT 
    state,
    GROUP_CONCAT(CASE WHEN rn_desc <= 2 THEN prominent_pollutants END ORDER BY rn_desc) AS top_2_pollutants,
    GROUP_CONCAT(CASE WHEN rn_asc <= 2 THEN prominent_pollutants END ORDER BY rn_asc) AS bottom_2_pollutants
FROM PollutantCounts
WHERE rn_desc <= 2 OR rn_asc <= 2
GROUP BY state;

-- Question 3: AQI improve on weekends vs weekdays in metro cities (last 1 year from max date)
WITH MetroAQI AS (
    SELECT 
        area,
        CASE WHEN DAYOFWEEK(str_to_date(date,"%d-%m-%Y")) IN (1, 7) THEN 'Weekend' ELSE 'Weekday' END AS day_type,
        aqi_value
    FROM aqi
    WHERE str_to_date(date,"%d-%m-%Y") BETWEEN (SELECT MAX(str_to_date(date,"%d-%m-%Y")) - INTERVAL 1 YEAR FROM aqi) AND (SELECT MAX(str_to_date(date,"%d-%m-%Y")) FROM aqi)
        AND area IN ('Delhi', 'Mumbai', 'Chennai', 'Kolkata', 'Bengaluru', 'Hyderabad', 'Ahmedabad', 'Pune')
        AND aqi_value IS NOT NULL
)
SELECT 
    area,
    ROUND(AVG(CASE WHEN day_type = 'Weekday' THEN aqi_value END), 2) AS weekday_avg_aqi,
    ROUND(AVG(CASE WHEN day_type = 'Weekend' THEN aqi_value END), 2) AS weekend_avg_aqi,
    ROUND(((AVG(CASE WHEN day_type = 'Weekday' THEN aqi_value END) - 
            AVG(CASE WHEN day_type = 'Weekend' THEN aqi_value END)) /
           AVG(CASE WHEN day_type = 'Weekday' THEN aqi_value END) * 100), 2) AS improvement_pct
FROM MetroAQI
GROUP BY area;

-- Question 4: Months consistently show worst air quality across top 10 states with high distinct areas
WITH TopStates AS (
    SELECT state
    FROM aqi
    GROUP BY state
    ORDER BY COUNT(DISTINCT area) DESC
    LIMIT 10
),
MonthlyAQI AS (
    SELECT 
        a.state,
        MONTH(a.date) AS month,
        AVG(a.aqi_value) AS avg_aqi
    FROM aqi a
    JOIN TopStates t ON a.state = t.state
    WHERE a.aqi_value IS NOT NULL
    GROUP BY a.state, MONTH(a.date)
),
WorstMonths AS (
    SELECT 
        state,
        month,
        avg_aqi,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY avg_aqi DESC) AS rn
    FROM MonthlyAQI
)
SELECT 
    month,
    COUNT(*) AS state_count
FROM WorstMonths
WHERE rn = 1
GROUP BY month
ORDER BY state_count DESC;

-- Question 5: Bengaluru days by AQI category (Mar-May 2025)
SELECT air_quality_status,COUNT(*) AS days
FROM aqi
WHERE area = 'Bengaluru'
AND str_to_date(date,"%d-%m-%Y") BETWEEN '2025-03-01' AND '2025-05-31' AND air_quality_status IS NOT NULL
GROUP BY air_quality_status;

-- Question 6: Severity Mapping - cities with persistent or worsening AQI, count unhealthy+ days
WITH MinDates AS (SELECT area, MIN(date) AS min_date FROM aqi
GROUP BY area),
UnhealthyDays AS (
    SELECT area, COUNT(*) AS unhealthy_days 
    FROM aqi
    WHERE aqi_value >= 151
    GROUP BY area
),
Trends AS (SELECT a.area,AVG(a.aqi_value) AS avg_aqi,
((SUM(a.aqi_value * DATEDIFF(a.date, m.min_date)) - (SUM(a.aqi_value) * SUM(DATEDIFF(a.date, m.min_date)) / COUNT(*)))/
(SUM(POWER(DATEDIFF(a.date, m.min_date), 2)) -
POWER(SUM(DATEDIFF(a.date, m.min_date)), 2) / COUNT(*))) AS slope
FROM aqi a
JOIN MinDates m ON a.area = m.area
WHERE a.aqi_value IS NOT NULL
GROUP BY a.area
HAVING COUNT(*) >= 10)
SELECT 
t.area, 
t.avg_aqi,
t.slope,
CASE 
WHEN t.avg_aqi > 100 THEN 'Persistent' ELSE 'Not Persistent' 
END AS persistent_status, COALESCE(u.unhealthy_days, 0) AS unhealthy_days
FROM Trends t
LEFT JOIN UnhealthyDays u ON t.area = u.area
ORDER BY t.avg_aqi DESC
LIMIT 10;


-- Question 7: Health Impact Correlation - correlate AQI spikes with health events

WITH HealthMonthly AS (
    SELECT 
        state,
        YEAR(outbreak_starting_date) AS year,
        MONTH(outbreak_starting_date) AS month,
        SUM(cases) AS health_events
    FROM idsp
    WHERE disease_illness_name IN ('Chickenpox', 'Fever with Rash', 'Measles', 'Acute Diarrheal Disease')
    GROUP BY state, YEAR(outbreak_starting_date), MONTH(outbreak_starting_date)
),
AQIMonthly AS (
    SELECT 
        state,
        YEAR(STR_TO_DATE(date, "%d-%m-%Y")) AS year,
        MONTH(STR_TO_DATE(date, "%d-%m-%Y")) AS month,
        AVG(aqi_value) AS avg_aqi,
        SUM(CASE WHEN aqi_value > 200 THEN 1 ELSE 0 END) AS spikes
    FROM aqi
    WHERE aqi_value IS NOT NULL
    GROUP BY state, YEAR(STR_TO_DATE(date, "%d-%m-%Y")), MONTH(STR_TO_DATE(date, "%d-%m-%Y"))
),
Merged AS (
    SELECT 
        h.state,
        h.year,
        h.month,
        h.health_events,
        a.avg_aqi
    FROM HealthMonthly h
    JOIN AQIMonthly a 
        ON h.state = a.state 
        AND h.year = a.year 
        AND h.month = a.month
),
StateStats AS (
    SELECT 
        state,
        COUNT(*) AS n,
        AVG(health_events) AS mean_health,
        AVG(avg_aqi) AS mean_aqi
    FROM Merged
    GROUP BY state
),
CovarianceCalc AS (
    SELECT 
        m.state,
        SUM((m.health_events - s.mean_health) * (m.avg_aqi - s.mean_aqi)) / (COUNT(*) - 1) AS cov,
        STDDEV(m.health_events) AS std_health,
        STDDEV(m.avg_aqi) AS std_aqi
    FROM Merged m
    JOIN StateStats s ON m.state = s.state
    GROUP BY m.state
    HAVING COUNT(*) >= 2 AND std_health > 0 AND std_aqi > 0
)
-- final output
SELECT 
    'Overall' AS scope,
    SUM(cov) / SUM(std_health * std_aqi) AS correlation
FROM CovarianceCalc
UNION ALL
SELECT 
    state AS scope,
    cov / (std_health * std_aqi) AS correlation
FROM CovarianceCalc
WHERE cov IS NOT NULL;




-- Question 8: Demand Triggers - temporal relationship AQI spikes and vehicle growth
 WITH VahanMonthly AS (SELECT state,year,month,SUM(value) AS registrations,
(SUM(value) - LAG(SUM(value)) OVER (PARTITION BY state ORDER BY year, month)) / 
LAG(SUM(value)) OVER (PARTITION BY state ORDER BY year, month) AS growth
FROM vahan
GROUP BY state, year, month),
AQIMonthly AS (SELECT state,YEAR(STR_TO_DATE(date, "%d-%m-%Y")) AS year,MONTH(STR_TO_DATE(date, "%d-%m-%Y")) AS month, 
SUM(CASE WHEN aqi_value > 200 THEN 1 ELSE 0 END) AS spikes
FROM aqi
WHERE aqi_value IS NOT NULL
GROUP BY state, YEAR(STR_TO_DATE(date, "%d-%m-%Y")), MONTH(STR_TO_DATE(date, "%d-%m-%Y"))),
Merged AS (SELECT a.state,a.year,a.month,a.spikes,
COALESCE(v.growth, 0) AS growth
FROM AQIMonthly a
JOIN VahanMonthly v 
ON a.state = v.state AND a.year = v.year AND a.month = v.month),
StatsBase AS (SELECT AVG(spikes) AS mean_spikes,AVG(growth) AS mean_growth FROM Merged),
Stats AS (SELECT SUM((m.spikes - s.mean_spikes) * (m.growth - s.mean_growth)) / (COUNT(*) - 1) AS cov,STDDEV(m.spikes) AS std_spikes,STDDEV(m.growth) AS std_growth
FROM Merged m CROSS JOIN StatsBase s)
SELECT cov / (std_spikes * std_growth) AS correlation
FROM Stats
WHERE std_spikes > 0 AND std_growth > 0;


-- Question 9: Market size proxies using vahan and popu for top states (2025)
WITH Popu2025 AS (SELECT state,SUM(value) * 1000 AS population
FROM population_projection
WHERE year = 2025 AND gender = 'Total'
GROUP BY state),
Vahan2025 AS (SELECT state,SUM(value) AS total_vehicles
FROM vahan
WHERE year = 2025
GROUP BY state),
HighAQIDays AS (SELECT state,COUNT(DISTINCT date) AS high_aqi_days
FROM aqi
    WHERE YEAR(date) = 2025 AND aqi_value > 150
    GROUP BY state
)
SELECT 
    p.state,
    v.total_vehicles,
    p.population,
    ROUND(v.total_vehicles / p.population, 4) AS per_capita_vehicles,
    COALESCE(h.high_aqi_days, 0) * p.population / 1000000 AS aqi_burden,
    p.population / 4.5 AS households,
    ROUND(v.total_vehicles / (p.population / 4.5), 2) AS vehicles_per_hh
FROM Popu2025 p
JOIN Vahan2025 v ON p.state = v.state
LEFT JOIN HighAQIDays h ON p.state = h.state
ORDER BY aqi_burden DESC
LIMIT 10;