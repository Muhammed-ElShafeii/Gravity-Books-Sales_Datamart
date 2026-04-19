-- ============================================================
--  gravity_books — Order History Data Cleaning Script
--  Practice Project | Author: Mohamed El Shafei
--  Description: Full cleaning pipeline for order_history table
-- ============================================================
 
 
-- ============================================================
-- STEP 0: CREATE A BACKUP BEFORE ANY CHANGES
-- Always keep the original data safe before cleaning
-- ============================================================
 
SELECT *
INTO order_history_backup
FROM order_history;
 
 
-- ============================================================
-- STEP 1: CREATE A QUARANTINE TABLE
-- Bad records will be moved here instead of deleted,
-- so we have a full audit trail of what was removed and why
-- ============================================================
 
CREATE TABLE order_history_quarantine (
    history_id   INT,
    order_id     INT,
    status_id    INT,
    status_date  DATETIME,
    reject_reason VARCHAR(200),        -- why this row was rejected
    quarantine_date DATETIME DEFAULT GETDATE()
);
 
 
-- ============================================================
-- STEP 2: DIAGNOSTICS — Run these first to understand the data
-- These are READ-ONLY checks, they don't change anything
-- ============================================================
 
-- 2A: Count NULLs in every critical column
SELECT
    COUNT(CASE WHEN order_id    IS NULL THEN 1 END) AS null_order_id,
    COUNT(CASE WHEN status_id   IS NULL THEN 1 END) AS null_status_id,
    COUNT(CASE WHEN status_date IS NULL THEN 1 END) AS null_status_date,
    COUNT(*)                                         AS total_rows
FROM order_history;
 
-- 2B: Find orphaned records (order_id not in cust_order)
-- These are history rows that don't belong to any real order
SELECT oh.*
FROM order_history oh
LEFT JOIN cust_order co ON oh.order_id = co.order_id
WHERE co.order_id IS NULL;
 
-- 2C: Find invalid status_id (not defined in order_status table)
SELECT oh.*
FROM order_history oh
LEFT JOIN order_status os ON oh.status_id = os.status_id
WHERE os.status_id IS NULL;
 
-- 2D: Find temporal violations — status date is BEFORE the order was placed
-- Example found in data: order_id=3 has order_date=2025-12-14 but status_date=2020-12-14
SELECT
    oh.history_id,
    oh.order_id,
    co.order_date,
    oh.status_date,
    DATEDIFF(DAY, co.order_date, oh.status_date) AS day_diff
FROM order_history oh
JOIN cust_order co ON oh.order_id = co.order_id
WHERE oh.status_date < co.order_date;
 
-- 2E: Find future status dates (recorded after today — impossible)
SELECT *
FROM order_history
WHERE status_date > GETDATE();
 
-- 2F: Find duplicate rows (exact same order + status + date more than once)
SELECT order_id, status_id, status_date, COUNT(*) AS occurrences
FROM order_history
GROUP BY order_id, status_id, status_date
HAVING COUNT(*) > 1;
 
-- 2G: Find orders with no history record at all
SELECT co.order_id, co.order_date, co.customer_id
FROM cust_order co
LEFT JOIN order_history oh ON co.order_id = oh.order_id
WHERE oh.order_id IS NULL;
 
-- 2H: Find illogical status progression (status went backwards in time)
-- e.g. an order that was "Delivered" then recorded as "Order Received" again
WITH ranked_statuses AS (
    SELECT
        order_id,
        status_id,
        status_date,
        LAG(status_id)   OVER (PARTITION BY order_id ORDER BY status_date) AS prev_status_id,
        LAG(status_date) OVER (PARTITION BY order_id ORDER BY status_date) AS prev_status_date
    FROM order_history
)
SELECT *
FROM ranked_statuses
WHERE prev_status_id IS NOT NULL
  AND status_id < prev_status_id    -- current status is lower than previous = regression
  AND status_id NOT IN (5, 6);      -- exclude Cancelled and Returned (those are valid at any point)
 
-- 2I: Find orders that skipped statuses (jumped from Received → Delivered with no middle steps)
SELECT DISTINCT oh.order_id
FROM order_history oh
WHERE oh.status_id = 4              -- has a Delivered record
  AND oh.order_id NOT IN (SELECT order_id FROM order_history WHERE status_id = 2)  -- but no Pending Delivery
  AND oh.order_id NOT IN (SELECT order_id FROM order_history WHERE status_id = 3); -- and no Delivery In Progress
 
-- 2J: Find orders stuck at "Order Received" for more than 30 days with no further update
SELECT
    oh.order_id,
    oh.status_date                             AS received_date,
    DATEDIFF(DAY, oh.status_date, GETDATE())   AS days_stuck
FROM order_history oh
WHERE oh.status_id = 1
  AND oh.order_id NOT IN (
      SELECT order_id FROM order_history WHERE status_id > 1
  )
  AND DATEDIFF(DAY, oh.status_date, GETDATE()) > 30
ORDER BY days_stuck DESC;
 
-- 2K: Status distribution overview
SELECT
    os.status_value,
    COUNT(*)                                                    AS total_records,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2)          AS percentage
FROM order_history oh
JOIN order_status os ON oh.status_id = os.status_id
GROUP BY os.status_value
ORDER BY total_records DESC;
 
-- 2L: Funnel integrity check
-- Number of "Order Received" records should equal number of unique orders
SELECT
    COUNT(DISTINCT order_id)                                        AS total_unique_orders,
    COUNT(DISTINCT CASE WHEN status_id = 1 THEN order_id END)      AS orders_with_step1,
    COUNT(DISTINCT order_id)
        - COUNT(DISTINCT CASE WHEN status_id = 1 THEN order_id END) AS orders_missing_step1
FROM order_history;
 
 
-- ============================================================
-- STEP 3: QUARANTINE BAD RECORDS (move them out, don't delete)
-- Each INSERT below captures a specific type of bad record
-- with its reason labeled clearly
-- ============================================================
 
-- 3A: Quarantine rows with NULL in order_id, status_id, or status_date
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT history_id, order_id, status_id, status_date, 'NULL value in critical column'
FROM order_history
WHERE order_id IS NULL OR status_id IS NULL OR status_date IS NULL;
 
-- 3B: Quarantine orphaned records (no matching order in cust_order)
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT oh.history_id, oh.order_id, oh.status_id, oh.status_date, 'Orphaned: order_id not found in cust_order'
FROM order_history oh
LEFT JOIN cust_order co ON oh.order_id = co.order_id
WHERE co.order_id IS NULL
  AND oh.history_id NOT IN (SELECT history_id FROM order_history_quarantine); -- avoid double-inserting
 
-- 3C: Quarantine invalid status_id values
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT oh.history_id, oh.order_id, oh.status_id, oh.status_date, 'Invalid status_id: not in order_status table'
FROM order_history oh
LEFT JOIN order_status os ON oh.status_id = os.status_id
WHERE os.status_id IS NULL
  AND oh.history_id NOT IN (SELECT history_id FROM order_history_quarantine);
 
-- 3D: Quarantine temporal violations (status date before order date)
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT oh.history_id, oh.order_id, oh.status_id, oh.status_date,
       'Temporal violation: status_date (' + CONVERT(VARCHAR, oh.status_date, 120) +
       ') is before order_date (' + CONVERT(VARCHAR, co.order_date, 120) + ')'
FROM order_history oh
JOIN cust_order co ON oh.order_id = co.order_id
WHERE oh.status_date < co.order_date
  AND oh.history_id NOT IN (SELECT history_id FROM order_history_quarantine);
 
-- 3E: Quarantine future status dates
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT history_id, order_id, status_id, status_date, 'Future status_date: recorded beyond today'
FROM order_history
WHERE status_date > GETDATE()
  AND history_id NOT IN (SELECT history_id FROM order_history_quarantine);
 
-- 3F: Quarantine exact duplicate rows — keep only the first occurrence
INSERT INTO order_history_quarantine (history_id, order_id, status_id, status_date, reject_reason)
SELECT history_id, order_id, status_id, status_date, 'Duplicate row: same order_id + status_id + status_date'
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY order_id, status_id, status_date ORDER BY history_id) AS rn
    FROM order_history
) ranked
WHERE rn > 1  -- keep rn=1 (the first one), quarantine everything else
  AND history_id NOT IN (SELECT history_id FROM order_history_quarantine);
 
 
-- ============================================================
-- STEP 4: DELETE QUARANTINED ROWS FROM MAIN TABLE
-- Now that bad rows are safely stored in quarantine,
-- remove them from order_history
-- ============================================================
 
DELETE FROM order_history
WHERE history_id IN (SELECT history_id FROM order_history_quarantine);


