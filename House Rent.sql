CREATE DATABASE IF NOT EXISTS house_rent;
USE house_rent;

CREATE TABLE house_rent_datset (
    posted_on        VARCHAR(50),
    bhk              VARCHAR(10),
    rent             VARCHAR(20),
    size_sqft        VARCHAR(20),
    floor_text       VARCHAR(50),
    area_type        VARCHAR(50),
    area_locality    VARCHAR(150),
    city             VARCHAR(50),
    furnishing       VARCHAR(50),
    tenant_preferred VARCHAR(50),
    bathrooms        VARCHAR(10),
    point_of_contact VARCHAR(50)
);

SELECT COUNT(*) FROM Listings_raw;

Rename table house_rent_dataset to Listings_raw;

SELECT * FROM listings_raw LIMIT 10;

CREATE TABLE listings_clean (
    listing_id       INT AUTO_INCREMENT PRIMARY KEY,
    posted_on        DATE,
    bhk              TINYINT,
    rent             INT,
    size_sqft        INT,
    floor_no         INT,
    total_floors     INT,
    area_type        VARCHAR(50),
    area_locality    VARCHAR(150),
    city             VARCHAR(50),
    furnishing       VARCHAR(50),
    tenant_preferred VARCHAR(50),
    bathrooms        TINYINT,
    point_of_contact VARCHAR(50)
);

SELECT DISTINCT floor_text FROM listings_raw ORDER BY 1;

SELECT DISTINCT city FROM listings_raw;   

CREATE TABLE listings_clean (
    listing_id       INT AUTO_INCREMENT PRIMARY KEY,
    posted_on        DATE,
    bhk              TINYINT,
    rent             INT,
    size_sqft        INT,
    floor_no         INT,
    total_floors     INT,
    area_type        VARCHAR(50),
    area_locality    VARCHAR(150),
    city             VARCHAR(50),
    furnishing       VARCHAR(50),
    tenant_preferred VARCHAR(50),
    bathrooms        TINYINT,
    point_of_contact VARCHAR(50)
);

INSERT INTO listings_clean
(posted_on, bhk, rent, size_sqft, floor_no, total_floors, area_type, area_locality,
 city, furnishing, tenant_preferred, bathrooms, point_of_contact)
SELECT
  STR_TO_DATE(`Posted On`, '%Y-%m-%d'),
  CAST(`BHK` AS UNSIGNED),
  CAST(`Rent` AS UNSIGNED),
  CAST(`Size` AS UNSIGNED),
  CASE
    WHEN `Floor` LIKE 'Ground%'          THEN 0
    WHEN `Floor` LIKE 'Upper Basement%'  THEN -1
    WHEN `Floor` LIKE 'Lower Basement%'  THEN -2
    ELSE CAST(SUBSTRING_INDEX(`Floor`, ' out of ', 1) AS SIGNED)
  END,
  CASE
    WHEN `Floor` LIKE '% out of %'
    THEN CAST(SUBSTRING_INDEX(`Floor`, ' out of ', -1) AS UNSIGNED)
    ELSE NULL
  END,
  TRIM(`Area Type`), TRIM(`Area Locality`), TRIM(`City`), TRIM(`Furnishing Status`),
  TRIM(`Tenant Preferred`),
  CAST(`Bathroom` AS UNSIGNED),
  TRIM(`Point of Contact`)
FROM listings_raw;

SELECT COUNT(*) FROM listings_clean;  

SELECT MIN(posted_on), MAX(posted_on) FROM listings_clean;  

SELECT city, COUNT(*) FROM listings_clean GROUP BY city;

SELECT * FROM listings_clean WHERE floor_no > total_floors OR total_floors IS NULL;

SELECT MIN(rent), MAX(rent), MIN(size_sqft), MAX(size_sqft) FROM listings_clean;

ALTER TABLE listings_clean
  ADD COLUMN rent_per_sqft DECIMAL(10,2),
  ADD COLUMN is_outlier TINYINT DEFAULT 0;

DESCRIBE listings_clean;

SELECT city,
       ROUND(AVG(rent_per_sqft),1) AS avg_psf,
       MIN(rent_per_sqft) AS min_psf,
       MAX(rent_per_sqft) AS max_psf
FROM listings_clean
GROUP BY city;

SET SQL_SAFE_UPDATES = 0;

WITH ranked AS (
  SELECT city, rent_per_sqft,
         ROW_NUMBER() OVER (PARTITION BY city ORDER BY rent_per_sqft) AS rn,
         COUNT(*) OVER (PARTITION BY city) AS cnt
  FROM listings_clean
),
q AS (
  SELECT city,
         MIN(CASE WHEN rn >= CEIL(cnt*0.25) THEN rent_per_sqft END) AS q1,
         MIN(CASE WHEN rn >= CEIL(cnt*0.75) THEN rent_per_sqft END) AS q3
  FROM ranked GROUP BY city
)
UPDATE listings_clean l
JOIN q ON l.city = q.city
SET l.is_outlier = CASE
      WHEN l.rent_per_sqft > q.q3 + 3*(q.q3 - q.q1)
        OR l.rent_per_sqft < q.q1 - 3*(q.q3 - q.q1) THEN 1
      ELSE 0 END;
      
SELECT COUNT(*) AS flagged FROM listings_clean WHERE is_outlier = 1;

SELECT city, area_locality, bhk, size_sqft, rent, rent_per_sqft
FROM listings_clean
WHERE is_outlier = 1
ORDER BY rent_per_sqft DESC;

-- Q1: Rent by city
SELECT city, COUNT(*) AS listings, ROUND(AVG(rent)) AS avg_rent,
       ROUND(AVG(rent_per_sqft),1) AS avg_psf
FROM listings_clean WHERE is_outlier = 0
GROUP BY city ORDER BY avg_psf DESC;

-- Q2: BHK vs rent 
SELECT bhk, COUNT(*) AS listings, ROUND(AVG(rent)) AS avg_rent,
       ROUND(AVG(size_sqft)) AS avg_size
FROM listings_clean WHERE is_outlier = 0
GROUP BY bhk ORDER BY bhk;

-- Q3: Furnishing effect on rent per sqft, by city
SELECT city, furnishing, COUNT(*) AS listings,
       ROUND(AVG(rent_per_sqft),1) AS avg_psf
FROM listings_clean WHERE is_outlier = 0
GROUP BY city, furnishing ORDER BY city, avg_psf DESC;

-- Q4: Top 3 priciest localities per city (min 5 listings) 
SELECT * FROM (
  SELECT city, area_locality, COUNT(*) AS listings,
         ROUND(AVG(rent_per_sqft),1) AS avg_psf,
         DENSE_RANK() OVER (PARTITION BY city ORDER BY AVG(rent_per_sqft) DESC) AS rnk
  FROM listings_clean WHERE is_outlier = 0
  GROUP BY city, area_locality HAVING COUNT(*) >= 5
) t WHERE rnk <= 3;

-- Q5: Owner vs agent vs builder share by city
SELECT city, point_of_contact, COUNT(*) AS listings,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY city), 1) AS pct
FROM listings_clean
GROUP BY city, point_of_contact ORDER BY city, listings DESC;

-- Q6: Tenant preference by city
SELECT city, tenant_preferred, COUNT(*) AS listings
FROM listings_clean
GROUP BY city, tenant_preferred ORDER BY city, listings DESC;

-- Q7: Rent by floor level
SELECT CASE WHEN floor_no <= 0 THEN 'Ground/Basement'
            WHEN floor_no BETWEEN 1 AND 3 THEN 'Low (1-3)'
            WHEN floor_no BETWEEN 4 AND 10 THEN 'Mid (4-10)'
            ELSE 'High (11+)' END AS floor_band,
       COUNT(*) AS listings, ROUND(AVG(rent_per_sqft),1) AS avg_psf
FROM listings_clean WHERE is_outlier = 0
GROUP BY floor_band ORDER BY avg_psf DESC;

-- Q8: City summary with outlier counts 
SELECT city,
       COUNT(*) AS total_listings,
       SUM(is_outlier) AS outliers,
       ROUND(AVG(CASE WHEN is_outlier = 0 THEN rent END)) AS avg_rent,
       ROUND(AVG(CASE WHEN is_outlier = 0 THEN rent_per_sqft END), 2) AS avg_psf
FROM listings_clean
GROUP BY city
ORDER BY city;


