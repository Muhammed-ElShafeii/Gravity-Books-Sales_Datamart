-- we are converting a transactional order history table (row-based events) into a single row per order.
-- CASE does NOT create columns by itself
-- The column is created by the SELECT clause
-- CASE only decides the value inside that column

CREATE OR ALTER VIEW vw_fact_order_history_staged AS
SELECT
    oh.order_id,
    co.customer_id,
    co.shipping_method_id,
	MAX(CASE WHEN oh.status_id = 1 THEN oh.history_id END) AS history_id,
    -- history_id of the Order Received status as the Business Key
	-- "From all the rows for this order, look only at the row where status_id = 1 (Order Received), and give me its history_id"
    MAX(CASE WHEN oh.status_id = 1 THEN oh.status_date END) AS order_received_date,
	-- MAX returns the only non-null value and gets the latest status 
    MAX(CASE WHEN oh.status_id = 2 THEN oh.status_date END) AS pending_delivery_date,
    MAX(CASE WHEN oh.status_id = 3 THEN oh.status_date END) AS in_progress_date,
    MAX(CASE WHEN oh.status_id = 4 THEN oh.status_date END) AS delivered_date,
    MAX(CASE WHEN oh.status_id = 5 THEN oh.status_date END) AS cancelled_date,
    MAX(CASE WHEN oh.status_id = 6 THEN oh.status_date END) AS returned_date,
    CASE MAX(oh.status_id)
        WHEN 1 THEN 'Order Received'
        WHEN 2 THEN 'Pending Delivery'
        WHEN 3 THEN 'Delivery In Progress'
        WHEN 4 THEN 'Delivered'
        WHEN 5 THEN 'Cancelled'
        WHEN 6 THEN 'Returned'
    END AS Current_Status,
    CASE WHEN MAX(CASE WHEN oh.status_id = 5 THEN 1 END) = 1 
         THEN 1 ELSE 0 
    END AS Is_Cancelled
FROM order_history oh
JOIN cust_order co ON oh.order_id = co.order_id
GROUP BY oh.order_id, co.customer_id, co.shipping_method_id;

select @@SERVERNAME