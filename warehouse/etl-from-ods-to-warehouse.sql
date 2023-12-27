CREATE SCHEMA IF NOT EXISTS "WAREHOUSE";

/** CREATE AND INSERT dim_business TABLE **/
DROP TABLE IF EXISTS WAREHOUSE.dim_business;

CREATE TABLE WAREHOUSE.dim_business (
	business_id VARCHAR PRIMARY KEY,
	business_name VARCHAR
);

INSERT INTO WAREHOUSE.dim_business(business_id, business_name)
SELECT DISTINCT  b.business_id, b."name" AS business_name FROM ODS.BUSINESS b;

/** CREATE AND INSERT dim_date TABLE **/
DROP TABLE IF EXISTS WAREHOUSE.dim_date;

CREATE TABLE WAREHOUSE.dim_date (
	id INT PRIMARY KEY autoincrement start 1 increment 1,
	date DATE UNIQUE
);

INSERT INTO WAREHOUSE.dim_date(date)
SELECT DISTINCT TO_DATE(r."date") FROM ODS.REVIEW  r;

/** CREATE AND INSERT dim_review TABLE **/
DROP TABLE IF EXISTS WAREHOUSE.dim_review;

CREATE TABLE WAREHOUSE.dim_review (
	review_id VARCHAR PRIMARY KEY,
	text TEXT
);

INSERT INTO WAREHOUSE.dim_review(review_id, text)
SELECT DISTINCT r.review_id, r."text" FROM ODS.REVIEW  r;

/** CREATE AND INSERT dim_atmospheric_condition TABLE **/
DROP TABLE IF EXISTS WAREHOUSE.dim_atmospheric_condition;

CREATE TABLE WAREHOUSE.dim_atmospheric_condition (
	id INT PRIMARY KEY autoincrement start 1 increment 1,
	temperature_min NUMBER,
	temperature_max NUMBER,
	temperature_normal_min NUMBER,
	temperature_normal_max NUMBER,
	precipitation NUMBER,
	precipitation_normal NUMBER,
	date DATE
);

INSERT INTO WAREHOUSE.dim_atmospheric_condition(temperature_min, temperature_max, temperature_normal_min, temperature_normal_max, precipitation, precipitation_normal, date)
SELECT DISTINCT  
	tempe.min, 
	tempe.max, 
	tempe.normal_min, 
	tempe.normal_max, 
	prec.precipitation,
	prec.precipitation_normal,
	tempe."date"
FROM ODS.TEMPERATURE tempe
INNER JOIN ODS.PRECIPITATION  prec
ON tempe."date" = prec."date";


/** CREATE AND INSERT fact_rating TABLE **/
DROP TABLE IF EXISTS WAREHOUSE.fact_rating;

CREATE TABLE WAREHOUSE.fact_rating (
	fact_id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES WAREHOUSE.dim_business(business_id),
	date_id NUMBER FOREIGN KEY REFERENCES WAREHOUSE.dim_date(id),
	atmospheric_condition_id NUMBER FOREIGN KEY REFERENCES WAREHOUSE.dim_atmospheric_condition(id),
	review_id VARCHAR FOREIGN KEY REFERENCES WAREHOUSE.dim_review(review_id),
	cool NUMBER,
	funny NUMBER,
	"star" NUMBER,
	useful NUMBER
);

INSERT INTO WAREHOUSE.fact_rating(business_id, date_id, atmospheric_condition_id, review_id, cool, funny, "star", useful)
SELECT 
	bu.BUSINESS_ID,
	da.id,
	atm.ID,
	re.review_id,
	re.COOL, 
	re.FUNNY, 
	re.STAR, 
	re.USEFUL 
FROM ODS.REVIEW re
INNER JOIN "WAREHOUSE".DIM_BUSINESS bu ON re.BUSINESS_ID  = bu.BUSINESS_ID
INNER JOIN "WAREHOUSE".DIM_DATE da ON TO_DATE(re."date") = da."DATE"
INNER JOIN "WAREHOUSE".DIM_ATMOSPHERIC_CONDITION  atm ON TO_DATE(re."date") = atm."DATE"
INNER JOIN "WAREHOUSE".DIM_REVIEW  dimRe ON re.REVIEW_ID  = dimRe.REVIEW_ID;

/* SQL Report Zio's Italian Market */
SELECT 
	bu.business_name,
	da.DATE,
	rat.cool,
	rat.funny,
	rat."star",
	rat.useful,
	atm.temperature_min,
	atm.temperature_max,
	atm.precipitation
FROM FACT_RATING rat
INNER JOIN DIM_BUSINESS bu ON rat.business_id = bu.business_id
INNER JOIN DIM_DATE  da ON da.ID = rat.DATE_ID
INNER JOIN DIM_ATMOSPHERIC_CONDITION atm ON atm.ID = rat.atmospheric_condition_id
WHERE RAT.BUSINESS_ID  = '0bPLkL0QhhPO5kt1_EXmNQ'

