-- ============================================================
-- PHASE 5: DEEP SQL ANALYSIS
-- Marketplace Profit Leakage & Fulfillment Risk Intelligence
-- Run in MySQL Workbench, database: ecommerce_project
-- ============================================================
-- NOTE: If any column name below doesn't match your actual table
-- (check via DESCRIBE orders;), adjust the name — the query logic
-- stays the same.
-- ============================================================

USE ecommerce_project;


-- ============================================================
-- THEME 1: EXECUTIVE HEALTH — the numbers a manager sees first
-- ============================================================

-- Q1. Overall business health snapshot (finalized orders only)
SELECT
    COUNT(*)                                   AS finalized_orders,
    ROUND(SUM(total_price_usd), 2)             AS gross_revenue,
    ROUND(SUM(profit_usd), 2)                  AS reported_profit,
    ROUND(SUM(net_contribution), 2)            AS true_net_contribution,
    ROUND(SUM(profit_usd) - SUM(net_contribution), 2) AS leakage_amount,
    ROUND(100.0 * (SUM(profit_usd) - SUM(net_contribution)) / SUM(profit_usd), 2) AS leakage_pct,
    ROUND(AVG(total_price_usd), 2)             AS avg_order_value
FROM orders
WHERE is_finalized = 1;


-- Q2. Monthly revenue and net contribution trend (is leakage getting worse or better?)
SELECT
    DATE_FORMAT(order_date, '%Y-%m')           AS order_month,
    COUNT(*)                                    AS orders_count,
    ROUND(SUM(total_price_usd), 2)              AS gross_revenue,
    ROUND(SUM(net_contribution), 2)             AS net_contribution,
    ROUND(100.0 * (SUM(profit_usd) - SUM(net_contribution)) / NULLIF(SUM(profit_usd),0), 2) AS leakage_pct
FROM orders
WHERE is_finalized = 1
GROUP BY order_month
ORDER BY order_month;


-- Q3. Running cumulative net contribution over time (window function)
SELECT
    order_month,
    net_contribution,
    SUM(net_contribution) OVER (ORDER BY order_month) AS cumulative_net_contribution
FROM (
    SELECT
        DATE_FORMAT(order_date, '%Y-%m') AS order_month,
        SUM(net_contribution) AS net_contribution
    FROM orders
    WHERE is_finalized = 1
    GROUP BY order_month
) monthly;


-- ============================================================
-- THEME 2: PROFIT LEAKAGE DIAGNOSIS — where exactly is money lost
-- ============================================================

-- Q4. Leakage waterfall by category
SELECT
    category,
    ROUND(SUM(total_price_usd), 2)              AS gross_revenue,
    ROUND(SUM(discount_amount_usd), 2)          AS total_discount,
    ROUND(SUM(CASE WHEN is_returned = 1 THEN total_price_usd ELSE 0 END), 2) AS revenue_lost_to_returns,
    ROUND(SUM(shipping_cost_usd), 2)            AS total_shipping_cost,
    ROUND(SUM(net_contribution), 2)             AS net_contribution,
    ROUND(100.0 * (SUM(profit_usd) - SUM(net_contribution)) / NULLIF(SUM(profit_usd),0), 2) AS leakage_pct
FROM orders
WHERE is_finalized = 1
GROUP BY category
ORDER BY leakage_pct DESC;


-- Q5. Return cost breakdown by return_reason (which reasons cost the business most)
SELECT
    return_reason,
    COUNT(*)                                    AS return_count,
    ROUND(SUM(total_price_usd), 2)              AS revenue_lost,
    ROUND(SUM(shipping_cost_usd), 2)            AS shipping_cost_forfeited,
    ROUND(AVG(total_price_usd), 2)              AS avg_order_value_of_returns
FROM orders
WHERE is_returned = 1
GROUP BY return_reason
ORDER BY revenue_lost DESC;


-- Q6. False-positive top BRANDS: high revenue rank but poor net-contribution rank
WITH brand_stats AS (
    SELECT
        brand,
        ROUND(SUM(total_price_usd), 2) AS total_revenue,
        ROUND(SUM(net_contribution), 2) AS total_net_contribution,
        ROUND(AVG(is_returned), 4) AS return_rate,
        COUNT(*) AS order_count
    FROM orders
    WHERE is_finalized = 1
    GROUP BY brand
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY total_net_contribution DESC) AS net_contribution_rank
    FROM brand_stats
)
SELECT *,
    (net_contribution_rank - revenue_rank) AS rank_gap
FROM ranked
ORDER BY rank_gap DESC
LIMIT 10;


-- Q7. False-positive top CATEGORIES (same logic, category level)
WITH cat_stats AS (
    SELECT
        category,
        ROUND(SUM(total_price_usd), 2) AS total_revenue,
        ROUND(SUM(net_contribution), 2) AS total_net_contribution
    FROM orders
    WHERE is_finalized = 1
    GROUP BY category
),
ranked AS (
    SELECT *,
        RANK() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        RANK() OVER (ORDER BY total_net_contribution DESC) AS net_contribution_rank
    FROM cat_stats
)
SELECT *, (net_contribution_rank - revenue_rank) AS rank_gap
FROM ranked
ORDER BY rank_gap DESC;


-- Q8. Discount cannibalization: does discounting actually grow net contribution, or just erode it?
SELECT
    CASE
        WHEN discount_percent = 0 THEN '0% (no discount)'
        WHEN discount_percent BETWEEN 0.01 AND 10 THEN '1-10%'
        WHEN discount_percent BETWEEN 10.01 AND 20 THEN '10-20%'
        ELSE '20%+'
    END AS discount_band,
    COUNT(*) AS order_count,
    ROUND(AVG(total_price_usd), 2) AS avg_order_value,
    ROUND(SUM(net_contribution), 2) AS total_net_contribution,
    ROUND(AVG(is_returned), 4) AS return_rate
FROM orders
WHERE is_finalized = 1
GROUP BY discount_band
ORDER BY discount_band;


-- ============================================================
-- THEME 3: CUSTOMER VALUE — who actually drives profit
-- ============================================================

-- Q9. RFM segmentation with window functions
WITH customer_rfm AS (
    SELECT
        customer_id,
        DATEDIFF((SELECT MAX(order_date) FROM orders), MAX(order_date)) AS recency_days,
        COUNT(DISTINCT order_id) AS frequency,
        SUM(total_price_usd) AS monetary
    FROM orders
    WHERE is_finalized = 1
    GROUP BY customer_id
),
scored AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC)      AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)       AS m_score
    FROM customer_rfm
)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'At Risk'
        ELSE 'Needs Attention'
    END AS segment
FROM scored;


-- Q10. Profitability by existing customer_segment column (validate the business's own labels)
SELECT
    customer_segment,
    COUNT(DISTINCT customer_id)                 AS customers,
    ROUND(SUM(net_contribution), 2)             AS total_net_contribution,
    ROUND(AVG(net_contribution), 2)             AS avg_net_contribution_per_order,
    ROUND(AVG(is_returned), 4)                  AS return_rate
FROM orders
WHERE is_finalized = 1
GROUP BY customer_segment
ORDER BY total_net_contribution DESC;


-- Q11. Net-negative "loyal-looking" customers — many orders, but losing the business money
SELECT
    customer_id,
    COUNT(*)                                     AS total_orders,
    ROUND(SUM(net_contribution), 2)              AS total_net_contribution,
    ROUND(AVG(is_returned), 4)                   AS return_rate
FROM orders
WHERE is_finalized = 1
GROUP BY customer_id
HAVING total_orders >= 5 AND total_net_contribution < 0
ORDER BY total_net_contribution ASC
LIMIT 20;


-- Q12. Monthly cohort retention matrix
WITH cohorts AS (
    SELECT
        customer_id,
        DATE_FORMAT(order_date, '%Y-%m-01') AS order_month,
        MIN(DATE_FORMAT(order_date, '%Y-%m-01')) OVER (PARTITION BY customer_id) AS cohort_month
    FROM orders
    WHERE is_finalized = 1
)
SELECT
    cohort_month,
    order_month,
    TIMESTAMPDIFF(MONTH, cohort_month, order_month) AS month_number,
    COUNT(DISTINCT customer_id) AS active_customers
FROM cohorts
GROUP BY cohort_month, order_month
ORDER BY cohort_month, month_number;


-- ============================================================
-- THEME 4: FULFILLMENT & DELIVERY RISK
-- ============================================================

-- Q13. Delivery SLA performance by shipping method
SELECT
    shipping_method,
    COUNT(*)                                     AS order_count,
    ROUND(AVG(delivery_days), 2)                 AS avg_delivery_days,
    ROUND(AVG(promised_days), 2)                 AS promised_days,
    ROUND(100.0 * AVG(is_late), 2)                AS pct_late,
    ROUND(AVG(delivery_delay_days), 2)            AS avg_delay_days_when_late
FROM orders
WHERE is_finalized = 1
GROUP BY shipping_method
ORDER BY pct_late DESC;


-- Q14. Does a late delivery increase the odds of a return?
SELECT
    is_late,
    COUNT(*)                                     AS order_count,
    ROUND(100.0 * AVG(is_returned), 2)            AS return_rate_pct
FROM orders
WHERE is_finalized = 1
GROUP BY is_late;


-- Q15. Warehouse / shipping country performance (geography-level fulfillment risk)
SELECT
    warehouse_location,
    COUNT(*)                                     AS order_count,
    ROUND(AVG(delivery_days), 2)                 AS avg_delivery_days,
    ROUND(100.0 * AVG(is_late), 2)                AS pct_late,
    ROUND(SUM(net_contribution), 2)               AS net_contribution
FROM orders
WHERE is_finalized = 1
GROUP BY warehouse_location
ORDER BY pct_late DESC;


-- ============================================================
-- THEME 5: RISK & FRAUD SIGNALS
-- ============================================================

-- Q16. Does fraud_risk_score actually correlate with cancellations/returns?
SELECT
    CASE
        WHEN fraud_risk_score < 0.3 THEN 'Low (0-0.3)'
        WHEN fraud_risk_score < 0.6 THEN 'Medium (0.3-0.6)'
        ELSE 'High (0.6+)'
    END AS fraud_risk_band,
    COUNT(*)                                     AS order_count,
    ROUND(100.0 * AVG(is_cancelled), 2)           AS cancellation_rate_pct,
    ROUND(100.0 * AVG(is_returned), 2)            AS return_rate_pct
FROM orders
GROUP BY fraud_risk_band
ORDER BY fraud_risk_band;


-- Q17. Payment method risk (which methods have the highest failure/return pairing)
SELECT
    payment_method,
    COUNT(*)                                     AS order_count,
    ROUND(100.0 * AVG(is_returned), 2)            AS return_rate_pct,
    ROUND(SUM(net_contribution), 2)               AS net_contribution
FROM orders
WHERE is_finalized = 1
GROUP BY payment_method
ORDER BY return_rate_pct DESC;


-- ============================================================
-- THEME 6: MARKETING & ACQUISITION EFFICIENCY
-- ============================================================

-- Q18. Which acquisition channel brings genuinely profitable customers (not just volume)?
SELECT
    traffic_source,
    COUNT(*)                                      AS order_count,
    ROUND(SUM(total_price_usd), 2)                AS gross_revenue,
    ROUND(SUM(net_contribution), 2)                AS net_contribution,
    ROUND(100.0 * AVG(is_returned), 2)             AS return_rate_pct
FROM orders
WHERE is_finalized = 1
GROUP BY traffic_source
ORDER BY net_contribution DESC;
