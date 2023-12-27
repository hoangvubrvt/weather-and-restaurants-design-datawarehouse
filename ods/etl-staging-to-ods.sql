/** CREATE AND INSERT precipitation TABLE **/

CREATE TABLE ODS.precipitation (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1, 
	"date" DATE UNIQUE,
	precipitation NUMBER,
	precipitation_normal NUMBER
);

INSERT INTO ODS.precipitation ("date", precipitation, precipitation_normal)
SELECT TO_DATE(TO_VARIANT(pre.date)::STRING, 'YYYYMMDD')::DATE,
	CASE 
		WHEN TRY_CAST(pre.precipitation AS NUMBER) IS NOT NULL
		THEN TRY_CAST(pre.precipitation AS NUMBER)
		ELSE NULL
	END AS precipitation,
	CASE 
		WHEN TRY_CAST(pre.precipitation_normal AS NUMBER) IS NOT NULL
		THEN TRY_CAST(pre.precipitation_normal AS NUMBER)
		ELSE NULL
	END AS precipitation_normal 
FROM CLIMATE.PRECIPITATION AS pre;

/** CREATE AND INSERT temperature TABLE **/
CREATE TABLE ODS.temperature (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1, 
	"date" DATE UNIQUE,
	min NUMBER,
	max NUMBER,
	normal_min NUMBER,
	normal_max NUMBER
);

INSERT INTO ODS.temperature ("date", min, max, normal_min, normal_max)
SELECT TO_DATE(TO_VARIANT(pre.date)::STRING, 'YYYYMMDD')::DATE, pre.min, pre.max, pre.normal_min, pre.normal_max
FROM CLIMATE.TEMPERATURE  AS pre;


/** CREATE AND INSERT BUSINESS TABLE **/

DROP TABLE IF EXISTS ODS.business;

CREATE TABLE ODS.business (
	business_id VARCHAR PRIMARY KEY,
	is_open BOOLEAN,
	review_count INT,
	"star" FLOAT,
	"name" VARCHAR
);

INSERT INTO ODS.business (business_id, is_open, review_count, "star", "name")
SELECT 
	PARSE_JSON(BUSINESSJSON):business_id::STRING AS business_id,
	CASE 
		WHEN PARSE_JSON(BUSINESSJSON):is_open::INT = 1 THEN TRUE
		WHEN PARSE_JSON(BUSINESSJSON):is_open::INT = 0 THEN FALSE
		ELSE FALSE
	END AS is_open,
	PARSE_JSON(BUSINESSJSON):review_count::INT AS review_count,
	PARSE_JSON(BUSINESSJSON):stars::FLOAT AS "star",
	PARSE_JSON(BUSINESSJSON):name::STRING AS "name"
FROM YELP.BUSINESS;

SELECT * FROM ODS.business;

/** CREATE AND INSERT ADDRESS TABLE **/
DROP TABLE IF EXISTS ODS.address;

CREATE TABLE ODS.address (
	id INT PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR UNIQUE FOREIGN KEY REFERENCES ODS.business(business_id),
	street VARCHAR,
	city VARCHAR,
	postal_code VARCHAR,
	state VARCHAR,
	latitude DOUBLE,
	longitude DOUBLE
);

INSERT INTO ODS.address (business_id, street, city, postal_code, state, latitude, longitude)
SELECT 
	PARSE_JSON(BUSINESSJSON):business_id::STRING AS business_id,
	IFF(PARSE_JSON(BUSINESSJSON):address::STRING = '', NULL, PARSE_JSON(BUSINESSJSON):address::STRING) AS street,
	IFF(PARSE_JSON(BUSINESSJSON):city::STRING = '', NULL, PARSE_JSON(BUSINESSJSON):city::STRING) AS city,
	IFF(PARSE_JSON(BUSINESSJSON):postal_code::STRING = '', NULL, PARSE_JSON(BUSINESSJSON):postal_code::STRING) AS postal_code,
	IFF(PARSE_JSON(BUSINESSJSON):state::STRING = '', NULL, PARSE_JSON(BUSINESSJSON):state::STRING) AS state,
	PARSE_JSON(BUSINESSJSON):latitude::DOUBLE AS latitude,
	PARSE_JSON(BUSINESSJSON):longitude::DOUBLE AS longitude
FROM YELP.BUSINESS;

SELECT * FROM ODS.address;

/** CREATE AND INSERT category TABLE **/
DROP TABLE IF EXISTS ODS.category;

CREATE TABLE ODS.category (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	"name" VARCHAR UNIQUE
);

DROP TABLE IF EXISTS ODS.category_business;
CREATE TABLE ODS.category_business (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	category_id NUMBER FOREIGN KEY REFERENCES ODS.category(id)
);

INSERT INTO ODS.category ("name")
SELECT DISTINCT 
	TRIM(f1.value::STRING) AS "name"
FROM YELP.BUSINESS,
	LATERAL FLATTEN(INPUT => STRTOK_TO_ARRAY(PARSE_JSON(BUSINESSJSON):categories, ',')) f1;

SELECT * FROM ODS.category;

INSERT INTO ODS.category_business(category_id, business_id)
SELECT ct.id, sub_result.business_id FROM ODS.category ct
INNER JOIN (
	SELECT 
		PARSE_JSON(BUSINESSJSON):business_id::STRING AS business_id,
		TRIM(f1.value::STRING) AS category
	FROM YELP.BUSINESS,
		LATERAL FLATTEN(INPUT => STRTOK_TO_ARRAY(PARSE_JSON(BUSINESSJSON):categories, ',')) f1	
) AS sub_result
ON ct."name" = sub_result.category;

SELECT * FROM ODS.category_business;

/** CREATE AND INSERT ambience_attribute TABLE **/
DROP TABLE IF EXISTS ODS.ambience_attribute;

CREATE TABLE ODS.ambience_attribute (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	romantic BOOLEAN DEFAULT FALSE,
	intimate BOOLEAN DEFAULT FALSE,
	touristy BOOLEAN DEFAULT FALSE,
	hipster BOOLEAN DEFAULT FALSE,
	divey BOOLEAN DEFAULT FALSE,
	classy BOOLEAN DEFAULT FALSE,
	trendy BOOLEAN DEFAULT FALSE,
	upscale BOOLEAN DEFAULT FALSE,
	casual BOOLEAN DEFAULT FALSE
);

INSERT INTO ODS.ambience_attribute (business_id, romantic, intimate, touristy, hipster, divey, classy, trendy, upscale, casual)
SELECT 
	result_data.business_id, 
	MAX(CASE WHEN ambience.KEY = 'romantic' THEN ambience.value END) AS romantic,
	MAX(CASE WHEN ambience.KEY = 'intimate' THEN ambience.value END) AS intimate,
	MAX(CASE WHEN ambience.KEY = 'touristy' THEN ambience.value END) AS touristy,
	MAX(CASE WHEN ambience.KEY = 'hipster' THEN ambience.value  END) AS hipster,
	MAX(CASE WHEN ambience.KEY = 'divey' THEN ambience.value END) AS divey,
	MAX(CASE WHEN ambience.KEY = 'classy' THEN ambience.value END) AS classy,
	MAX(CASE WHEN ambience.KEY = 'trendy' THEN ambience.value END) AS trendy,
	MAX(CASE WHEN ambience.KEY = 'upscale' THEN ambience.value END) AS upscale,
	MAX(CASE WHEN ambience.KEY = 'casual' THEN ambience.value END) AS casual
FROM (
	SELECT
		PARSE_JSON(b.BUSINESSJSON):business_id::STRING AS business_id,
		f.value
	FROM YELP.BUSINESS b,
		LATERAL FLATTEN(input => PARSE_JSON(b.BUSINESSJSON), path => 'attributes') f
	WHERE
		f.KEY = 'Ambience'
		AND
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes:Ambience IS NOT NULL, TRUE, FALSE)
		AND 
		IFF(PARSE_JSON(BUSINESSJSON):attributes:Ambience <> 'None', TRUE, FALSE)
) AS result_data,
	LATERAL FLATTEN(input => TRY_PARSE_JSON(result_data.value)) ambience
GROUP BY result_data.business_id;

SELECT * FROM ODS.ambience_attribute;

/** CREATE AND INSERT good_for_meal_attribute TABLE **/
DROP TABLE IF EXISTS ODS.good_for_meal_attribute;

CREATE TABLE ODS.good_for_meal_attribute (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	dessert BOOLEAN DEFAULT FALSE,
	latenight BOOLEAN DEFAULT FALSE,
	lunch BOOLEAN DEFAULT FALSE,
	dinner BOOLEAN DEFAULT FALSE,
	brunch BOOLEAN DEFAULT FALSE,
	breakfast BOOLEAN DEFAULT FALSE
);

INSERT INTO ODS.good_for_meal_attribute (business_id, dessert, latenight, lunch, dinner, brunch, breakfast)
SELECT 
	result_data.business_id, 
	MAX(CASE WHEN goodForMeal.KEY = 'dessert' THEN goodForMeal.value END) AS dessert,
	MAX(CASE WHEN goodForMeal.KEY = 'latenight' THEN goodForMeal.value END) AS latenight,
	MAX(CASE WHEN goodForMeal.KEY = 'lunch' THEN goodForMeal.value END) AS lunch,
	MAX(CASE WHEN goodForMeal.KEY = 'dinner' THEN goodForMeal.value  END) AS dinner,
	MAX(CASE WHEN goodForMeal.KEY = 'brunch' THEN goodForMeal.value END) AS brunch,
	MAX(CASE WHEN goodForMeal.KEY = 'breakfast' THEN goodForMeal.value END) AS breakfast
FROM (
	SELECT
		PARSE_JSON(b.BUSINESSJSON):business_id::STRING AS business_id,
		f.value
	FROM YELP.BUSINESS b,
		LATERAL FLATTEN(input => PARSE_JSON(b.BUSINESSJSON), path => 'attributes') f
	WHERE
		f.KEY = 'GoodForMeal'
		AND
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes:GoodForMeal IS NOT NULL, TRUE, FALSE)
		AND 
		IFF(PARSE_JSON(BUSINESSJSON):attributes:GoodForMeal <> 'None', TRUE, FALSE)
) AS result_data,
	LATERAL FLATTEN(input => TRY_PARSE_JSON(result_data.value)) goodForMeal
GROUP BY result_data.business_id;

SELECT * FROM ODS.good_for_meal_attribute;

/** CREATE AND INSERT business_parking_attribute TABLE **/
DROP TABLE IF EXISTS ODS.business_parking_attribute;

CREATE TABLE ODS.business_parking_attribute (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	garage BOOLEAN DEFAULT FALSE,
	street BOOLEAN DEFAULT FALSE,
	validated BOOLEAN DEFAULT FALSE,
	lot BOOLEAN DEFAULT FALSE,
	valet BOOLEAN DEFAULT FALSE
);

INSERT INTO ODS.business_parking_attribute (business_id, garage, street, validated, lot, valet)
SELECT 
	result_data.business_id, 
	MAX(CASE WHEN businessParking.KEY = 'garage' THEN businessParking.value END) AS garage,
	MAX(CASE WHEN businessParking.KEY = 'street' THEN businessParking.value END) AS street,
	MAX(CASE WHEN businessParking.KEY = 'validated' THEN businessParking.value END) AS validated,
	MAX(CASE WHEN businessParking.KEY = 'lot' THEN businessParking.value  END) AS lot,
	MAX(CASE WHEN businessParking.KEY = 'valet' THEN businessParking.value END) AS valet
FROM (
	SELECT
		PARSE_JSON(b.BUSINESSJSON):business_id::STRING AS business_id,
		f.value
	FROM YELP.BUSINESS b,
		LATERAL FLATTEN(input => PARSE_JSON(b.BUSINESSJSON), path => 'attributes') f
	WHERE
		f.KEY = 'BusinessParking'
		AND
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes:BusinessParking IS NOT NULL, TRUE, FALSE)
		AND 
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes:BusinessParking <> 'None', TRUE, FALSE)
) AS result_data,
	LATERAL FLATTEN(input => TRY_PARSE_JSON(result_data.value)) businessParking
GROUP BY result_data.business_id;

SELECT * FROM ODS.business_parking_attribute;

/** CREATE AND INSERT other_attribute TABLE **/
DROP TABLE IF EXISTS ODS.other_attribute;

CREATE TABLE ODS.other_attribute (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	by_appointment_only BOOLEAN DEFAULT FALSE,
	business_accepts_credit_card BOOLEAN DEFAULT FALSE,
	bike_parking BOOLEAN DEFAULT FALSE,
	cater BOOLEAN DEFAULT FALSE,
	coat_check BOOLEAN DEFAULT FALSE,
	dogs_allowed BOOLEAN DEFAULT FALSE,
	happy_hour BOOLEAN DEFAULT FALSE,
	has_tv BOOLEAN DEFAULT FALSE,
	outdoor_seating BOOLEAN DEFAULT FALSE,
	restaurants_delivery BOOLEAN DEFAULT FALSE,
	restaurants_price_range NUMBER,
	restaurants_reservation BOOLEAN DEFAULT FALSE,
	restaurants_take_out BOOLEAN DEFAULT FALSE,
	wheelchair_accessible BOOLEAN DEFAULT FALSE,
	wifi VARCHAR,
	alcohol VARCHAR,
	good_for_kid BOOLEAN DEFAULT FALSE,
	drive_thru BOOLEAN DEFAULT FALSE,
	restaurants_attire VARCHAR,
	restaurants_good_for_group BOOLEAN DEFAULT FALSE,
	restaurants_table_service BOOLEAN DEFAULT FALSE,
	noise_level VARCHAR,
	business_accepts_bitcoin BOOLEAN DEFAULT FALSE
);

INSERT INTO ODS.other_attribute (business_id, business_accepts_credit_card, by_appointment_only, bike_parking, cater, coat_check, dogs_allowed, happy_hour, has_tv, outdoor_seating, restaurants_delivery, restaurants_price_range, restaurants_reservation, restaurants_take_out, wheelchair_accessible, wifi, alcohol, good_for_kid, drive_thru, restaurants_attire, restaurants_good_for_group, restaurants_table_service, noise_level, business_accepts_bitcoin)
SELECT
		PARSE_JSON(b.BUSINESSJSON):business_id::STRING AS business_id,
		MAX(CASE 
				WHEN f.KEY = 'BusinessAcceptsCreditCards' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS business_accepts_credit_card,
		MAX(CASE 
				WHEN f.KEY = 'ByAppointmentOnly' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS by_appointment_only,
		MAX(CASE 
				WHEN f.KEY = 'BikeParking' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS bike_parking,
		MAX(CASE 
				WHEN f.KEY = 'Caters' THEN 
					CASE 
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS cater,
		MAX(CASE 
				WHEN f.KEY = 'CoatCheck' THEN 
					CASE 
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END		
			END) AS coat_check,
		MAX(CASE 
				WHEN f.KEY = 'DogsAllowed' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END	
			END) AS dogs_allowed,
		MAX(CASE 
				WHEN f.KEY = 'HappyHour' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END		
			END) AS happy_hour,
		MAX(CASE 
				WHEN f.KEY = 'HasTV' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
					
			END) AS has_tv,
		MAX(CASE 
				WHEN f.KEY = 'OutdoorSeating' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS outdoor_seating,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsDelivery' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END
			END) AS restaurants_delivery,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsPriceRange2' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END				
			END) AS restaurants_price_range,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsReservations' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END						
			END) AS restaurants_reservation,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsTakeOut' THEN 
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END	
			END) AS restaurants_take_out,
		MAX(CASE 
				WHEN f.KEY = 'WheelchairAccessible' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS wheelchair_accessible,
		MAX(CASE 
				WHEN f.KEY = 'WiFi' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END	
			END) AS wifi,
		MAX(CASE 
				WHEN f.KEY = 'Alcohol' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS alcohol,
		MAX(CASE 
				WHEN f.KEY = 'GoodForKids' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END				
			END) AS good_for_kid,
		MAX(CASE 
				WHEN f.KEY = 'DriveThru' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS drive_thru,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsAttire' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END				
			END) AS restaurants_attire,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsGoodForGroups' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS restaurants_good_for_group,
		MAX(CASE 
				WHEN f.KEY = 'RestaurantsTableService' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS restaurants_table_service,
		MAX(CASE 
				WHEN f.KEY = 'NoiseLevel' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS noise_level,
		MAX(CASE 
				WHEN f.KEY = 'BusinessAcceptsBitcoin' THEN
					CASE
						WHEN f.value = 'None' THEN NULL
						ELSE f.value
					END					
			END) AS business_accepts_bitcoin		
	FROM YELP.BUSINESS b,
		LATERAL FLATTEN(input => PARSE_JSON(b.BUSINESSJSON), path => 'attributes') f
	WHERE
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes IS NOT NULL, TRUE, FALSE)
		AND 
		IFF(PARSE_JSON(b.BUSINESSJSON):attributes <> 'None', TRUE, FALSE)
	GROUP BY business_id;

/** CREATE AND INSERT open_and_close_time TABLE **/
DROP TABLE IF EXISTS ODS.open_and_close_time;

CREATE TABLE ODS.open_and_close_time (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	open_time TIME,
	close_time TIME,
	day_of_the_week VARCHAR
);

INSERT INTO ODS.open_and_close_time (business_id, open_time, close_time, day_of_the_week)
SELECT 
	PARSE_JSON(b.BUSINESSJSON):business_id::STRING AS business_id,
	SPLIT(f.value, '-')[0] AS open_time,
	SPLIT(f.value, '-')[1] AS close_time,
	UPPER(f.KEY) AS day_of_the_week
FROM YELP.BUSINESS b,
	LATERAL FLATTEN(input => PARSE_JSON(b.BUSINESSJSON), path => 'hours') f
WHERE 
	IFF(PARSE_JSON(b.BUSINESSJSON):hours IS NOT NULL, TRUE, FALSE);

/** CREATE AND INSERT open_and_close_time TABLE **/
DROP TABLE IF EXISTS ODS.checkin;

CREATE TABLE ODS.checkin (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	precipitation_id NUMBER FOREIGN KEY REFERENCES ODS.precipitation(id),
	temperature_id NUMBER FOREIGN KEY REFERENCES ODS.temperature(id),
	date TIMESTAMP
);

INSERT INTO ODS.checkin (business_id, date, precipitation_id, temperature_id)
SELECT checkIn.*, prec.id, tempe.id FROM
(SELECT 
	PARSE_JSON(c.CHECKINJSON):business_id::STRING AS business_id,
	checkInDate.value
FROM YELP.CHECKIN c,
	TABLE(SPLIT_TO_TABLE(PARSE_JSON(c.CHECKINJSON):date::STRING, ',')) AS checkInDate) checkIn
INNER JOIN ODS.TEMPERATURE tempe ON tempe."date" = TO_DATE(checkIn.value)
INNER JOIN ODS.PRECIPITATION prec ON prec."date" = TO_DATE(checkIn.value);

/** CREATE AND INSERT covid TABLE **/
DROP TABLE IF EXISTS ODS.covid;

CREATE TABLE ODS.covid (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	call_to_action_enabled BOOLEAN,
	covid_banner VARCHAR,
	grubhub_enabled BOOLEAN,
	request_a_quote_enabled BOOLEAN,
	temporary_closed_until TIMESTAMP,
	virtual_services_offered VARCHAR,
	delivery_or_take_out BOOLEAN,
	highlights VARCHAR
);

INSERT INTO ODS.covid (business_id, call_to_action_enabled, covid_banner, grubhub_enabled, request_a_quote_enabled, temporary_closed_until, virtual_services_offered, delivery_or_take_out, highlights)
SELECT 
	PARSE_JSON(c.COVIDJSON):business_id::STRING AS business_id,
	PARSE_JSON(c.COVIDJSON):"Call To Action enabled"::BOOLEAN AS call_to_action_enabled,
	CASE 
		WHEN PARSE_JSON(c.COVIDJSON):"Covid Banner"::STRING = 'FALSE' THEN NULL 
		ELSE PARSE_JSON(c.COVIDJSON):"Covid Banner"::STRING 
	END AS covid_banner,
	PARSE_JSON(c.COVIDJSON):"Grubhub enabled"::BOOLEAN AS grubhub_enabled,
	PARSE_JSON(c.COVIDJSON):"Request a Quote Enabled"::BOOLEAN AS request_a_quote_enabled,
	CASE 
		WHEN PARSE_JSON(c.COVIDJSON):"Temporary Closed Until"::STRING = 'FALSE' THEN NULL 
		ELSE PARSE_JSON(c.COVIDJSON):"Temporary Closed Until"::TIMESTAMP 
	END AS temporary_closed_until,
	CASE 
		WHEN PARSE_JSON(c.COVIDJSON):"Virtual Services Offered"::STRING = 'FALSE' THEN NULL 
		ELSE PARSE_JSON(c.COVIDJSON):"Virtual Services Offered"::STRING 
	END AS virtual_services_offered,
	PARSE_JSON(c.COVIDJSON):"delivery or takeout"::BOOLEAN AS delivery_or_take_out,
	CASE 
		WHEN PARSE_JSON(c.COVIDJSON):"highlights"::STRING = 'FALSE' THEN NULL 
		ELSE PARSE_JSON(c.COVIDJSON):"highlights"::STRING 
	END AS highlights
FROM YELP.COVID c

/** CREATE AND INSERT user TABLE **/
DROP TABLE IF EXISTS ODS.user;

CREATE TABLE ODS.user (
	user_id VARCHAR PRIMARY KEY,
	"name" VARCHAR,
	average_stars NUMBER,
	compliment_cool NUMBER,
	compliment_cute NUMBER,
	compliment_funny NUMBER,
	compliment_hot NUMBER,
	compliment_list NUMBER,
	compliment_more NUMBER,
	compliment_note NUMBER,
	compliment_photos NUMBER,
	compliment_plain NUMBER,
	compliment_profile NUMBER,
	compliment_writer NUMBER,
	cool NUMBER,
	fans NUMBER,
	funny NUMBER,
	review_count NUMBER,
	useful NUMBER,
	yelping_since TIMESTAMP
);

INSERT INTO ODS.user (user_id, "name", average_stars, compliment_cool, compliment_cute, compliment_funny, compliment_hot, compliment_list, compliment_more, compliment_note, compliment_photos, compliment_plain, compliment_profile, compliment_writer, cool, fans, funny, review_count, useful, yelping_since) 
SELECT 
	PARSE_JSON(c.CUSTOMERJSON):user_id::STRING AS user_id,
	PARSE_JSON(c.CUSTOMERJSON):name::STRING AS "name",
	PARSE_JSON(c.CUSTOMERJSON):average_stars::NUMBER AS average_stars,
	PARSE_JSON(c.CUSTOMERJSON):compliment_cool::NUMBER AS compliment_cool,
	PARSE_JSON(c.CUSTOMERJSON):compliment_cute::NUMBER AS compliment_cute,
	PARSE_JSON(c.CUSTOMERJSON):compliment_funny::NUMBER AS compliment_funny,
	PARSE_JSON(c.CUSTOMERJSON):compliment_hot::NUMBER AS compliment_hot,
	PARSE_JSON(c.CUSTOMERJSON):compliment_list::NUMBER AS compliment_list,
	PARSE_JSON(c.CUSTOMERJSON):compliment_more::NUMBER AS compliment_more,
	PARSE_JSON(c.CUSTOMERJSON):compliment_note::NUMBER AS compliment_note,
	PARSE_JSON(c.CUSTOMERJSON):compliment_photos::NUMBER AS compliment_photos,
	PARSE_JSON(c.CUSTOMERJSON):compliment_plain::NUMBER AS compliment_plain,
	PARSE_JSON(c.CUSTOMERJSON):compliment_profile::NUMBER AS compliment_profile,
	PARSE_JSON(c.CUSTOMERJSON):compliment_writer::NUMBER AS compliment_writer,
	PARSE_JSON(c.CUSTOMERJSON):cool::NUMBER AS cool,
	PARSE_JSON(c.CUSTOMERJSON):fans::NUMBER AS fans,
	PARSE_JSON(c.CUSTOMERJSON):funny::NUMBER AS funny,
	PARSE_JSON(c.CUSTOMERJSON):review_count::NUMBER AS review_count,
	PARSE_JSON(c.CUSTOMERJSON):useful::NUMBER AS useful,
	PARSE_JSON(c.CUSTOMERJSON):yelping_since::TIMESTAMP AS yelping_since
FROM YELP.USER c;

SELECT * FROM ODS.user;

/** CREATE AND INSERT review TABLE **/
DROP TABLE IF EXISTS ODS.review;

CREATE TABLE ODS.review (
	review_id VARCHAR PRIMARY KEY,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	user_id VARCHAR FOREIGN KEY REFERENCES ODS.user(user_id),
	precipitation_id NUMBER FOREIGN KEY REFERENCES ODS.precipitation(id),
	temperature_id NUMBER FOREIGN KEY REFERENCES ODS.temperature(id),
	cool NUMBER,
	funny NUMBER,
	star NUMBER,
	useful NUMBER,
	"text" TEXT,
	"date" TIMESTAMP
);

INSERT INTO ODS.review (review_id, business_id, user_id, cool, funny, star, useful, "text", "date", temperature_id, precipitation_id)
SELECT 
	PARSE_JSON(c.REVIEWJSON):review_id::STRING AS review_id,
	PARSE_JSON(c.REVIEWJSON):business_id::STRING AS "business_id",
	PARSE_JSON(c.REVIEWJSON):user_id::STRING AS user_id,
	PARSE_JSON(c.REVIEWJSON):cool::NUMBER AS cool,
	PARSE_JSON(c.REVIEWJSON):funny::NUMBER AS funny,
	PARSE_JSON(c.REVIEWJSON):stars::NUMBER AS star,
	PARSE_JSON(c.REVIEWJSON):useful::NUMBER AS useful,
	PARSE_JSON(c.REVIEWJSON):text::TEXT AS "text",
	PARSE_JSON(c.REVIEWJSON):date::TIMESTAMP AS "date",
	tempe.id AS temperature_id,
	prec.id AS precipitation_id
FROM YELP.REVIEW c
INNER JOIN ODS.TEMPERATURE tempe ON tempe."date" = PARSE_JSON(c.REVIEWJSON):date::DATE
INNER JOIN ODS.PRECIPITATION  prec ON prec."date" = PARSE_JSON(c.REVIEWJSON):date::DATE;

/** CREATE AND INSERT tip TABLE **/
DROP TABLE IF EXISTS ODS.tip;

CREATE TABLE ODS.tip (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	business_id VARCHAR FOREIGN KEY REFERENCES ODS.business(business_id),
	user_id VARCHAR FOREIGN KEY REFERENCES ODS.user(user_id),
	compliment_count NUMBER,
	"text" TEXT,
	"date" TIMESTAMP
);

INSERT INTO ODS.tip (business_id, user_id, compliment_count, "text", "date")
SELECT 
	PARSE_JSON(c.TIPJSON):business_id::STRING AS business_id,
	PARSE_JSON(c.TIPJSON):user_id::STRING AS user_id,
	PARSE_JSON(c.TIPJSON):compliment_count::NUMBER AS compliment_count,
	PARSE_JSON(c.TIPJSON):text::TEXT AS "text",
	PARSE_JSON(c.TIPJSON):date::TIMESTAMP AS "date"
FROM YELP.TIP c;

/** CREATE AND INSERT user_elite TABLE **/
DROP TABLE IF EXISTS ODS.user_elite;

CREATE TABLE ODS.user_elite (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	user_id VARCHAR FOREIGN KEY REFERENCES ODS.user(user_id),
	elite INT
);

INSERT INTO ODS.user_elite (user_id, elite)
SELECT 
	PARSE_JSON(c.CUSTOMERJSON):user_id::STRING AS user_id,
	e.value 
FROM YELP.USER c,
	TABLE(SPLIT_TO_TABLE(PARSE_JSON(c.CUSTOMERJSON):elite::STRING, ',')) AS e
WHERE PARSE_JSON(c.CUSTOMERJSON):elite::STRING <> '';

/** CREATE AND INSERT user_friend TABLE **/
DROP TABLE IF EXISTS ODS.user_friend;

CREATE TABLE ODS.user_friend (
	id NUMBER PRIMARY KEY autoincrement start 1 increment 1,
	user_id_1 VARCHAR FOREIGN KEY REFERENCES ODS.user(user_id),
	user_id_2 VARCHAR FOREIGN KEY REFERENCES ODS.user(user_id)
);

INSERT INTO ODS.user_friend (user_id_1, user_id_2)
SELECT 
	PARSE_JSON(c.CUSTOMERJSON):user_id::STRING AS user_id_1,
	e.value AS user_id_2
FROM YELP.USER c,
	TABLE(SPLIT_TO_TABLE(PARSE_JSON(c.CUSTOMERJSON):friends::STRING, ',')) AS e

