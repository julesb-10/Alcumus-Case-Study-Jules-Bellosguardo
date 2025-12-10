/*
============================================================================================================

RENEWING CUSTOMERS EDA

- Note on Analysis: The provided renewing customers dataset comes from 2020, when COVID introduced itself.
Though this surely played a major part on whether clients renewed or not, it is only slightly taken into account here.

- ALSO: I place myself in 2020 for this analysis and therefore re-categorized all prospect statuses marked
as 'Need Time to Consider' or related as 'Pending'

- Lastly, lots of these queries are just exploratory and weren't included in the dashboard

============================================================================================================
*/





-- Looking at amount of clients who were won (retained) and lost in 2020:
SELECT COUNT(*) FILTER (WHERE prospectoutcome = 'Won') AS renewed_clients,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') AS lost_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Won') * 1.0 / COUNT(*) * 100, 2) AS pct_won,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') * 1.0 / COUNT(*) * 100, 2) AS pct_lost,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') AS pending_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') * 1.0 / COUNT(*) * 100, 2) AS pct_pending
FROM stg2_renewing_customers_clean;

-- 5.24% Won, 33.34% Pending and 61.51% Lost


-- ARR Lost & Retained:
SELECT prospectoutcome,
	TO_CHAR(SUM(price), 'FM999,999,999') AS arr
FROM stg2_renewing_customers_clean
GROUP BY prospectoutcome;

-- 298,700 in Annual recurring revenue lost due to clients not renewing


--------------------------------------------------------------------------------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN renewaldate < '2020-03-23' THEN 'Pre-COVID (Jan-Mar)'
        WHEN renewaldate BETWEEN '2020-03-23' AND '2020-06-30' THEN 'Lockdown 1 (Mar-Jun)'
        WHEN renewaldate BETWEEN '2020-07-01' AND '2020-10-31' THEN 'Summer/Autumn (Jul-Oct)'
        ELSE 'Lockdown 2 (Nov-Dec)'
    END as period,
    COUNT(*) as total,
    SUM(CASE WHEN prospectoutcome = 'Won' THEN 1 ELSE 0 END) as won,
    SUM(CASE WHEN prospectoutcome = 'Pending' THEN 1 ELSE 0 END) as pending,
    SUM(CASE WHEN prospectoutcome = 'Lost' THEN 1 ELSE 0 END) as lost,
    ROUND(100.0 * SUM(CASE WHEN prospectoutcome = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate,
	ROUND(100.0 * SUM(CASE WHEN prospectoutcome = 'Pending' THEN 1 ELSE 0 END) / COUNT(*), 2) as pending_rate,
	ROUND(100.0 * SUM(CASE WHEN prospectoutcome = 'Lost' THEN 1 ELSE 0 END) / COUNT(*), 2) as loss_rate
FROM stg2_renewing_customers_clean
GROUP BY period
ORDER BY MIN(renewaldate);

-- Win rates were significantly higher in the beginning of the year (~15% vs 4.35% in last few months), though there were also much less
-- clients up for renewal (81 in first half of year vs 1044 in second half of the year)



-- Breakdown of Pending statuses
SELECT prospectstatus, COUNT(*), 
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) as pct
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Pending'
GROUP BY prospectstatus
ORDER BY COUNT(*) DESC;

-- Out of all pending customers, 66.04% were unresponsive to Alcumus' attempts to contact them about subscription renewal




-- Renewal date distribution (check for timing issues)
SELECT 
    EXTRACT(MONTH FROM renewaldate) as month,
    COUNT(*) as total,
    SUM(CASE WHEN prospectoutcome = 'Won' THEN 1 ELSE 0 END) as won,
    SUM(CASE WHEN prospectoutcome = 'Pending' THEN 1 ELSE 0 END) as pending,
    ROUND(100.0 * SUM(CASE WHEN prospectoutcome = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) as win_rate
FROM stg2_renewing_customers_clean
GROUP BY month
ORDER BY month;
-- High Win Rates in Jan and Feb (25%), though again, only 8 clients were up for renewal in this period. Renewal rates
-- per month decrease significantly once more clients are up for renewal










-- Seeing if clients in certain pricing bands more susceptible to leaving:
SELECT band,
	COUNT(*) AS clients_in_band,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Won') AS renewed_clients,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') AS lost_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Won') * 1.0 / COUNT(*) * 100, 2) AS band_renewal_rate_pct,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') * 1.0 / COUNT(*) * 100, 2) AS band_loss_rate_pct,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') AS pending_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') * 1.0 / COUNT(*) * 100, 2) AS band_pending_rate_pct
FROM stg2_renewing_customers_clean
GROUP BY band
ORDER BY band;

-- Bands B and C1 (assuming my reasoning during cleaning was valid) experienced the highest amount of client losses, 
-- In terms of loss rate, Band E suffered the highest rate with 77.27% and Band G just behind at 76.92%. To be investigated further

SELECT band,
	ROUND(AVG(clients), 2) AS avg_clients,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY clients) AS median_clients,
	PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY clients) AS p75_clients
FROM stg2_renewing_customers_clean
GROUP BY band
ORDER BY band;

-- Though average clients increases as band tiers do, but with Band G having average clients of 8.69,
-- contractors in this band have median clients of 1, and 75th percentile of clients of 3, meaning only 
-- 25% of contractors in Band G have more than 3 clients, potentially explaining why lots of them churn.
-- The numbers tell a similar story for contractors in Band E, but with a much lower average client count of 2

-- Though this doesn't explain it all, it does give some insight on why clients in this band may be leaving

select companytype, count(*)
from rc_and_supp
WHERE band = 'Band A'
group by companytype;


select prospectstatus, 
	COUNT(*) AS total,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean WHERE band = 'Band E' AND prospectoutcome = 'Lost'), 2) AS pct_total
FROM stg2_renewing_customers_clean
WHERE band = 'Band E' AND prospectoutcome = 'Lost'
GROUP BY prospectstatus;
-- 32.35% of clients in Band E that left cited 'Not Value for Money' as their reason for leaving, reinforcing the previous finding








-- Revenue Loss per band:
SELECT band,
	COUNT(*) AS contractors_in_band,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean), 2) AS pct_of_total_contractors_up_for_renewal,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean WHERE prospectoutcome = 'Lost'), 2) AS pct_of_total_contractors_lost,
	TO_CHAR(SUM(price), 'FM999,999,999') AS revenue_lost,
	ROUND(SUM(price) / (SELECT SUM(price) FROM stg2_renewing_customers_clean WHERE prospectoutcome = 'Lost') * 100, 2) AS pct_of_total_lost_revenue
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost'
GROUP BY band
ORDER BY pct_of_total_lost_revenue DESC;

-- Band B contributed the most to lost revenue (30.95% of total), followed by Band C1 contributing 19.46%. These two bands 
-- together combine for a revenue loss of 108,800 (50.41% of total)

-- Worth noting that the majority of all contractors up for renewal in 2020 were also from Bands B and C1 (68.5%)






-- Segmenting by derived prospect status categories from data cleaning section:

SELECT prospectstatus_category,
	COUNT(*) AS total,
	ROUND(COUNT(*) * 1.0 / (SELECT COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') FROM stg2_renewing_customers_clean) * 100, 2) AS pct_of_total
FROM stg2_renewing_customers_clean
WHERE prospectstatus_category <> 'Renewed'
GROUP BY prospectstatus_category
ORDER BY total DESC;

-- 41.91% of clients are unresponsive/refused to discuss when contact was made to renew, 10.61% left for unknown reasons,
-- 34.68% were due to circumstantial reasons (anchor client loss, no longer trading, etc.)

-- Price Objections / Low Derived Value contributed to 25.91% of lost clients in 2020. This isn't enough to conclude that
-- Safecontractor may be setting pricing too high, need to look at clients that left for this reason per band:


SELECT band,
	COUNT(*) AS total,
	ROUND(COUNT(*) * 1.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean WHERE prospectstatus_category = 'Price Objections / Low Derived Value') * 100, 2) AS pct_of_total,
	TO_CHAR(SUM(price), 'FM999,999,999') AS revenue_lost
FROM stg2_renewing_customers_clean
WHERE prospectstatus_category = 'Price Objections / Low Derived Value'
GROUP BY band
ORDER BY total DESC;
---------------------------------------------------------------------------------------------------------------------
-- INSIGHT: Here, we see that out of  customers that left for reasons relating to PRICING or DERIVED VALUE,
-- 50.55% were from the Band B pricing tier, with another 18% coming from Band C1 (could be faulty due to reasoning from data cleaning, ie not recategorizing bands)

-- We also see that for companies with more employees (higher Band price tier), they are less likely to leave due to pricing / value
-- reasons, indicating larger clients (ie with more employees) feel they get more out of SafeContractor than smaller clients.
---------------------------------------------------------------------------------------------------------------------

-- Seeing if added segmentation granularity gives more insight:

SELECT prospectstatus,
	band,
	COUNT(*) AS total,
	TO_CHAR(SUM(price), 'FM999,999,999') AS lost_revenue,
	ROUND(COUNT(*) * 1.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean WHERE prospectstatus_category = 'Price Objections / Low Derived Value') * 100, 2) AS pct_total,
	ROUND(AVG(employees), 2) AS avg_employees,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY employees) AS median_employees
FROM stg2_renewing_customers_clean
WHERE prospectstatus_category = 'Price Objections / Low Derived Value'
GROUP BY prospectstatus, band
ORDER BY total DESC;
---------------------------------------------------------------------------------------------------------------------
-- INSIGHT: These results tell us a lot. 42.07% of clients lost who listed 'Price Objections / Low Derived Value as their reason were in the Band B
-- price tier (citing Not Value for Money, with 16.97% coming from Band C1 (again, could be inaccurate based on how I filled pricing tiers for band C).

-- Though it makes up for just 15 lost clients (5.54%) out of only those who left for pricing / value reasons, it is worth noting that
-- Band B is most commonly mentioned when clients list 'Not Affordable' as a reason for leaving
---------------------------------------------------------------------------------------------------------------------


SELECT band,
	COUNT(*) AS band_total,
	COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') AS total_not_value_for_money,
	ROUND(COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') * 100.0 / COUNT(*), 2) AS pct_total_in_band,
	TO_CHAR(SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money'), 'FM999,999,999') AS rev_lost,
	ROUND(SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money') / SUM(price) * 100.0, 2) AS pct_total_band_rev_lost
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost'
GROUP BY band
ORDER BY total_not_value_for_money DESC;






-- seeing if there's a relationship between tenure and churn:
-- Using DERIVED tenure since for lost clients, can't get tenure from current live customers table.
-- Derived tenure = (renewing customers renewal date) - (registration date from supplemental data)


WITH tenures AS (SELECT DISTINCT(rc.coref),
					 rc.renewaldate,
					 sd.registrationdate,
					 EXTRACT(YEAR FROM AGE(rc.renewaldate, sd.registrationdate)) AS tenure_years,
					 sd.companytype,
					 sd.industrysector,
					 prospectoutcome,
					 prospectstatus_category
				 FROM stg2_renewing_customers_clean rc
				 INNER JOIN stg2_supplemental_data sd
					 ON rc.coref = sd.coref)
SELECT prospectoutcome,
	companytype,
	COUNT(*) AS total,
	ROUND(AVG(tenure_years), 2) AS avg_tenure,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tenure_years) AS median_tenure
FROM tenures
GROUP BY prospectoutcome, companytype
ORDER BY avg_tenure DESC;

-- Tenure (or the values for it I derived) don't have an apparent effect on clients leaving. Clients who were 'Won'
-- and were either partnerships or sole traders had the highest average and median tenures, though the sample size is very small


--------------------------COME BACK TO------------------------------------------------------------------------
SELECT package, COUNT(*) AS total,
	ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM stg2_renewing_customers_clean WHERE prospectoutcome = 'Won'), 2) AS pct_total
FROM
	(SELECT DISTINCT coref,
		package
	FROM stg2_current_live_customers_dedup clc
	WHERE coref IN (SELECT coref 
		FROM stg2_renewing_customers_clean
		WHERE prospectoutcome = 'Won')
		ORDER BY coref)
GROUP BY package;

-- 59.32% of retained customers had the Assisted package, indicating potentially better retention for those that opt
-- for this package due to its help in getting contractors accredited and available in SafeContractor's network to get contracts.

-- (NOTE: Not entirely sure on how Safecontractor's package plan works, so can't make to much out fo this info. Also,
-- I can't compare these to lost clients or pending as none of them appear in the Current Live Customers Data)

--------------------------------------------------------------------------------------------------------------








-- SSIP:
WITH supp_info AS (SELECT DISTINCT(rc.coref), -- To avoid duplicate results as renewing customers to supplemental data is 1:Many
					   rc.prospectoutcome,
					   rc.prospectstatus_category,
					   rc.clients,
					   ssipmember,
					   companytype,
					   industrysector
				   FROM stg2_renewing_customers_clean rc
				   INNER JOIN stg2_supplemental_data sd
					   ON rc.coref = sd.coref),
   ssip_win_loss AS (SELECT ssipmember,
						prospectoutcome,
						COUNT(*) AS total,
						ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY ssipmember), 2) AS pct_total
					FROM supp_info
					GROUP BY ssipmember, prospectoutcome
					ORDER BY ssipmember, prospectoutcome)
SELECT * FROM ssip_win_loss;
					
SELECT 
	ssipmember,
	prospectoutcome,
	SUM(total) AS total_y_or_n,
	ROUND(SUM(total) FILTER (WHERE prospectoutcome = 'Won') / SUM(total) * 100, 2) AS renewal_rate
FROM ssip_win_loss
GROUP BY ssipmember, prospectoutcome;

---------------------------------------------------------------------------------------------------------------------
-- We see here that renewal rates among clients who are SSIP members is almost twice as high as those who aren't SSIP members (8.8% vs 4.9%)
---------------------------------------------------------------------------------------------------------------------





WITH supp_info AS (SELECT DISTINCT(rc.coref), -- To avoid duplicate results as renewing customers to supplemental data is 1:Many
					   rc.prospectoutcome,
					   rc.prospectstatus_category,
					   rc.clients,
					   rc.band,
					   ssipmember,
					   companytype,
					   industrysector
				   FROM stg2_renewing_customers_clean rc
				   INNER JOIN stg2_supplemental_data sd
					   ON rc.coref = sd.coref)
SELECT companytype,
	band,
	prospectoutcome,
	COUNT(*) AS total,
	ROUND(COUNT(*) * 100.0 / (SUM(COUNT(*)) OVER (PARTITION BY companytype)), 2) AS pct_of_total,
	SUM(COUNT(*)) OVER (PARTITION BY companytype) AS total_company_type
FROM supp_info
GROUP BY companytype, band, prospectoutcome
ORDER BY companytype, band, pct_of_total DESC;







CREATE OR REPLACE VIEW rc_and_supp AS
SELECT DISTINCT(rc.coref), -- To avoid duplicate results as renewing customers to supplemental data is 1:Many
	rc.prospectoutcome,
	rc.prospectstatus,
	rc.prospectstatus_category,
	rc.clients,
	rc.band,
	rc.price,
	sd.ssipmember,
	sd.companytype,
	sd.industrysector,
	sd.registrationdate
FROM stg2_renewing_customers_clean rc
INNER JOIN stg2_supplemental_data sd
	ON rc.coref = sd.coref;


------------------------------------------------------------------------------------------------------




-- Compariung prop'ns of contractors in each band in RC and CLC:

SELECT band, count(*) as total,
	ROUND(count(*) * 100.0 / (select count(*) from stg2_renewing_customers_clean), 2) AS pct_of_total
FROM stg2_renewing_customers_clean
GROUP BY band
ORDER BY total DESC;



SELECT band, count(*) as clc_total,
	ROUND(count(*) * 100.0 / (select count(*) from stg2_current_live_customers_dedup), 2) AS pct_of_total
FROM stg2_current_live_customers_dedup
GROUP BY band
ORDER BY clc_total DESC;


-- Overall proportions frome ach band look rather similar
-- Band B: Made up 50.58% of total contractors up for renewal, and makes up for 36.9% of customer base



WITH client_tiers AS (SELECT *,
						CASE 
							WHEN clients = 1 THEN 'Signle Client'
							WHEN clients BETWEEN 2 AND 4 THEN 'Few Clients'
							ELSE 'Many Clients' END AS client_tier
					FROM stg2_renewing_customers_clean)
SELECT client_tier,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Won') AS renewed_clients,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') AS lost_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Won') * 1.0 / COUNT(*) * 100, 2) AS pct_won,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Lost') * 1.0 / COUNT(*) * 100, 2) AS pct_lost,
	COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') AS pending_clients,
	ROUND(COUNT(*) FILTER (WHERE prospectoutcome = 'Pending') * 1.0 / COUNT(*) * 100, 2) AS pct_pending
FROM client_tiers
GROUP BY client_tier;

-- Higher Churn Rate among those with a single or few clients, though not by much.
-- Renewal rate much higher among those with Many clients (more than 4), though sample 
-- size for these clients is quite small




/*
==================================================================================================================

Additional Exploratory Queries (can ignore)

==================================================================================================================
*/




SELECT COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') AS total_nvfm,
	SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money') AS rev_lost,
	SUM(price) AS total_rev_lost,
	ROUND(SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money') * 100 / SUM(price), 2) AS pct_rev_lost,
	COUNT(*) AS total_lost,
	ROUND(COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') * 100.0 / COUNT(*), 2) AS pct_total_lost
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost';

-- 'Not Value for Money' --> 31.88% of Lost Revenue


select prospectstatus_category, count(*) as total
from stg2_renewing_customers_clean
where prospectoutcome = 'Pending'
group by prospectstatus_category
order by total desc;


select prospectstatus, count(*) as total
from stg2_renewing_customers_clean
where prospectoutcome = 'Pending'
group by prospectstatus
order by total desc;


select prospectstatus, sum(price) as total from stg2_renewing_customers_clean where prospectstatus_category <> 'Circumstantial' 
AND prospectstatus <> 'Not Value for Money' AND prospectoutcome = 'Lost'
group by prospectstatus
order by total desc;


select band, count(*) as total_in_band, 
	count(*) filter (where prospectstatus_category = 'Unresponsive') as total_band_unresponsive,
	round(count(*) filter (where prospectstatus_category = 'Unresponsive') * 100.0 /  count(*), 2) as band_unresponsive_rate,
	sum(price) FILTER (where prospectstatus_category = 'Unresponsive') as rev_at_risk_unresponsive
from stg2_renewing_customers_clean
group by  band
order by band_unresponsive_rate desc;



select sum(price) as rev_at_risk
from stg2_renewing_customers_clean
where prospectstatus_category = 'Unresponsive';




SELECT band, COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') AS total_nvfm,
	COUNT(*) AS total_band_lost,
	SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money') AS rev_lost_nvfm,
	SUM(price) AS total_rev_lost_band,
	ROUND(SUM(price) FILTER (WHERE prospectstatus = 'Not Value for Money') * 100 / SUM(price), 2) AS pct_rev_lost_band_nvfm,
	ROUND(COUNT(*) FILTER (WHERE prospectstatus = 'Not Value for Money') * 100.0 / COUNT(*), 2) AS pct_total_lost_from_band
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost'
GROUP BY band
ORDER BY total_rev_lost_band DESC;



SELECT band, COUNT(*) FILTER (WHERE prospectstatus_category = 'Circumstantial') AS total_circumstantial,
	COUNT(*) AS total_band_lost,
	SUM(price) FILTER (WHERE prospectstatus_category = 'Circumstantial') AS rev_lost_circumstantial,
	SUM(price) AS total_rev_lost_band,
	ROUND(SUM(price) FILTER (WHERE prospectstatus_category = 'Circumstantial') * 100 / SUM(price), 2) AS pct_rev_lost_band_circumstantial,
	ROUND(COUNT(*) FILTER (WHERE prospectstatus_category = 'Circumstantial') * 100.0 / COUNT(*), 2) AS pct_total_lost_from_circumstantial
FROM stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost'
GROUP BY band
ORDER BY total_rev_lost_band DESC;

SELECT sum(price) from stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost' AND prospectstatus_category = 'Circumstantial';

SELECT prospectstatus, 
	count(*) total, 
	round(count(*) * 100.0 / (select count(*) from stg2_renewing_customers_clean where prospectstatus_category = 'Circumstantial'), 2) pct_total,
	sum(price) as rev_lost,
	sum(price) * 100 / (select sum(price) from stg2_renewing_customers_clean where prospectstatus_category = 'Circumstantial') as pct_circ_rev_loss
from stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost' AND prospectstatus_category = 'Circumstantial'
group by prospectstatus
order by total desc;


select prospectstatus_category, count(*) from stg2_renewing_customers_clean
WHERE prospectoutcome = 'Lost'
group by prospectstatus_category;

SELECT distinct prospectstatus AS total
FROM stg2_renewing_customers_clean
where prospectoutcome = 'Lost';

SELECT prospectstatus, count(*) as total
FROM stg2_renewing_customers_clean
where prospectoutcome = 'Lost'
group by prospectstatus
order by total desc;


select band,
	count(*) as total_lost_to_competitors
from rc_and_supp
where prospectstatus = 'Competitor Accreditation'
group by band
order by total_lost_to_competitors DESC;

select ssipmember, 
	count(*) as total,
	ROUND(count(*) * 100.0 / (SELECT COUNT(*) FROM rc_and_supp where prospectstatus = 'Competitor Accreditation'), 2) as pct_total
from rc_and_supp
where prospectstatus = 'Competitor Accreditation'
group by ssipmember;
select prospectstatus, sum(price) rev_lost, count(*) total
FROM stg2_renewing_customers_clean where prospectstatus_category <> 'Circumstantial'
AND prospectstatus <> 'Not Value for Money' AND prospectstatus <> 'Non Responsive' AND prospectoutcome = 'Lost'
group by prospectstatus
order by rev_lost desc;




select ssipmember, 
	count(*) as total,
	ROUND(count(*) * 100.0 / (SELECT COUNT(*) FROM rc_and_supp where prospectstatus = 'Competitor Accreditation'), 2) as pct_total
from rc_and_supp
where prospectstatus = 'Competitor Accreditation'
group by ssipmember;





select companytype, 
	count(*) as total,
	ROUND(count(*) * 100.0 / (SELECT COUNT(*) FROM rc_and_supp where prospectstatus = 'Competitor Accreditation'), 2) as pct_total
from rc_and_supp
where prospectstatus = 'Competitor Accreditation'
group by companytype;

select industrysector, 
	count(*) as total,
	ROUND(count(*) * 100.0 / (SELECT COUNT(*) FROM rc_and_supp where prospectstatus = 'Competitor Accreditation'), 2) as pct_total
from rc_and_supp
where prospectstatus = 'Competitor Accreditation'
group by industrysector
order by pct_total desc;



select companytype, 
	count(*) as total_company_type,
	count(*) FILTER (where prospectoutcome = 'Lost') as total_lost,
	round(count(*) FILTER (where prospectoutcome = 'Lost') * 100.0 / COUNT(*), 2)  as pct_total,
	round(count(*) FILTER (where prospectoutcome = 'Lost') * 100.0 / (select count(*) from rc_and_supp where prospectoutcome = 'Lost'), 2) as pct_total_lost
from rc_and_supp
group by companytype;


select industrysector, band,
	count(*) as total_company_type,
	count(*) FILTER (where prospectoutcome = 'Lost') as total_lost,
	round(count(*) FILTER (where prospectoutcome = 'Lost') * 100.0 / COUNT(*), 2)  as pct_total
	--count(*) FILTER (where prospectoutcome = 'Lost') * 100.0 / (select count(*) from rc_and_supp where prospectoutcome = 'Lost') as pct_total_
from rc_and_supp
group by industrysector, band
order by total_lost desc;


