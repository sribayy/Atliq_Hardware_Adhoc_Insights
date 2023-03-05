USE gdb023;

-- 1. List of markets where customer "Atliq Exclusive" operates in "APAC" Region
SELECT DISTINCT market 
FROM dim_customer 
WHERE customer = 'Atliq Exclusive' AND Region = 'APAC';

-- 2. percentage of unique product increase in 2021 vs 2022
WITH unique_products_2020 AS(
	SELECT COUNT(DISTINCT product_code) AS unique_products_2020
	FROM fact_sales_monthly
	WHERE fiscal_year = 2020),
unique_products_2021 AS(
	SELECT COUNT(DISTINCT product_code) AS unique_products_2021
	FROM fact_sales_monthly
	WHERE fiscal_year = 2021)
SELECT unique_products_2020, unique_products_2021, round((unique_products_2021 - unique_products_2020)/unique_products_2020 * 100, 2) AS percentage_chg
	FROM unique_products_2020, unique_products_2021;

-- 3. Unique product counts for each segment and sort them in descending order of product counts
SELECT segment, COUNT(DISTINCT product_code) AS "product_count" 
FROM dim_product 
GROUP BY segment 
ORDER BY product_count DESC;

-- 4. segment that had the most increase in unique products in 2021 vs 2020
WITH merged_table AS(
	SELECT dim_product.segment, fact_sales_monthly.product_code, fact_sales_monthly.fiscal_year
    FROM dim_product JOIN fact_sales_monthly
	ON dim_product.product_code=fact_sales_monthly.product_code),
distinct_product_count AS(
SELECT segment,fiscal_year,COUNT(DISTINCT product_code) AS product_count 
	FROM merged_table GROUP BY segment, fiscal_year),
product_counts_by_year AS(
SELECT segment, 
		SUM(CASE WHEN fiscal_year = 2020 THEN product_count ELSE 0 END) AS product_count_2020, 
		SUM(CASE WHEN fiscal_year = 2021 THEN product_count ELSE 0 END) as product_count_2021
	FROM distinct_product_count GROUP BY segment)
SELECT segment, product_count_2020, product_count_2021, product_count_2021 - product_count_2020 AS difference FROM product_counts_by_year;

-- 5. products that have the highest and lowest manufacturing costs
SELECT fact_manufacturing_cost.product_code,
		dim_product.product, 
		fact_manufacturing_cost.manufacturing_cost 
FROM fact_manufacturing_cost 
JOIN dim_product 
	ON fact_manufacturing_cost.product_code=dim_product.product_code
WHERE fact_manufacturing_cost.manufacturing_cost = (
		SELECT MIN(manufacturing_cost) FROM fact_manufacturing_cost) OR
	fact_manufacturing_cost.manufacturing_cost = (
		SELECT MAX(manufacturing_cost) FROM fact_manufacturing_cost);

-- 6. top 5 customers who received an average high pre_invoice_discount_pct for the fiscal year 2021 in the Indian market
SELECT fact_pre_invoice_deductions.customer_code, 
		dim_customer.customer, 
		AVG(fact_pre_invoice_deductions.pre_invoice_discount_pct) AS avg_discount 
FROM fact_pre_invoice_deductions  
JOIN dim_customer 
	ON fact_pre_invoice_deductions.customer_code=dim_customer.customer_code
WHERE fact_pre_invoice_deductions.fiscal_year = 2021 AND dim_customer.sub_zone = 'India'
GROUP BY fact_pre_invoice_deductions.customer_code, dim_customer.customer 
ORDER BY avg_discount DESC LIMIT 5;

-- 7. Gross sales amount for the customer “Atliq Exclusive” for each month

SELECT EXTRACT(YEAR FROM fact_sales_monthly.date) AS year, 
		EXTRACT(MONTH FROM fact_sales_monthly.date) AS month, 
        ROUND(SUM(fact_gross_price.gross_price * fact_sales_monthly.sold_quantity),2) AS gross_sales_amount 
FROM fact_sales_monthly 
JOIN fact_gross_price 
	ON fact_gross_price.product_code = fact_sales_monthly.product_code
JOIN dim_customer 
	ON dim_customer.customer_code = fact_sales_monthly.customer_code 
WHERE dim_customer.customer = "Atliq Exclusive" 
GROUP BY month, year 
ORDER BY year, month;

--  8. maximum total_sold_quantity by Quarter in 2020
    
SELECT SUM(sold_quantity) AS Total_Sold_Quantity,
    CASE
        WHEN MONTH(date) BETWEEN 3  AND 5  THEN 'Q3'
        WHEN MONTH(date) BETWEEN 6  AND 8  THEN 'Q4'
        WHEN MONTH(date) BETWEEN 9  AND 11  THEN 'Q1'
        WHEN MONTH(date) BETWEEN 1 AND 2 OR 12 THEN 'Q2'
    END AS Quarter
FROM
    fact_sales_monthly
WHERE YEAR(date) = 2020
GROUP BY Quarter
ORDER BY Total_Sold_Quantity DESC;
-- LIMIT 1;

-- 9. channel that helped to bring more gross sales in the fiscal year 2021 and the percentage of contribution

WITH channel_gross_sales AS(
	SELECT dim_customer.channel AS channel, SUM(fact_sales_monthly.sold_quantity * fact_gross_price.gross_price) AS gross_sales_mln 
	FROM fact_sales_monthly
	JOIN fact_gross_price
		ON fact_sales_monthly.product_code = fact_gross_price.product_code 
	JOIN dim_customer
		ON fact_sales_monthly.customer_code = dim_customer.customer_code
	WHERE fact_sales_monthly.fiscal_year=2021
	GROUP BY dim_customer.channel
	)
SELECT channel, gross_sales_mln, ROUND(gross_sales_mln*100/(SELECT SUM(gross_sales_mln) FROM channel_gross_sales),2) AS percentage 
	FROM channel_gross_sales
	GROUP BY channel, gross_sales_mln 
	ORDER BY gross_sales_mln DESC;


-- 10. Top 3 products in each division that have a high total_sold_quantity in the fiscal_year 2021

WITH rank_sales AS(
	SELECT dim_product.division as division, 
			dim_product.product_code as product_code, 
            dim_product.product as product, 
            sum(fact_sales_monthly.sold_quantity) as sold_quantity, 
	DENSE_RANK() OVER (PARTITION BY division ORDER BY sold_quantity DESC) AS rank_order
		FROM dim_product
		JOIN fact_sales_monthly
			ON dim_product.product_code=fact_sales_monthly.product_code 
		WHERE fact_sales_monthly.fiscal_year = 2021
		GROUP BY division, product_code, product, sold_quantity
)
SELECT division, product_code, product, sold_quantity, rank_order
FROM rank_sales 
WHERE rank_order<=3;
