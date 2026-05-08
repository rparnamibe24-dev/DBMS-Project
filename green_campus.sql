

DROP TRIGGER IF EXISTS trg_overconsumption_alert;
DROP TRIGGER IF EXISTS trg_auto_maintenance_flag;
DROP TRIGGER IF EXISTS trg_log_status_change;

DROP PROCEDURE IF EXISTS sp_monthly_report;
DROP PROCEDURE IF EXISTS sp_building_summary;
DROP PROCEDURE IF EXISTS sp_resolve_alerts;
DROP PROCEDURE IF EXISTS sp_cursor_all_overconsumption;

DROP FUNCTION IF EXISTS fn_carbon_footprint;
DROP FUNCTION IF EXISTS fn_total_consumption;
DROP FUNCTION IF EXISTS fn_alert_count;

DROP VIEW IF EXISTS vw_consumption_detail;
DROP VIEW IF EXISTS vw_alert_summary;
DROP VIEW IF EXISTS vw_pending_maintenance;

DROP TABLE IF EXISTS Audit_Log;
DROP TABLE IF EXISTS Sustainability_Alert;
DROP TABLE IF EXISTS Maintenance_Request;
DROP TABLE IF EXISTS Consumption_Record;
DROP TABLE IF EXISTS Resource;
DROP TABLE IF EXISTS Building;

CREATE TABLE Building (
Building_ID INT PRIMARY KEY AUTO_INCREMENT,
Building_Name VARCHAR(100) NOT NULL,
Building_Type VARCHAR(50) NOT NULL,
Location VARCHAR(100),
Capacity INT CHECK (Capacity > 0),
Established_Year YEAR,
CONSTRAINT chk_building_type
CHECK (Building_Type IN ('Academic','Hostel','Library','Administrative','Laboratory'))
);

CREATE TABLE Resource (
Resource_ID INT PRIMARY KEY AUTO_INCREMENT,
Resource_Name VARCHAR(50) NOT NULL UNIQUE,
Unit VARCHAR(20) NOT NULL,
Threshold_Limit DECIMAL(10,2) NOT NULL DEFAULT 1000.00,
Cost_Per_Unit DECIMAL(8,4) NOT NULL DEFAULT 0.00
);

CREATE TABLE Consumption_Record (
Record_ID INT PRIMARY KEY AUTO_INCREMENT,
Building_ID INT NOT NULL,
Resource_ID INT NOT NULL,
Consumption_Amount DECIMAL(10,2) NOT NULL CHECK (Consumption_Amount >= 0),
Record_Date DATE NOT NULL,
Recorded_By VARCHAR(50) DEFAULT 'Admin',
CONSTRAINT fk_cr_building FOREIGN KEY (Building_ID) REFERENCES Building(Building_ID) ON DELETE CASCADE,
CONSTRAINT fk_cr_resource FOREIGN KEY (Resource_ID) REFERENCES Resource(Resource_ID) ON DELETE RESTRICT,
CONSTRAINT uq_daily_record UNIQUE (Building_ID, Resource_ID, Record_Date)
);

CREATE TABLE Maintenance_Request (
Request_ID INT PRIMARY KEY AUTO_INCREMENT,
Building_ID INT NOT NULL,
Issue_Description VARCHAR(500) NOT NULL,
Status VARCHAR(20) NOT NULL DEFAULT 'Pending',
Priority VARCHAR(10) DEFAULT 'Medium',
Request_Date DATE NOT NULL,
Resolved_Date DATE,
CONSTRAINT fk_mr_building FOREIGN KEY (Building_ID) REFERENCES Building(Building_ID) ON DELETE CASCADE,
CONSTRAINT chk_status CHECK (Status IN ('Pending','In Progress','Resolved')),
CONSTRAINT chk_priority CHECK (Priority IN ('Low','Medium','High'))
);

CREATE TABLE Sustainability_Alert (
Alert_ID INT PRIMARY KEY AUTO_INCREMENT,
Building_ID INT NOT NULL,
Resource_ID INT NOT NULL,
Record_ID INT,
Alert_Message VARCHAR(300) NOT NULL,
Alert_Date DATE NOT NULL,
Severity VARCHAR(10) DEFAULT 'High',
Acknowledged TINYINT(1) DEFAULT 0,
CONSTRAINT fk_sa_building FOREIGN KEY (Building_ID) REFERENCES Building(Building_ID) ON DELETE CASCADE,
CONSTRAINT fk_sa_resource FOREIGN KEY (Resource_ID) REFERENCES Resource(Resource_ID) ON DELETE RESTRICT,
CONSTRAINT fk_sa_record FOREIGN KEY (Record_ID) REFERENCES Consumption_Record(Record_ID) ON DELETE SET NULL
);

CREATE TABLE Audit_Log (
Log_ID INT PRIMARY KEY AUTO_INCREMENT,
Table_Name VARCHAR(50) NOT NULL,
Operation VARCHAR(10) NOT NULL,
Record_Ref_ID INT,
Changed_By VARCHAR(50) DEFAULT 'Admin',
Changed_At DATETIME DEFAULT CURRENT_TIMESTAMP,
Details VARCHAR(500)
);

INSERT INTO Building (Building_Name, Building_Type, Location, Capacity, Established_Year) VALUES
('Academic Block A', 'Academic', 'North Campus', 500, 2005),
('Hostel Block B', 'Hostel', 'East Campus', 300, 2008),
('Central Library', 'Library', 'Main Campus', 200, 2003),
('Admin Office', 'Administrative', 'Main Campus', 100, 2001),
('Science Lab', 'Laboratory', 'South Campus', 150, 2010),
('Academic Block C', 'Academic', 'West Campus', 450, 2015),
('Hostel Block D', 'Hostel', 'West Campus', 350, 2018);

INSERT INTO Resource (Resource_Name, Unit, Threshold_Limit, Cost_Per_Unit) VALUES
('Electricity', 'kWh', 1000.00, 7.5000),
('Water', 'Litres', 1000.00, 0.0300),
('Waste', 'kg', 500.00, 2.0000);

INSERT INTO Consumption_Record (Building_ID, Resource_ID, Consumption_Amount, Record_Date) VALUES
(1, 1, 1200.00, '2025-01-10'), -- Over threshold → will trigger alert
(2, 2, 850.00, '2025-01-10'),
(3, 1, 430.00, '2025-01-11'),
(1, 3, 95.00, '2025-01-12'),
(4, 1, 1500.00, '2025-02-05'), -- Over threshold
(5, 2, 1100.00, '2025-02-06'), -- Over threshold
(2, 1, 780.00, '2025-02-10'),
(3, 3, 45.00, '2025-03-01'),
(4, 2, 650.00, '2025-03-05'),
(5, 1, 990.00, '2025-03-08'),
(6, 1, 870.00, '2025-03-10'),
(7, 2, 540.00, '2025-03-11'),
(1, 2, 920.00, '2025-04-01'),
(6, 2, 1050.00, '2025-04-03'), -- Over threshold
(7, 1, 430.00, '2025-04-05');

INSERT INTO Maintenance_Request (Building_ID, Issue_Description, Status, Priority, Request_Date) VALUES
(1, 'AC unit leaking — high electricity draw', 'Pending', 'High', '2025-01-15'),
(3, 'Water pipe dripping in east wing', 'Resolved', 'Medium', '2025-02-20'),
(5, 'Old pumps causing excess water consumption', 'In Progress', 'High', '2025-03-02'),
(4, 'Fluorescent lights not auto-switching off', 'Pending', 'Low', '2025-03-18'),
(2, 'Broken taps causing constant water flow', 'Pending', 'High', '2025-04-01');

CREATE VIEW vw_consumption_detail AS
SELECT
cr.Record_ID,
b.Building_Name,
b.Building_Type,
r.Resource_Name,
r.Unit,
cr.Consumption_Amount,
r.Threshold_Limit,
CASE WHEN cr.Consumption_Amount > r.Threshold_Limit THEN 'OVER' ELSE 'Normal' END AS Status,
cr.Record_Date
FROM Consumption_Record cr
JOIN Building b ON cr.Building_ID = b.Building_ID
JOIN Resource r ON cr.Resource_ID = r.Resource_ID;

CREATE VIEW vw_alert_summary AS
SELECT
sa.Alert_ID,
b.Building_Name,
r.Resource_Name,
sa.Alert_Message,
sa.Severity,
sa.Alert_Date,
IF(sa.Acknowledged, 'Yes', 'No') AS Acknowledged
FROM Sustainability_Alert sa
JOIN Building b ON sa.Building_ID = b.Building_ID
JOIN Resource r ON sa.Resource_ID = r.Resource_ID;

CREATE VIEW vw_pending_maintenance AS
SELECT
mr.Request_ID,
b.Building_Name,
mr.Issue_Description,
mr.Status,
mr.Priority,
mr.Request_Date,
DATEDIFF(CURRENT_DATE, mr.Request_Date) AS Days_Open
FROM Maintenance_Request mr
JOIN Building b ON mr.Building_ID = b.Building_ID
WHERE mr.Status != 'Resolved'
ORDER BY FIELD(mr.Priority,'High','Medium','Low'), mr.Request_Date;

DELIMITER $$

CREATE TRIGGER trg_overconsumption_alert
AFTER INSERT ON Consumption_Record
FOR EACH ROW
BEGIN
DECLARE v_threshold DECIMAL(10,2);
DECLARE v_resource VARCHAR(50);
DECLARE v_building VARCHAR(100);
DECLARE v_msg VARCHAR(300);

SELECT Threshold_Limit, Resource_Name
INTO v_threshold, v_resource
FROM Resource
WHERE Resource_ID = NEW.Resource_ID;

SELECT Building_Name
INTO v_building
FROM Building
WHERE Building_ID = NEW.Building_ID;

IF NEW.Consumption_Amount > v_threshold THEN
SET v_msg = CONCAT(
v_resource, ' overconsumption detected in ', v_building,
'. Recorded: ', NEW.Consumption_Amount,
' ', (SELECT Unit FROM Resource WHERE Resource_ID = NEW.Resource_ID),
' (Threshold: ', v_threshold, ')'
);

INSERT INTO Sustainability_Alert
(Building_ID, Resource_ID, Record_ID, Alert_Message, Alert_Date, Severity)
VALUES
(NEW.Building_ID, NEW.Resource_ID, NEW.Record_ID, v_msg, NEW.Record_Date, 'High');

INSERT INTO Audit_Log (Table_Name, Operation, Record_Ref_ID, Details)
VALUES ('Sustainability_Alert', 'INSERT', NEW.Record_ID,
CONCAT('Auto-alert for ', v_building, ' – ', v_resource));
END IF;
END$$

CREATE TRIGGER trg_auto_maintenance_flag
AFTER INSERT ON Sustainability_Alert
FOR EACH ROW
BEGIN
DECLARE v_alert_count INT DEFAULT 0;
DECLARE v_building VARCHAR(100);
DECLARE v_resource VARCHAR(50);

SELECT COUNT(*) INTO v_alert_count
FROM Sustainability_Alert
WHERE Building_ID = NEW.Building_ID
AND Resource_ID = NEW.Resource_ID;

IF v_alert_count >= 2 THEN
SELECT Building_Name INTO v_building FROM Building WHERE Building_ID = NEW.Building_ID;
SELECT Resource_Name INTO v_resource FROM Resource WHERE Resource_ID = NEW.Resource_ID;

IF NOT EXISTS (
SELECT 1 FROM Maintenance_Request
WHERE Building_ID = NEW.Building_ID
AND Status != 'Resolved'
AND Issue_Description LIKE CONCAT('%', v_resource, '%')
) THEN
INSERT INTO Maintenance_Request
(Building_ID, Issue_Description, Status, Priority, Request_Date)
VALUES
(NEW.Building_ID,
CONCAT('Recurring ', v_resource, ' overconsumption – inspect and fix immediately'),
'Pending', 'High', CURRENT_DATE);

INSERT INTO Audit_Log (Table_Name, Operation, Record_Ref_ID, Details)
VALUES ('Maintenance_Request', 'INSERT', NEW.Building_ID,
CONCAT('Auto-raised maintenance for repeated ', v_resource, ' alerts'));
END IF;
END IF;
END$$

CREATE TRIGGER trg_log_status_change
BEFORE UPDATE ON Maintenance_Request
FOR EACH ROW
BEGIN
IF OLD.Status != NEW.Status THEN
INSERT INTO Audit_Log (Table_Name, Operation, Record_Ref_ID, Details)
VALUES (
'Maintenance_Request', 'UPDATE', NEW.Request_ID,
CONCAT('Status changed from "', OLD.Status, '" to "', NEW.Status,
'" for Building_ID=', NEW.Building_ID)
);

IF NEW.Status = 'Resolved' THEN
SET NEW.Resolved_Date = CURRENT_DATE;
END IF;
END IF;
END$$

DELIMITER ;

DELIMITER $$

CREATE PROCEDURE sp_monthly_report(IN p_month INT, IN p_year INT)
BEGIN
DECLARE v_done INT DEFAULT FALSE;
DECLARE v_building_id INT;
DECLARE v_building_name VARCHAR(100);
DECLARE v_resource_name VARCHAR(50);
DECLARE v_unit VARCHAR(20);
DECLARE v_total DECIMAL(12,2);
DECLARE v_carbon DECIMAL(12,2);
DECLARE v_cost DECIMAL(12,2);

DECLARE cur_monthly CURSOR FOR
SELECT
b.Building_ID,
b.Building_Name,
r.Resource_Name,
r.Unit,
SUM(cr.Consumption_Amount) AS Total,
SUM(cr.Consumption_Amount) * 0.82 AS Carbon_kg,
SUM(cr.Consumption_Amount) * r.Cost_Per_Unit AS Cost_INR
FROM Consumption_Record cr
JOIN Building b ON cr.Building_ID = b.Building_ID
JOIN Resource r ON cr.Resource_ID = r.Resource_ID
WHERE MONTH(cr.Record_Date) = p_month
AND YEAR(cr.Record_Date) = p_year
GROUP BY b.Building_ID, b.Building_Name, r.Resource_Name, r.Unit, r.Cost_Per_Unit
ORDER BY Total DESC;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

SELECT CONCAT('===== MONTHLY SUSTAINABILITY REPORT — ',
MONTHNAME(STR_TO_DATE(p_month, '%m')), ' ', p_year,
' =====') AS Report_Header;

OPEN cur_monthly;
read_loop: LOOP
FETCH cur_monthly INTO
v_building_id, v_building_name, v_resource_name,
v_unit, v_total, v_carbon, v_cost;

IF v_done THEN
LEAVE read_loop;
END IF;

SELECT
v_building_name AS Building,
v_resource_name AS Resource,
v_total AS Total_Consumed,
v_unit AS Unit,
ROUND(v_carbon,2)AS Carbon_Footprint_kg,
ROUND(v_cost, 2) AS Estimated_Cost_INR;

END LOOP;
CLOSE cur_monthly;

SELECT
COUNT(DISTINCT cr.Building_ID) AS Buildings_Covered,
SUM(cr.Consumption_Amount) AS Grand_Total_Consumption,
ROUND(SUM(cr.Consumption_Amount) * 0.82,2) AS Total_Carbon_kg,
COUNT(sa.Alert_ID) AS Alerts_Generated
FROM Consumption_Record cr
LEFT JOIN Sustainability_Alert sa
ON sa.Record_ID = cr.Record_ID
WHERE MONTH(cr.Record_Date) = p_month
AND YEAR(cr.Record_Date) = p_year;

END$$

CREATE PROCEDURE sp_building_summary(IN p_building_id INT)
BEGIN
DECLARE v_done INT DEFAULT FALSE;
DECLARE v_res_name VARCHAR(50);
DECLARE v_unit VARCHAR(20);
DECLARE v_total DECIMAL(12,2);
DECLARE v_threshold DECIMAL(10,2);
DECLARE v_over_count INT;
DECLARE v_building_name VARCHAR(100);

DECLARE cur_res CURSOR FOR
SELECT
r.Resource_Name,
r.Unit,
COALESCE(SUM(cr.Consumption_Amount), 0),
r.Threshold_Limit,
COUNT(CASE WHEN cr.Consumption_Amount > r.Threshold_Limit THEN 1 END)
FROM Resource r
LEFT JOIN Consumption_Record cr
ON cr.Resource_ID = r.Resource_ID
AND cr.Building_ID = p_building_id
GROUP BY r.Resource_ID, r.Resource_Name, r.Unit, r.Threshold_Limit;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

SELECT Building_Name INTO v_building_name
FROM Building WHERE Building_ID = p_building_id;

SELECT CONCAT('Building Summary: ', v_building_name) AS Header;

OPEN cur_res;
res_loop: LOOP
FETCH cur_res INTO v_res_name, v_unit, v_total, v_threshold, v_over_count;
IF v_done THEN LEAVE res_loop; END IF;

SELECT
v_res_name AS Resource,
v_total AS Total_Consumed,
v_unit AS Unit,
v_threshold AS Threshold,
CASE WHEN v_total > v_threshold THEN '⚠ OVER' ELSE '✓ OK' END AS Status,
v_over_count AS Overconsumption_Incidents;
END LOOP;
CLOSE cur_res;
END$$

CREATE PROCEDURE sp_resolve_alerts(IN p_building_id INT)
BEGIN
DECLARE v_count INT DEFAULT 0;

SELECT COUNT(*) INTO v_count
FROM Sustainability_Alert
WHERE Building_ID = p_building_id AND Acknowledged = 0;

IF v_count = 0 THEN
SELECT 'No pending alerts for this building.' AS Message;
ELSE
UPDATE Sustainability_Alert
SET Acknowledged = 1
WHERE Building_ID = p_building_id AND Acknowledged = 0;

INSERT INTO Audit_Log (Table_Name, Operation, Record_Ref_ID, Details)
VALUES ('Sustainability_Alert', 'UPDATE', p_building_id,
CONCAT(v_count, ' alert(s) acknowledged for Building_ID=', p_building_id));

SELECT CONCAT(v_count, ' alert(s) acknowledged successfully.') AS Message;
END IF;
END$$

CREATE PROCEDURE sp_cursor_all_overconsumption()
BEGIN
DECLARE v_done INT DEFAULT FALSE;
DECLARE v_rec_id INT;
DECLARE v_building VARCHAR(100);
DECLARE v_resource VARCHAR(50);
DECLARE v_amount DECIMAL(10,2);
DECLARE v_thresh DECIMAL(10,2);
DECLARE v_date DATE;

DECLARE cur_over CURSOR FOR
SELECT cr.Record_ID, b.Building_Name, r.Resource_Name,
cr.Consumption_Amount, r.Threshold_Limit, cr.Record_Date
FROM Consumption_Record cr
JOIN Building b ON cr.Building_ID = b.Building_ID
JOIN Resource r ON cr.Resource_ID = r.Resource_ID
WHERE cr.Consumption_Amount > r.Threshold_Limit
ORDER BY cr.Consumption_Amount DESC;

DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

SELECT '===== ALL OVER-THRESHOLD RECORDS =====' AS Header;

OPEN cur_over;
over_loop: LOOP
FETCH cur_over INTO v_rec_id, v_building, v_resource, v_amount, v_thresh, v_date;
IF v_done THEN LEAVE over_loop; END IF;

SELECT
v_rec_id AS Record_ID,
v_building AS Building,
v_resource AS Resource,
v_amount AS Consumed,
v_thresh AS Threshold,
ROUND(((v_amount - v_thresh) / v_thresh) * 100, 1) AS Excess_Pct,
v_date AS Date;
END LOOP;
CLOSE cur_over;
END$$

DELIMITER ;

DELIMITER $$

CREATE FUNCTION fn_carbon_footprint(p_consumption DECIMAL(10,2))
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
RETURN ROUND(p_consumption * 0.82, 2);
END$$

CREATE FUNCTION fn_total_consumption(p_building_id INT, p_resource_id INT)
RETURNS DECIMAL(12,2)
READS SQL DATA
BEGIN
DECLARE v_total DECIMAL(12,2) DEFAULT 0;

SELECT COALESCE(SUM(Consumption_Amount), 0)
INTO v_total
FROM Consumption_Record
WHERE Building_ID = p_building_id
AND Resource_ID = p_resource_id;

RETURN v_total;
END$$

CREATE FUNCTION fn_alert_count(p_building_id INT)
RETURNS INT
READS SQL DATA
BEGIN
DECLARE v_count INT DEFAULT 0;

SELECT COUNT(*) INTO v_count
FROM Sustainability_Alert
WHERE Building_ID = p_building_id
AND Acknowledged = 0;

RETURN v_count;
END$$

DELIMITER ;

SELECT * FROM vw_consumption_detail ORDER BY Record_Date DESC;

SELECT * FROM vw_alert_summary WHERE Acknowledged = 'No';

SELECT * FROM vw_pending_maintenance;

SELECT
b.Building_Name,
fn_total_consumption(b.Building_ID, 1) AS Total_kWh,
fn_carbon_footprint(fn_total_consumption(b.Building_ID, 1)) AS Carbon_kg,
fn_alert_count(b.Building_ID) AS Open_Alerts
FROM Building b
ORDER BY Carbon_kg DESC;

SELECT
MONTHNAME(Record_Date) AS Month,
r.Resource_Name,
SUM(Consumption_Amount) AS Total,
r.Unit
FROM Consumption_Record cr
JOIN Resource r ON cr.Resource_ID = r.Resource_ID
GROUP BY MONTH(Record_Date), MONTHNAME(Record_Date), r.Resource_ID, r.Resource_Name, r.Unit
ORDER BY MONTH(Record_Date), r.Resource_ID;

SELECT
b.Building_Name,
SUM(cr.Consumption_Amount) AS Grand_Total
FROM Consumption_Record cr
JOIN Building b ON cr.Building_ID = b.Building_ID
GROUP BY b.Building_ID, b.Building_Name
ORDER BY Grand_Total DESC
LIMIT 3;

SELECT b.Building_Name
FROM Building b
WHERE b.Building_ID NOT IN (
SELECT DISTINCT Building_ID FROM Sustainability_Alert
);

SELECT
r.Resource_Name,
ROUND(AVG(cr.Consumption_Amount), 2) AS Avg_Consumption,
r.Unit
FROM Consumption_Record cr
JOIN Resource r ON cr.Resource_ID = r.Resource_ID
GROUP BY r.Resource_ID, r.Resource_Name, r.Unit;

SELECT * FROM Audit_Log ORDER BY Changed_At DESC LIMIT 20;

SELECT
b.Building_Name,
r.Resource_Name,
SUM(cr.Consumption_Amount) AS Total_Units,
r.Unit,
r.Cost_Per_Unit,
ROUND(SUM(cr.Consumption_Amount) * r.Cost_Per_Unit, 2) AS Estimated_Cost_INR
FROM Consumption_Record cr
JOIN Building b ON cr.Building_ID = b.Building_ID
JOIN Resource r ON cr.Resource_ID = r.Resource_ID
GROUP BY b.Building_ID, b.Building_Name, r.Resource_ID, r.Resource_Name, r.Unit, r.Cost_Per_Unit
ORDER BY Estimated_Cost_INR DESC;

CALL sp_monthly_report(2, 2025);

CALL sp_building_summary(1);

CALL sp_cursor_all_overconsumption();

CALL sp_resolve_alerts(4);

SELECT fn_carbon_footprint(1500) AS Carbon_1500kWh;
SELECT fn_total_consumption(1, 1) AS AcademicBlockA_Electricity_kWh;
SELECT fn_alert_count(1) AS OpenAlerts_AcademicBlockA;

START TRANSACTION;

INSERT INTO Consumption_Record
(Building_ID, Resource_ID, Consumption_Amount, Record_Date)
VALUES (1, 1, 1350.00, '2025-05-07'); -- triggers alert automatically

UPDATE Maintenance_Request
SET Status = 'In Progress' -- triggers audit log
WHERE Building_ID = 1
AND Status = 'Pending'
AND Priority = 'High'
LIMIT 1;

COMMIT;

SELECT * FROM vw_consumption_detail WHERE Building_Name = 'Academic Block A' ORDER BY Record_Date DESC LIMIT 3;
SELECT * FROM vw_alert_summary WHERE Building_Name = 'Academic Block A' ORDER BY Alert_Date DESC LIMIT 3;
SELECT * FROM Audit_Log ORDER BY Changed_At DESC LIMIT 5;
