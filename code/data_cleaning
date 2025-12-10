/*
===========================================================================

DATA CLEANING (NOTE: Done in PostgreSQL)

===========================================================================
*/

-- Starting with PriceList Table:

-- Dropping dummy column used to accomodate for csv file structure (Blank first column):
ALTER TABLE stg2_price_list
DROP COLUMN dummy;

-- Price column currently looks like: 'A£[price]' --> need to extract numerical value
UPDATE stg2_price_list
SET price = SUBSTRING(price, POSITION('£' IN price) + 1);


-- Changing price data type to Numeric, have to remove commas first:
UPDATE stg2_price_list
SET price = REPLACE(price, ',', '');

-- Changing Data Type:
ALTER TABLE stg2_price_list
ALTER COLUMN price TYPE NUMERIC(10, 2) USING price::NUMERIC(10,2);


-- Removing trailing spaces from band column:
UPDATE stg2_price_list
SET band = TRIM(band);



/*
===========================================================================

PRICE LIST CLEAN

MOVING ON TO CURRENT LIVE CUSTOMERS

===========================================================================
*/




SELECT * FROM stg2_current_live_customers;


-- Changing all date columns to the necessary data type:
ALTER TABLE stg2_current_live_customers
ALTER COLUMN accountstagedate TYPE DATE USING TO_DATE(NULLIF(accountstagedate, ''), 'MM/DD/YYYY'),
ALTER COLUMN registrationdate TYPE DATE USING TO_DATE(NULLIF(registrationdate, ''), 'MM/DD/YYYY'),
ALTER COLUMN renewaldate TYPE DATE USING TO_DATE(NULLIF(renewaldate, ''), 'MM/DD/YYYY'),
ALTER COLUMN auditstatusdate TYPE DATE USING TO_DATE(NULLIF(auditstatusdate, ''), 'MM/DD/YYYY');




-- Looking at columns and seeing if there are any problems in the data:
SELECT * FROM stg2_current_live_customers;



-- Standardizing Account Stage column:
UPDATE stg2_current_live_customers
SET accountstage = 'Vetting'
WHERE accountstage = 'vetting';



-- Making sure band column has no trailing spaces:
SELECT DISTINCT TRIM(band) FROM stg2_price_list;





-- Filling in price column:

-- Query demonstrating logic for filling:
SELECT 
	clc.coref, 
	clc.band,
	clc.price,
	pl.price
FROM stg2_current_live_customers clc
INNER JOIN stg2_price_list pl
	ON clc.band = pl.band;
-- Gives us appropriate prices per band




-- Filling:
UPDATE stg2_current_live_customers AS clc
SET price = pl.price
FROM stg2_price_list pl
WHERE clc.band = pl.band;



-- Still some remaining NULL prices for some reason, all relating to Band B:
-- Need to make sure Band B in the price table is free of trailing spaces as this is what is causing the problem

UPDATE stg2_current_live_customers AS clc
SET price = pl.price
FROM stg2_price_list pl
WHERE clc.band = pl.band
AND clc.price IS NULL;

-- Price column successfully filled






-- Dealing with Tenure NULLs:
-- The following query (subtracting registration date from the max account stage date) gives accurate results for all existing
-- values for tenure in the table (difference of 1 in about all cases). Will therefore be using this top fill in tenure NULLs, 2 in total

-- The query:
SELECT tenure, EXTRACT(YEAR FROM AGE((SELECT MAX(accountstagedate) FROM stg2_current_live_customers), registrationdate)) + 1
FROM stg2_current_live_customers
WHERE tenure is not null;




-- Filling in tenure NULLs:
UPDATE stg2_current_live_customers
SET tenure = EXTRACT(YEAR FROM AGE((SELECT MAX(accountstagedate) FROM stg2_current_live_customers), registrationdate)) + 1
WHERE tenure IS NULL;




-- Filling empty renewaldate NULLs:
UPDATE stg2_current_live_customers_dedup
SET renewaldate = (registrationdate + (tenure || 'years')::INTERVAL)::DATE
WHERE renewaldate IS NULL;





-- DUPLICATES:
WITH dups AS (SELECT *,
				  ROW_NUMBER() OVER (PARTITION BY coref, subsidiarytype, accountstage, 
				  membershipstatus, auditstatus) AS row_num
			  FROM stg2_current_live_customers)
SELECT *
FROM dups
WHERE row_num > 1;
-- No duplicate rows found




-- Duplicates in CoRef column:
SELECT coref--, COUNT(*) AS num_dups
FROM stg2_current_live_customers
GROUP BY coref
HAVING COUNT(*) > 1;
-- 33 duplicates



-- Looking at CoRef duplicate rows:
SELECT *
FROM stg2_current_live_customers
WHERE coref IN (SELECT coref--, COUNT(*) AS num_dups
				FROM stg2_current_live_customers
				GROUP BY coref
				HAVING COUNT(*) > 1)
ORDER BY coref, auditstatusdate DESC;





-- DEDUPLICATING CURRENT LIVE CUSTOMERS:

-- Creating clean, deduplicated Current Live Customers table
DROP TABLE IF EXISTS stg2_current_live_customers_dedup;

CREATE TABLE stg2_current_live_customers_dedup AS
SELECT DISTINCT ON (coref)
    *
FROM stg2_current_live_customers
ORDER BY 
    coref,
    -- Keep Published -> Vetting -> Membership Only -> Suspended
    CASE accountstage 
        WHEN 'Published' THEN 1
        WHEN 'Vetting' THEN 2
        WHEN 'Renewal Process' THEN 3
        WHEN 'Membership Only' THEN 4
        WHEN 'Suspended' THEN 5
        ELSE 6
    END,
    -- Keep Accredited > Member Only
    CASE membershipstatus
        WHEN 'Accredited' THEN 1
        WHEN 'Member Only' THEN 2
        ELSE 3
    END,
    -- Most recent date as tiebreaker
    GREATEST(
        COALESCE(accountstagedate, '1900-01-01'::DATE),
        COALESCE(auditstatusdate, '1900-01-01'::DATE),
        COALESCE(renewaldate, '1900-01-01'::DATE)
    ) DESC NULLS LAST,
    -- Highest price
    price DESC NULLS LAST,
    -- Longest tenure
    tenure DESC NULLS LAST;




-- Verifying uniqueness:
SELECT 
    COUNT(*) as total_rows,
    COUNT(DISTINCT coref) as unique_corefs
FROM dim_currentlivecustomers_clean;
-- Both should be 13,644






/*
=====================================================================================================
CURRENT LIVE CUSTOMERS CLEAN

MOVING ON TO RENEWING CUSTOMERS
=====================================================================================================
*/







-- Dropping dummy column used in import to accomodate for CSV structure:
ALTER TABLE stg2_renewing_customers
DROP COLUMN dummy_col;


SELECT *
FROM stg2_renewing_customers;

-- Changing data types to appropriate type (dates, etc.)

-- Checking if conversion of renewaldate column to date will work:
SELECT TO_DATE(NULLIF(renewaldate, ''), 'MM/DD/YYYY')
FROM stg2_renewing_customers;


-- Problematic date value in renewaldate column: "29/10.2020"
-- Fixing (ie updating to string of date in correct format for subsequent conversion):


UPDATE stg2_renewing_customers
SET renewaldate = '10/29/2020'
WHERE renewaldate = '29/10.2020';


-- Changing Data Type:
ALTER TABLE stg2_renewing_customers
ALTER COLUMN renewaldate TYPE DATE USING TO_DATE(NULLIF(renewaldate, ''), 'MM/DD/YYYY');



-- Extracting Band from product column to then be used to fill price column:
SELECT coref,
	SUBSTRING(product, STRPOS(product, ' ') + 1) -- STRPOS returns position of first occurence of a space, substring takes everything after, excluding leading space
FROM stg2_renewing_customers;					 -- More Dynamic than just using RIGHT(product, 7)


-- Adding column for just band:
ALTER TABLE stg2_renewing_customers
ADD COLUMN band VARCHAR(50);


-- Filling band values:
UPDATE stg2_renewing_customers
SET band = SUBSTRING(product, STRPOS(product, ' ') + 1);




SELECT DISTINCT band FROM stg2_renewing_customers;

-- Spelling errors for Band B (Spelt as Bond B). Fixing:
UPDATE stg2_renewing_customers
SET band = 'Band B'
WHERE band = 'Bond B';







-- Filling client column: # times CoRef appears in supplemental data

-- To see if any CoRefs from Renewing Customers table don't appear in the supplemental data:
SELECT *
FROM
(SELECT rc.coref, sd.coref AS sd_coref
FROM stg2_renewing_customers rc
LEFT JOIN stg2_supplemental_data sd
	ON rc.coref = sd.coref) integrity_check
WHERE sd_coref IS NULL;
-- No rows showed up --> match for every CoRef in Renewing customers table


-- Filling:
WITH client_counts AS (SELECT coref, COUNT(*) AS client_count
					   FROM stg2_supplemental_data
					   GROUP BY coref)
UPDATE stg2_renewing_customers_clean rc
SET clients = COALESCE(cc.client_count, 0) -- In case any NULLs result
FROM client_counts AS cc
WHERE rc.coref = cc.coref;

-- CLIENT COLUMN GOOD TO GO











-- FILLING BAND C values with C1 or C2:
-- Approach: Could either: 1) just fill in their price values with the average of C1 and C2 band pricing (350) OR
-- 2) Since band pricing seems to be a result of number of employees, can segment the range of Band C CoRefs into
-- 2 equal segments based on the range of employees for CoRefs in Band C
-- Will use approach 2

SELECT MAX(employees) - MIN(employees) AS emp_range,
	MIN(employees),
	MAX(employees)
FROM stg2_renewing_customers_clean
WHERE band = 'Band C';


-- Companies within Band C have between 4 and 24 employees, though when lookig at the data, it does seem that Band C 
-- pricing typically kicks in at 5 employees and goes until 15. This could potentially suggest that a recalculation
-- of Bands for all CoRefs could be necessary, but since I don't have Alcumus SafeContractor's concrete pricing plan
-- per employee count and may be missing some contextual reasoning, I will just fix the values in the Band C column


-- NOTE: Could Replace ALL Band values based on inferred employee count per band:
/*
employees (ranges inclusive)		Band
1									A / B (could be an error for those in B, but again, I could be unaware of certain pieces of information)
----------------------------------------
2-4									B
----------------------------------------
5-15								C
----------------------------------------
16-30								D
----------------------------------------
31-50								E
----------------------------------------
51 - 250 (roughly)					F
----------------------------------------
251+								G
----------------------------------------

To fix all values this way, would need to do the following within an UPDATE statement:

SELECT CoRef, employees,
	CASE
		WHEN employees = 1 THEN 'Band A'
		WHEN employees BETWEEN 2 AND 4 THEN 'Band B'
		WHEN employees BETWEEN 5 AND 9 THEN 'Band C1'
		WHEN employees BETWEEN 10 AND 15 THEN 'Band C2'
		WHEN employees BETWEEN 16 AND 30 THEN 'Band D'
		WHEN employees BETWEEN 31 AND 50 THEN 'Band E'
		WHEN employees BETWEEN 51 AND 250 THEN 'Band F'
		WHEN employees > 250 THEN 'Band G'
		END AS adjusted_band
FROM stg2_renewing_customers
ORDER BY employees;

I am going to choose to play it conservatively here and just reassign Band C values to either C1 or C2
*/


-- FILLING BAND C VALUES USING:
-- 5 <= employees <= 9 --> C1
-- 10 <= employees <= 15 --> C2

-- Also could fix 2 values where CoRefs with 4 employees are in Band C, switching to B
-- Could be wrong as well but I don't have the necessary information to get precise band employee distributions, and don't know
-- if this could be on purpose


-- Fill:
UPDATE stg2_renewing_customers
SET band = CASE 
    WHEN employees BETWEEN 5 AND 10 THEN 'Band C1'
    WHEN employees BETWEEN 11 AND 15 THEN 'Band C2'
    ELSE 'Band C1'  -- Default in case criteria isn't met
END
WHERE band = 'Band C';



-- Filling in price column:
-- Logic for fill: Join price table, extract price itself from associated band
SELECT rc.band,
	rc.price,
	pl.price
FROM stg2_renewing_customers rc
INNER JOIN stg2_price_list pl
	ON rc.band = pl.band;



-- Filling:
UPDATE stg2_renewing_customers AS rc
SET price = pl.price
FROM stg2_price_list pl
WHERE rc.band = pl.band;



-- CONVERTING PRICE TO NUMERIC:
ALTER TABLE stg2_renewing_customers
ALTER COLUMN price TYPE NUMERIC(10,2) USING price::NUMERIC(10,2);






-- Duplicates:
WITH dups AS (SELECT *,
				  ROW_NUMBER() OVER(PARTITION BY coref, renewaldate, employees, product, prospectstatus, prospectoutcome) AS row_num
			  FROM stg2_renewing_customers)
SELECT *
FROM dups
WHERE row_num > 1;

-- One duplicate where whole row concerned, let's look at duplicates for just CoRef:

SELECT coref
FROM stg2_renewing_customers
GROUP BY coref
HAVING COUNT(*) > 1;

SELECT *
FROM stg2_renewing_customers
WHERE coref IN (SELECT coref
				FROM stg2_renewing_customers
				GROUP BY coref
				HAVING COUNT(*) > 1)
ORDER BY coref, renewaldate DESC;

SELECT *
FROM stg2_supplemental_data
WHERE coref = 'QR2344';

SELECT *
FROM stg2_current_live_customers
WHERE coref = 'QR2344';

-- 4 duplicate pairs of CoRef, 2 of which are marked "Duplicate Entry" in the prospectstatus column,
-- one has just a difference in the renewal date column, and 1 is a complete duplicate (whole row)


-- Removing entries specificly marked as duplicates:
DELETE FROM stg2_renewing_customers
WHERE prospectstatus = 'Duplicate Entry';


-- Dealing with the 2 other duplicate pairs:


WITH dups AS (SELECT *,
				  ROW_NUMBER() OVER(PARTITION BY coref ORDER BY renewaldate DESC) AS row_num
			  FROM stg2_renewing_customers)
SELECT *
FROM dups
WHERE row_num > 1;


-- Creating table to be without duplicates:
DROP TABLE IF EXISTS stg2_renewing_customers_clean CASCADE; -- Used Cascade as I had a View created that depended on this table
CREATE TABLE stg2_renewing_customers_clean
(
    CoRef VARCHAR(50),
    RenewalDate DATE,
    Employees INT,
    Product VARCHAR(100),
    ProspectStatus VARCHAR(100),
    ProspectOutcome VARCHAR(50),
    Clients INT,
    Price NUMERIC(10,2),
	band VARCHAR(50),
	row_num INT
);


-- Insert into table with identified duplicates:
INSERT INTO stg2_renewing_customers_clean
SELECT *,
	ROW_NUMBER() OVER(PARTITION BY coref ORDER BY renewaldate DESC) AS row_num
FROM stg2_renewing_customers;


-- Delete duplicate rows:
DELETE 
FROM stg2_renewing_customers_clean
WHERE row_num > 1;

-- Make sure they're gone:
SELECT *
FROM stg2_renewing_customers_clean
WHERE row_num > 1;


-- Delete row_num column from new, clean table:
ALTER TABLE stg2_renewing_customers_clean
DROP COLUMN row_num;





---------------------- FEATURE ENGINEERING: PROSPECT STATUS --------------------------------------------

-- Some prospect statuses are marked as 'Attempted Contact', 'Intention to Proceed', 'Need time to consider', and more indicating that the clients 
-- aren't necessarily Lost yet. I assume they are all marked as lost until they actually renew. 
-- Also, some are marked as "Existing SafeContractor Member" (20 in total) which means they aren't lost and should be marked as "Won" or removed from the table
-- I will make a new column that differentiates between these cases and separates them into new categories that will drive analysis:



-- Adding column to store new prospect categories:
ALTER TABLE stg2_renewing_customers_clean
ADD COLUMN prospectstatus_category VARCHAR(50);



UPDATE stg2_renewing_customers_clean
SET prospectstatus_category = 
CASE
	-- Price Objections (Actionable):
	WHEN prospectstatus IN (
		'Not Affordable',
        'Not Value for Money',
        'Price Increase',
        'Insufficient Contract Value') THEN 'Price Objections / Low Derived Value'
	

	-- Customer Service (Actionable):
	WHEN prospectstatus IN ('Poor Customer Service') THEN 'Customer Service Issues'

	-- Audit Troubles (Don't know whether SafeContractor's fault or client's fault, likely client)
	WHEN prospectstatus IN ('Can''t Pass Audit') THEN 'Audit Not Passed'

	-- Loss to Competitors:
	WHEN prospectstatus IN ('Competitor Accreditation') THEN 'Loss to Competitor'

	-- Circumstantial Changes (not Safecontractor's fault):
	WHEN prospectstatus IN (
		'Do Not Work for Client',
        'Outside UK',
        'No Longer Trading',
        'Supply Only',  -- Changed from contractor to supplier (Might be wrong on what Supply Only means)
        'Lost Anchor Client', -- Lost contract requiring accreditation (ie Safecontractor's services not as valuable to them anymore, though could be used to find new contracts)
        'Anchor client close down'
		) THEN 'Circumstantial'

	-- Not Lost Yet:
	WHEN prospectstatus IN (
		'Need time to consider',
        'Need time to consider - 30 days',
        'Need time to consider - 60 days',
        'Need time to consider - 90 days',
        'Intention to Proceed',
        'Contact Made Deciding', 'Attempted Contact') THEN 'Still in Decision Process'

	-- Unresponsive:
    WHEN prospectstatus IN (
        'Non Responsive',
        'Refused to Discuss'
    ) THEN 'Unresponsive'

	-- Payment Issues:
    WHEN prospectstatus IN (
        'Promised to Pay - Fees not Received'
    ) THEN 'Payment Issues'

    -- Unknown Reasons:
    WHEN prospectstatus IN ('Unable to Confirm Reason for Cancellation', 'Existing safecontractor member')
        THEN 'Unknown'
    
    ELSE 'Renewed' -- remaining prospect status is renewed, ie Won. 
END;
	






-- Making changes to prospectoutcome column to reflect reality (ie marking some contractors a spending as they aren't lost yet):
BEGIN;
UPDATE stg2_renewing_customers_clean
SET prospectoutcome = 
CASE
	WHEN prospectstatus IN ('Need time to consider', 
							'Attempted Contact',
							'Need time to consider - 30 days',
							'Need time to consider - 60 days',
							'Need time to consider - 90 days',
							'Contact Made Deciding', 'Intention to Proceed',
							'Non Responsive', 'Promised to Pay - Fees not Received') THEN 'Pending' END
WHERE prospectstatus IN ('Need time to consider', 
							'Attempted Contact',
							'Need time to consider - 30 days',
							'Need time to consider - 60 days',
							'Need time to consider - 90 days',
							'Contact Made Deciding', 'Intention to Proceed',
							'Non Responsive', 'Promised to Pay - Fees not Received');

COMMIT;

BEGIN;
UPDATE stg2_renewing_customers_clean
SET prospectoutcome = 'Pending'
WHERE prospectstatus = 'Existing safecontractor member';

COMMIT;









/*
=====================================================================================================
RENEWING CUSTOMERS CLEAN

MOVING ON TO SUPPLEMENTAL DATA
=====================================================================================================
*/


SELECT * FROM stg2_supplemental_data;

-- Removing dummy column:
ALTER TABLE stg2_supplemental_data
DROP COLUMN dummy;



-- Converting registrationdate to date:
SELECT 
	TO_DATE(NULLIF(registrationdate, ''), 'MM/DD/YYY')
FROM stg2_supplemental_data;

ALTER TABLE stg2_supplemental_data
ALTER COLUMN registrationdate TYPE DATE USING TO_DATE(NULLIF(registrationdate, ''), 'MM/DD/YYY');


-- Converting ssip to CHAR(1):
ALTER TABLE stg2_supplemental_data
ALTER COLUMN ssipmember TYPE CHAR(1);


--Converting NULL company types to 'Other', as company types couldn't be derived from other factors:
UPDATE stg2_supplemental_data
SET companytype = 'Other'
WHERE companytype IS NULL;


SELECT *
FROM stg2_supplemental_data WHERE companytype IS NULL;

-- Good to go




