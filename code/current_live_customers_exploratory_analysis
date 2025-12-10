/*
===================================================================================================

CURRENT LIVE CUSTOMERS BRIEF EDA

- Rest was explored in Power BI

===================================================================================================
*/



-- Annual Suscription Revenue contribution from parents and their subsidiaries:
SELECT SUM(annual_revenue_contributed)
FROM
	(SELECT coref, price + (noofsubsidiaries * 100) AS annual_revenue_contributed
	FROM stg2_current_live_customers_dedup
	WHERE subsidiarytype = 'Parent'
	ORDER BY noofsubsidiaries DESC);



-- Looking at Tenure:
WITH tenure_pctiles AS (SELECT coref, noofanchorings, tenure,
							NTILE(10) OVER(ORDER BY tenure DESC) AS tenure_pctile_group
						FROM stg2_current_live_customers_dedup)
SELECT tenure_pctile_group,
	ROUND(AVG(tenure), 3) AS avg_tenure,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY tenure) AS median_tenure,
	ROUND(AVG(noofanchorings), 3) AS avg_anchorings,
	PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY noofanchorings) AS median_no_anchorings
FROM tenure_pctiles
GROUP BY tenure_pctile_group;

-- Those with longer tenures also appear to have a larger number of average and median anchorings (which I assume means number of clients requiring Safecontractor
-- accreditation)

-- SafeContactor is Incentivised to get Contractors accredited and help them find work, this embeds the client into SafeContractor's 
-- system, to the point where their contracts depend on it

-- Moral of the story: More anchorings --> Longer tenures




------------------------------------------CLV-----------------------------------------------------
-- Top Corefs by CLV (ignoring employee growth over time):

WITH 
-- Calculate individual CLV for each customer (including subsidiaries):
individual_clv AS (
    SELECT 
        coref,
        subsidiarytype,
        holdingcoref,
        price,
        tenure,
        (price * tenure) AS individual_lifetime_value
    FROM stg2_current_live_customers_dedup
),

-- Calculate total subsidiary LTV for each parent company:
subsidiary_clv_rollup AS (
    SELECT 
        holdingcoref AS parent_coref,
        COUNT(*) AS number_of_subsidiaries,
        SUM(individual_lifetime_value) AS total_subsidiary_clv
    FROM individual_clv
    WHERE subsidiarytype = 'Subsidiary'
        AND holdingcoref IS NOT NULL
        AND holdingcoref <> '' -- or !=
    GROUP BY holdingcoref
),

-- Combine parent CLV with subsidiary CLV:
final_clv AS (
    SELECT 
        i.coref,
        i.subsidiarytype,
        i.holdingcoref,
        i.price,
        i.tenure,
        i.individual_lifetime_value,
        
        -- For parents --> add subsidiary CLV
        CASE 
            WHEN i.subsidiarytype = 'Parent' THEN 
                i.individual_lifetime_value + COALESCE(s.total_subsidiary_clv, 0)
            ELSE 
                i.individual_lifetime_value
        END AS total_customer_lifetime_value,
        
        -- Additional metrics
        CASE 
            WHEN i.subsidiarytype = 'Parent' THEN COALESCE(s.number_of_subsidiaries, 0)
            ELSE 0
        END AS number_of_subsidiaries,
        
        CASE 
            WHEN i.subsidiarytype = 'Parent' THEN COALESCE(s.total_subsidiary_clv, 0)
            ELSE 0
        END AS subsidiary_contribution_to_clv
        
    FROM individual_clv i
    LEFT JOIN subsidiary_clv_rollup s ON i.coref = s.parent_coref
)
SELECT 
    coref,
    subsidiarytype,
    holdingcoref,
    price AS annual_price,
    tenure AS tenure_years,
    individual_lifetime_value,
    total_customer_lifetime_value,
    number_of_subsidiaries,
    subsidiary_contribution_to_clv,
    
    -- Calculate % of CLV from subsidiaries (for parents only)
    CASE 
        WHEN total_customer_lifetime_value > 0 THEN 
            ROUND(100.0 * subsidiary_contribution_to_clv / total_customer_lifetime_value, 2)
        ELSE 0
    END AS pct_clv_from_subsidiaries

FROM final_clv
ORDER BY total_customer_lifetime_value DESC;

------------------------------------------------------------------------------------------------------------------------

-- IMPORTANT NOTE: This indicates what (to me) is a good sign about SafeContractor's Business model. The top CLTV of 34K
-- is a mere fraction of annual subscription revenue, meaning SafeContractor's business model thrives on volume and 
-- does not depend on a few large clients for success. What's more important is customer acquisition and retention, both
-- for contractors as well as hiring clients.





