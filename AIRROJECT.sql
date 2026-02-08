/*                                                  PROJECT - Air purifier SQL project
OBJECTIVES:
The primary objectives of this project are:
1) Identify Dominant Pollutants:- 
 - Analyze AQI data to determine which pollutants (PM2.5, PM10, NO₂) most severely impact Indian cities and should be prioritized in air purifier design.
2)Understand Consumer Needs & Essential Features:-
 - Translate pollution patterns into product features such as real-time AQI monitoring, portability, filter type, and city-specific optimization.
3)Estimate Market Demand & High-Potential Cities:-
 - Identify cities with severe and worsening air quality and estimate market size using population projections and AQI severity.
4)Align R&D with Localized Pollution Patterns:-
 - Ensure product specifications match real-world pollution characteristics to reduce R&D risk and avoid over-engineering.
5)Support Strategic Decision-Making:-
 - Provide insights for leadership through data-backed storytelling suitable for product strategy and executive presentations.
*/

-- Database Creation 
create database AQI;
use AQI;

-- Datasets Used

select * from aqi;
select * from idsp;	
select* from population_projection;
select * from vahan;



-- PROBLEM 1: Top 5 and bottom 5 areas with highest average AQI (Dec 2024 to May 2026)

-- BOTTOM 5 
SELECT area, round(AVG(aqi_value),2), count(*) AS observation_count
FROM aqi 
WHERE str_to_date(DATE,"%d-%m-%Y") BETWEEN "2024-12-01" AND "2026-05-31"
AND aqi_value IS NOT NULL 
GROUP BY area 
HAVING observation_count >0 
ORDER BY observation_count ASC 
LIMIT 5; 

-- TOP 5
SELECT area, round(AVG(aqi_value),2), count(*) AS observation_count
FROM aqi 
WHERE str_to_date(DATE,"%d-%m-%Y") BETWEEN "2024-12-01" AND "2026-05-31"
AND aqi_value IS NOT NULL 
GROUP BY area 
HAVING observation_count >0 
ORDER BY observation_count DESC 
LIMIT 5; 


-- PROBLEM 2: Top 2 and bottom 2 prominent pollutants for each Southern state (2022 onward)
WITH PollutantCounts AS (
    SELECT 
        state,
        prominent_pollutants,
        COUNT(*) AS pollutant_count,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY COUNT(*) DESC) AS rn_desc,
        ROW_NUMBER() OVER (PARTITION BY state ORDER BY COUNT(*) ASC) AS rn_asc
    FROM aqi
    WHERE str_to_date(date,"%d-%m-%Y") >=2022
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
/*STEPS:-
1.Filter AQI data for the target year (2022 onwards) to ensure relevance to current and future product strategy.
2.Restrict analysis to selected South Indian states (Andhra Pradesh, Telangana, Karnataka, Kerala, Tamil Nadu) for region-specific insights.
3.Group AQI records by state and prominent pollutant to measure pollutant occurrence frequency.
4.Count the number of occurrences for each pollutant within each state to assess dominance.
5.Rank pollutants in descending order of frequency within each state to identify the most dominant pollutants.
6.Rank pollutants in ascending order of frequency within each state to identify the least dominant pollutants.
7.Assign row numbers using window functions to enable top-N and bottom-N pollutant selection per state.
8.Select the top two most frequent pollutants for each state as primary targets for air purifier filter design.
9.Select the bottom two least frequent pollutants to identify lower-priority or optional filtration needs.
10.Concatenate pollutant names into readable lists for executive-friendly output and reporting.*/


-- PROBLEM 3: AQI improve on weekends vs weekdays in metro cities (last 1 year from max date)
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
/*STEPS:-
1.Convert AQI date strings into proper date format to enable accurate time-based filtering and weekday/weekend classification.
2.Restrict the dataset to the most recent one-year period to reflect current urban pollution behavior.
3.Filter data for major Indian metro cities to focus on high-density, high-demand urban markets.
4.Classify each AQI record as Weekday or Weekend using the day-of-week logic.
5.Exclude null AQI values to ensure reliable average calculations.
6.Compute average AQI for weekdays for each metro city to capture regular working-day pollution levels.
7.Compute average AQI for weekends for each metro city to capture reduced-activity pollution levels.
8.Calculate pollution improvement percentage to quantify how much air quality improves during weekends compared to weekdays.
9.Aggregate results at the city level to enable metro-wise comparison of behavioral pollution impact.*/



-- PROBLEM 4: Months consistently show worst air quality across top 10 states with high distinct areas
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
/*STEPS:-
1.Identify the top 10 states with the widest AQI monitoring coverage by ranking states based on the number of distinct monitored areas.
2. Restrict analysis to these top states to ensure consistency and comparability across regions.
3. Aggregate AQI data at a monthly level by calculating the average AQI for each state and calendar month.
4. Exclude invalid AQI readings by filtering out null AQI values to maintain data quality.
5. Rank months within each state using a window function to identify the month with the highest average AQI.
6. Select the worst pollution month per state by filtering to the top-ranked month (highest AQI).
7. Count how many states share the same worst month to detect national-level pollution seasonality.
8. Rank months by frequency to determine which months most commonly experience peak pollution across states.*/




-- PROBLEM 5: Bengaluru days by AQI category (Mar-May 2025)
SELECT air_quality_status,COUNT(*) AS days
FROM aqi
WHERE area = 'Bengaluru'
AND str_to_date(date,"%d-%m-%Y") BETWEEN '2025-03-01' AND '2025-05-31' AND air_quality_status IS NOT NULL
GROUP BY air_quality_status;




-- PROBLEM 6: Severity Mapping - cities with persistent or worsening AQI, count unhealthy+ days
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
/*STEPS:-
1. Identify the earliest AQI record date for each area to establish a time baseline for trend analysis.
2. Count the total number of unhealthy air quality days (AQI ≥ 151) for each area to measure pollution frequency.
3. Filter valid AQI observations by excluding null AQI values to ensure accurate calculations.
4. Calculate the average AQI level for each area to represent long-term pollution intensity.
5. Convert calendar dates into numerical time offsets using the difference between each date and the area’s first recorded date.
6. Compute the AQI trend slope for each area using linear regression logic to capture whether pollution levels are increasing or decreasing over time.
7. Restrict analysis to areas with sufficient data points (at least 10 observations) to ensure statistical reliability.
8. Classify pollution persistence status by labeling areas with average AQI above 100 as “Persistent” pollution zones.
9. Merge trend results with unhealthy-day counts to enrich severity insights with exposure frequency.
10. Rank areas by average AQI severity and select the top 10 most polluted areas for strategic prioritization.*/



-- PROBLEM 7: Health Impact Correlation - correlate AQI spikes with health events

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
/*STEPS:-
1. Filter and aggregate health outbreak data monthly by state using IDSP records for pollution-sensitive diseases (Chickenpox, Measles, Fever with Rash, Acute Diarrheal Disease).
2. Extract year and month from outbreak start dates to align health data temporally with AQI data.
3. Aggregate monthly air quality data by state, calculating both average AQI levels and the count of severe pollution spikes (AQI > 200).
4. Standardize AQI date formats using STR_TO_DATE() to ensure accurate time-based joins.
5. Merge monthly health events with monthly AQI metrics at the state-year-month level to create a unified health-pollution dataset.
6. Compute state-level statistical baselines by calculating the mean number of health events and mean AQI for each state.
7. Calculate covariance between AQI and health events for each state to measure how pollution levels and disease outbreaks move together.
8. Compute standard deviation for health events and AQI to normalize variability across states.
9. Filter out statistically invalid states where observations are insufficient or variability is zero to ensure reliable correlation results.
10. Derive state-level Pearson correlation coefficients between average AQI and health events.
11. Calculate an overall correlation score by aggregating state-level covariance and variability to capture nationwide health impact trends.
12. Combine overall and state-level correlations into a single result set for executive-level interpretation.*/



-- PROBLEM 8: Demand Triggers - temporal relationship AQI spikes and vehicle growth
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
/*STEPS:-
1. Aggregate monthly vehicle registrations by state, year, and month to create a time-series view of vehicle growth.
2. Calculate month-over-month vehicle growth rate using the LAG() window function to capture changes in consumer and mobility trends.
3. Convert AQI dates into year and month format to align pollution data with vehicle registration timelines.
4. Count monthly pollution spike events by summing days where AQI exceeded 200 (very unhealthy category) for each state.
5. Merge monthly AQI spikes with vehicle growth data using state, year, and month as common keys.
6. Handle missing growth values by replacing nulls with zero using COALESCE() to maintain continuity in analysis.
7. Compute mean values of AQI spikes and vehicle growth to establish a statistical baseline.
8. Calculate covariance between AQI spikes and vehicle growth, measuring how the two variables move together over time.
9. Calculate standard deviation for both AQI spikes and vehicle growth to normalize variability.
10. Derive the Pearson correlation coefficient by dividing covariance by the product of standard deviations.
11. Filter out invalid cases where standard deviation is zero to ensure mathematical correctness.*/




-- PROBLEM 9: Market size proxies using vahan and population for top states (2025)
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
/*STEPS:-
1. Extract 2025 population data at the state level using population projections and convert values from thousands to actual population.
2. Aggregate total vehicle registrations for 2025 by state to measure vehicular pollution pressure.
3. Identify high pollution exposure days by counting distinct days in 2025 where AQI exceeded 150 (unhealthy category).
4. Integrate population, vehicle, and AQI datasets using state-level joins to create a unified analytical view.
5. Calculate per-capita vehicle density to normalize vehicular pollution impact across states of different population sizes.
6. Compute AQI burden index by combining population size with the number of unhealthy AQI days to quantify total exposure risk.
7. Estimate total households using an average household size of 4.5 to translate population into potential consumer units.
8. Derive vehicles per household metric as a proxy for urban density and likelihood of air-purifier adoption.
9. Rank states by AQI burden and select the top 10 highest-priority markets for product launch and R&D focus.*/