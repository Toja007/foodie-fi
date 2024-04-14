--How many customers has Foodie-Fi ever had?
WITH t2 AS (SELECT DISTINCT(customer_id)
			FROM subscriptions)
SELECT COUNT(*)
FROM t2


--What is the monthly distribution of trial plan start_date values for our dataset - use the start of the month as the group by value
SELECT DATE_TRUNC('MONTH', subscriptions.start_date) AS month_start,
       plans.plan_name,
       COUNT(plans.plan_name) AS plan_count
FROM plans
JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
GROUP BY month_start, plans.plan_name
ORDER BY month_start, plans.plan_name;


--What plan start_date values occur after the year 2020 for our dataset? Show the breakdown by count of events for each plan_name
SELECT subscriptions.start_date, plans.plan_name, COUNT(*)
FROM subscriptions
JOIN plans ON subscriptions.plan_id = plans.plan_id
WHERE subscriptions.start_date > '2020-12-31'
GROUP BY subscriptions.start_date, plans.plan_name
ORDER BY subscriptions.start_date, plans.plan_name;


--What is the customer count and percentage of customers who have churned rounded to 1 decimal place?
 WITH t2 AS (SELECT count(subscriptions.customer_id) AS churn_count
FROM  subscriptions
JOIN PLANS
ON subscriptions.plan_id = plans.plan_id
WHERE plans.plan_name = 'churn'),


t3 AS (SELECT count(subscriptions.customer_id) AS total_count
FROM  subscriptions
JOIN PLANS
ON subscriptions.plan_id = plans.plan_id)

SELECT t2.churn_count, ROUND(CAST((t2.churn_count::FLOAT / (SELECT t3.total_count::FLOAT FROM t3)) * 100 AS NUMERIC), 1) AS churn_percentage
FROM t2;

--How many customers have churned straight after their initial free trial
WITH t2 AS (SELECT subscriptions.customer_id AS cus, subscriptions.start_date AS trial_date
			FROM plans
			JOIN subscriptions
			ON plans.plan_id = subscriptions.plan_id
			WHERE plan_name = 'trial')
,
t3 AS (SELECT subscriptions.customer_id AS custom, subscriptions.start_date AS churn_date
		FROM plans
		JOIN subscriptions
		ON plans.plan_id = subscriptions.plan_id
		WHERE plan_name = 'churn')
,
t4 AS (SELECT count(*)
		FROM t2
		JOIN t3
		ON  t2.cus = t3.custom
		GROUP BY t2.cus, t3.custom, t2.trial_date, t3.churn_date
		HAVING t3.churn_date - t2.trial_date =7)

SELECT COUNT(*) AS number_of_churn_after_trial
FROM t4;


--What is the number and percentage of customer plans after their initial free trial?
WITH t2 AS (SELECT subscriptions.customer_id AS cus, subscriptions.start_date AS trial_date
            FROM plans
            JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
            WHERE plans.plan_name = 'trial'
            GROUP BY 2, 1)
, 
t3 AS (SELECT plans.plan_name, COUNT(subscriptions.customer_id) AS plan_count_after_trial
        FROM plans
        JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
        JOIN t2 ON t2.cus = subscriptions.customer_id
        WHERE subscriptions.start_date - t2.trial_date >= 7
        GROUP BY plans.plan_name)

SELECT t3.plan_name, t3.plan_count_after_trial, 
       ROUND((CAST(t3.plan_count_after_trial AS FLOAT) / 
             (SELECT COUNT(*) FROM subscriptions)) * 100) AS percentage_after_trial
FROM t3;

--What is the customer count and percentage breakdown of all 5 plan_name values at 2020-12-31?
WITH t2 AS (SELECT plans.plan_name, COUNT(subscriptions.customer_id) AS customer_count
						FROM plans
						JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
						WHERE subscriptions.start_date <= '2020-12-31'
						GROUP BY plans.plan_name)

SELECT plan_name, customer_count,
       ROUND((CAST(customer_count AS FLOAT) / (SELECT SUM(customer_count) FROM t2)) * 100) AS percentage
FROM t2;

--How many customers have upgraded to an annual plan in 2020?
SELECT COUNT(DISTINCT subscriptions.customer_id) AS num_customers_upgraded
FROM plans
JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
WHERE plans.plan_name = 'pro annual' AND EXTRACT(YEAR FROM subscriptions.start_date) = 2020;


--How many days on average does it take for a customer to an annual plan from the day they join Foodie-Fi?
WITH upgrade_dates AS (
    SELECT customer_id, MIN(start_date) AS join_date
    FROM subscriptions
    GROUP BY customer_id
),
upgrade_times AS (
    SELECT u.customer_id, u.join_date, MIN(s.start_date) AS upgrade_date
    FROM upgrade_dates u
    JOIN subscriptions s ON u.customer_id = s.customer_id
    JOIN plans p ON s.plan_id = p.plan_id
    WHERE p.plan_name = 'pro annual'  
    GROUP BY u.customer_id, u.join_date
)
SELECT AVG(upgrade_times.upgrade_date - upgrade_times.join_date)
FROM upgrade_times;

--Can you further breakdown this average value into 30 day periods (i.e. 0-30 days, 31-60 days etc)
WITH upgrade_dates AS (SELECT customer_id, MIN(start_date) AS join_date
    					FROM subscriptions
    					GROUP BY customer_id
),
upgrade_times AS (SELECT u.customer_id, u.join_date, MIN(s.start_date) AS upgrade_date
					FROM upgrade_dates u
					JOIN subscriptions s ON u.customer_id = s.customer_id
					JOIN plans p ON s.plan_id = p.plan_id
					WHERE p.plan_name = 'pro annual'
					GROUP BY u.customer_id, u.join_date),
days_to_upgrade AS (SELECT customer_id, upgrade_date - join_date AS days_to_upgrade
    				FROM upgrade_times)
SELECT 
    CASE 
        WHEN days_to_upgrade BETWEEN 0 AND 30 THEN '0-30 days'
        WHEN days_to_upgrade BETWEEN 31 AND 60 THEN '31-60 days'
        WHEN days_to_upgrade BETWEEN 61 AND 90 THEN '61-90 days'
        ELSE 'More than 90 days'
    END AS period,
    COUNT(*) AS count_in_period
FROM days_to_upgrade
GROUP BY period
ORDER BY MIN(days_to_upgrade);


--How many customers downgraded from a pro monthly to a basic monthly plan in 2020?
WITH pro_cus AS (SELECT subscriptions.customer_id as cus, start_date AS pro_date
					FROM plans
					JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
					WHERE plans.plan_name = 'pro monthly' AND EXTRACT(YEAR FROM start_date) = 2020),

basic_cus AS (SELECT subscriptions.customer_id as cuss, start_date AS basic_date
				FROM plans
				JOIN subscriptions ON plans.plan_id = subscriptions.plan_id
				WHERE plans.plan_name = 'basic monthly' AND EXTRACT(YEAR FROM start_date) = 2020)

SELECT COUNT(*)
FROM pro_cus
JOIN basic_cus
ON pro_cus.cus = basic_cus.cuss
WHERE pro_cus.pro_date < basic_cus. basic_date;



--The Foodie-Fi team wants you to create a new payments table for the year 2020 that includes amounts paid by each customer in the subscriptions table with the following requirements:
--monthly payments always occur on the same day of month as the original start_date of any monthly paid plan
--upgrades from basic to monthly or pro plans are reduced by the current paid amount in that month and start immediately
--upgrades from pro monthly to pro annual are paid at the end of the current billing period and also starts at the end of the month period
--once a customer churns they will no longer make payments

CREATE TABLE payments_2020 AS
SELECT s.customer_id, p.plan_id, p.plan_name, s.start_date, p.price AS monthly_amount,
		RANK() OVER (PARTITION BY s.customer_id ORDER BY s.start_date) payment_order
FROM subscriptions s
JOIN plans p ON s.plan_id = p.plan_id
WHERE s.start_date <= '2020-12-31';




