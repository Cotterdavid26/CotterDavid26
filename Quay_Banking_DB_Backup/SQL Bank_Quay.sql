-- Intergrating tables into existing database setting foreign keys and how tables are linked, 
-- connect the review and district table using district_id
ALTER TABLE Reviews ADD CONSTRAINT
FK_Review_District FOREIGN KEY (district_id) REFERENCES
District (district_id);
-- Connect the Events table to client using client ID
ALTER TABLE CRM_Events ADD CONSTRAINT
FK_CRM_Events_Client FOREIGN KEY (client_id) REFERENCES
Client (client_id);
-- connect the call centre log to the Events table
ALTER TABLE CRM_Call_Centre_Logs ADD CONSTRAINT
FK_CRM_Call_Centre_Logs_Events FOREIGN KEY (Complaint_ID) REFERENCES
CRM_Events (Complaint_ID);

-- 1)Performance:a. Which 20% of branches are underperforming? – evident in “closed complaints without relief” and negative customer service feedback
With reviewCounts as (
SELECT d.bank_branch, COUNT(r.Rating) AS negative_reviews
FROM Reviews r
JOIN District d ON r.district_id = d.district_id
WHERE r.Rating = 1
GROUP BY d.bank_branch
),
EventCounts as (
SELECT d.bank_branch, COUNT(Complaint_ID) as event_reviews
FROM CRM_Events as e
JOIN Client as c
ON e.client_id = C.client_id
JOIN District as d 
ON c.district_id = d.district_id
WHERE Company_response_to_consumer = 'Closed without relief'
GROUP BY d.bank_branch
)
SELECT TOP 15
  COALESCE(rc.bank_branch, ec.bank_branch) AS bank_branch,
  COALESCE(rc.negative_reviews, 0) + COALESCE(ec.event_reviews, 0) AS Total_negative_reviews
FROM reviewCounts rc
FULL OUTER JOIN EventCounts ec ON rc.bank_branch = ec.bank_branch
ORDER BY Total_negative_reviews DESC;

-- Can we rank the Call Centre Servers’ performance according to Call duration and outcome ? (Advanced)
-- I decide to use the consumer disputed column as reference to negative or positive calls when evaluating the data.
SELECT l.server, 
CASE WHEN COALESCE(e.consumer_disputed, 0) = 0 THEN 'Positive' ELSE 'Negative' END AS Outcome,
CAST(CAST(MIN(CAST(CAST(l.ser_time AS datetime) AS float)) AS datetime) AS time(0))as MIN_call_duration,
CAST(CAST(MAX(CAST(CAST(l.ser_time AS datetime) AS float)) AS datetime) AS time(0))as MAX_call_duration,
CAST(CAST(AVG(CAST(CAST(l.ser_time AS datetime) AS float)) AS datetime) AS time(0)) AS AvgTime,
SUM(CASE WHEN Company_response_to_consumer = 'Closed with explanation' THEN 1 ELSE 0 END) as Closed_with_Explanation,
SUM(CASE WHEN Company_response_to_consumer = 'Closed without relief' THEN 1 ELSE 0 END) as Closed_without_relief,
SUM(CASE WHEN Company_response_to_consumer = 'Closed with relief' THEN 1 ELSE 0 END) as Closed_with_relief,
SUM(CASE WHEN Company_response_to_consumer = 'Closed with non-monetary relief' THEN 1 ELSE 0 END) as Closed_with_non_monetary_relief,
SUM(CASE WHEN Company_response_to_consumer = 'Closed with Monetary relief' THEN 1 ELSE 0 END) as Closed_with_Monetary_relief,
SUM(CASE WHEN Company_response_to_consumer = 'Untimely response' THEN 1 ELSE 0 END) as Untimely_response
FROM CRM_Call_Centre_Logs as l
JOIN CRM_Events as e
ON l.Complaint_ID=e.Complaint_ID
Group by l.server, COALESCE(e.consumer_disputed, 0)
ORDER by l.server, COALESCE(e.consumer_disputed, 0);

-- doing some investigation on the avg call time filtered by Consumer disputed yes
SELECT l.server,
CAST(CAST(AVG(CAST(CAST(l.ser_time AS datetime) AS float)) AS datetime) AS time(0)) AS AvgTime
FROM CRM_Call_Centre_Logs as l
JOIN CRM_Events as e
ON l.Complaint_ID=e.Complaint_ID
WHERE e.Consumer_disputed = 1
GROUP by l.server
ORDER BY l.server;
-- doing some investigation on the avg call time between Consumer disputed No
SELECT l.server,
CAST(CAST(AVG(CAST(CAST(l.ser_time AS datetime) AS float)) AS datetime) AS time(0)) AS AvgTime
FROM CRM_Call_Centre_Logs as l
JOIN CRM_Events as e
ON l.Complaint_ID=e.Complaint_ID
WHERE e.Consumer_disputed = 0
GROUP by l.server
ORDER BY l.server;


-- 1b Which are the top 5 branches per positive customer feedback?
SELECT TOP 5 d.bank_branch, COUNT(r.Rating) AS Total_Positive_reviews
FROM Reviews r
JOIN District d ON r.district_id = d.district_id
WHERE r.Rating = 5
GROUP BY d.bank_branch
ORDER BY Total_Positive_reviews DESC;

--1b i What are the characteristics of these branches that could contribute to this positivity?
-- I've used a case when statement to count the number of occurences of positive words in the reviews for the top 5 branches based on total review numbers 
SELECT d.bank_branch,d.city, d.state_name, d.region,d.division, 
SUM(CASE WHEN r.Review LIKE '%Competitive%' THEN 1 ELSE 0 END) as Competitive_mentioned,
SUM(CASE WHEN r.Review LIKE '%Friendly%' THEN 1 ELSE 0 END) as Friendly_mentioned,
SUM(CASE WHEN r.Review LIKE '%Helpful%' THEN 1 ELSE 0 END) as Helpful_mentioned,
SUM(CASE WHEN r.Review LIKE '%efficient%' THEN 1 ELSE 0 END) as Efficient_mentioned,
SUM(CASE WHEN r.Review LIKE '%Excellent%' THEN 1 ELSE 0 END) as Excellent_mentioned,
SUM(CASE WHEN r.Review LIKE '%Fast%' THEN 1 ELSE 0 END) as Fast_mentioned,
SUM(CASE WHEN r.Review LIKE '%helped%' THEN 1 ELSE 0 END) as helped_mentioned,
SUM(CASE WHEN r.Review LIKE '%reliable%' THEN 1 ELSE 0 END) as reliable_mentioned,
SUM(CASE WHEN r.Review LIKE '%Responded Quick%' THEN 1 ELSE 0 END) as RespondedQuick_mentioned,
SUM(CASE WHEN r.Review LIKE '%Waved Fees%' THEN 1 ELSE 0 END) as Waivedfees_mentioned,
SUM(CASE WHEN r.Review LIKE '%Thank You%' THEN 1 ELSE 0 END) as ThankYOU_mentioned,
COUNT(r.Rating) AS Total_Positive_reviews
FROM Reviews r
JOIN District d ON r.district_id = d.district_id
--WHERE r.Rating = 5 AND d.bank_branch = 'Quay Manchester' OR d.bank_branch = 'Minneapolis Quay' OR d.bank_branch = 'Washinton State Quay' OR d.bank_branch = 'Quay Nachsville Main' OR d.bank_branch = 'Quay Sioux Falls'
GROUP BY d.bank_branch, d.city, d.state_name, d.region,d.division
ORDER BY Total_Positive_reviews DESC

-- Reporting CRM data:
-- Which branches may be under-reporting their customer feedback? Highlight anything less than 2 standard deviations away from the mean

WITH ReviewStats AS (
  SELECT 
    d.bank_branch, 
    COUNT(r.Rating) AS Total_reviews
  FROM Reviews r
  JOIN District d ON r.district_id = d.district_id
  GROUP BY d.bank_branch
),
AvgStdDev AS (
  SELECT
    AVG(Total_reviews) AS Avg_reviews,
    STDEV(Total_reviews) AS StdDev_reviews
  FROM ReviewStats
)
SELECT 
  rs.bank_branch,
  rs.Total_reviews
  --asd.Avg_reviews,
  --asd.StdDev_reviews
FROM ReviewStats as rs, AvgStdDev as asd
WHERE rs.Total_reviews < (asd.Avg_reviews - 2 * asd.StdDev_reviews)
ORDER BY rs.Total_reviews desc;

-- Q2 ai. Dive deeper into this pattern by separating branches in urban from those in more rural areas, as best you can.
WITH ReviewStats AS (
  SELECT 
    d.bank_branch, d.city, d.state_name, d.region, d.division, 
    COUNT(r.Rating) AS Total_reviews
  FROM Reviews r
  JOIN District d 
  ON r.district_id = d.district_id
  GROUP BY d.bank_branch, d.city, d.state_name, d.region, d.division
),
AvgStdDev AS (
  SELECT
    AVG(Total_reviews) AS Avg_reviews,
    STDEV(Total_reviews) AS StdDev_reviews
  FROM ReviewStats
)
SELECT 
  rs.bank_branch,
  rs.city,
  rs.state_name,
  rs.region,
  rs.Total_reviews, 
  CASE rs.city 
  WHEN 'Danbury' THEN 86759 
  When 'Salt Lake City' THEN 200478 
  WHEN 'Houston' THEN 2288000
  WHEN 'Atlanta' THEN 496461
  WHEN 'Las Vegas' THEN 646790
  WHEN 'Minneapolis' THEN 425336
  ELSE 'other' END as Population,
  CASE rs.city 
  WHEN 'Danbury' THEN 'Small'
  WHEN 'Salt Lake City' THEN 'Small'
  WHEN 'Atlanta' THEN 'Medium'
  WHEN 'Las Vegas' THEN 'Medium'
  WHEN ' Minneapolis' THEN 'Medium'
  ELSE 'Large' END as City_size
  FROM ReviewStats as rs, AvgStdDev as asd
WHERE rs.Total_reviews < (asd.Avg_reviews - 2 * asd.StdDev_reviews)
ORDER BY rs.Total_reviews desc;


-- Q3 Reporting CRM data: How well are branches and customer service staff handling customer complaints?
-- Which customer service staff are closing the most queries either as “Closed without relief” or “Closed with Explanation”?
SELECT l.server, COUNT(e.Company_response_to_consumer) as Total_closed
FROM CRM_Events as e
JOIN CRM_Call_Centre_Logs as l 
ON e.Complaint_ID=l.Complaint_ID
WHERE Company_response_to_consumer = 'Closed without relief' OR Company_response_to_consumer =  'Closed with Explanation'
GROUP BY l.server
ORDER BY Total_closed DESC;

-- ii Which branches are proportionally receiving the most complaints regarding “Account opening, closing, or management”?

SELECT d.bank_branch, COUNT(issue) as Most_complaints
FROM CRM_Events as e
JOIN Client as c
ON e.client_id = c.client_id
JOIN District as d
ON c.district_id=d.district_id
WHERE Issue LIKE '%Account Opening%' or Issue LIKE '%closing%' OR Issue LIKE '%management%'
GROUP BY d.bank_branch
ORDER BY Most_complaints DESC;



















