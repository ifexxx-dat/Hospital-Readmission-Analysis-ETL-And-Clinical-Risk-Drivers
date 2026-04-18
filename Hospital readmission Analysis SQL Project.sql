CREATE DATABASE healthcare_readmission_project;
USE healthcare_readmission_project;

SELECT *
FROM raw_hospital_data;

DESCRIBE raw_hospital_data;

-- DATA CLEANING
-- FIRST CREATE A COPY OF THE TABLE working table
CREATE TABLE hospital_working_data AS
SELECT * 
FROM raw_hospital_data;

SELECT * 
FROM hospital_working_data;

-- to standardize our text column
UPDATE hospital_working_data
SET Discharge_Disposition =
UPPER(TRIM(Discharge_Disposition));

UPDATE hospital_working_data
SET Primary_Diagnosis_Group =
UPPER(TRIM(Primary_Diagnosis_Group));

UPDATE hospital_working_data
SET 
    Admission_Type =
UPPER(TRIM(Admission_Type)),
    Insurance_Type = 
UPPER(TRIM(Insurance_Type)),
    Gender =
UPPER(TRIM(Insurance_Type)) ;

-- lets fix the error
DROP TABLE hospital_working_data;

CREATE TABLE hospital_work AS
SELECT *
FROM raw_hospital_data;

SELECT *
FROM hospital_work;

-- lets create a primary key
ALTER TABLE hospital_work
ADD COLUMN Patient_id INT AUTO_INCREMENT
PRIMARY KEY FIRST;

-- to standardize our data
UPDATE hospital_work
SET Discharge_Disposition =
UPPER(TRIM(Discharge_Disposition));

UPDATE hospital_work
SET Primary_Diagnosis_Group =
UPPER(TRIM(Primary_Diagnosis_Group));

UPDATE hospital_work
SET 
    Admission_Type =
UPPER(TRIM(Admission_Type)),
    Insurance_Type = 
UPPER(TRIM(Insurance_Type)),
    Gender =
UPPER(TRIM(Gender)) ;

-- to identify and remove duplicates
SELECT Age, COUNT(*) AS Duplicate_c
FROM hospital_work
GROUP BY Age
HAVING COUNT(*) >1 

-- TO FIND ACTUAL DUPLICATS since the data didnt come with an actual unique id primary key we will create a 
-- composite key or a data fingerprint be selecting a combination of columns that makes it statistically impossible
-- for two different people to naturally share same values
SELECT Age, Gender, Length_of_Stay, Medication_Adherence_Score,HbA1c_Level, Discharge_Disposition, COUNT(*) AS Dup_count
FROM hospital_work
GROUP BY Age, Gender, Length_of_Stay, Medication_Adherence_Score, HbA1c_Level, Discharge_Disposition
HAVING COUNT(*) > 1

-- now lets handle the nulls 
SELECT *
FROM hospital_work
WHERE Age IS NULL 
OR Age = ' ';

-- To check for nulls in the rest of the data
SELECT
    SUM(CASE WHEN Gender IS NULL OR TRIM(Gender) = '' THEN 1 ELSE 0 END) AS missing_gender,
     SUM(CASE WHEN Time_Since_Last_Discharge IS NULL THEN 1 ELSE 0 END) AS missing_Time_Since_Last_Discharge,
     SUM(CASE WHEN Length_of_Stay IS NULL THEN 1 ELSE 0 END) AS missing_Length_of_Stay,
     SUM(CASE WHEN Medication_Adherence_Score IS NULL THEN 1 ELSE 0 END) AS missing_Medication_Adherence_Score,
     SUM(CASE WHEN HbA1c_Level IS NULL THEN 1 ELSE 0 END) AS missing_HbA1c_Level,
     SUM(CASE WHEN Admission_Type IS NULL OR TRIM(Admission_Type) = '' THEN 1 ELSE 0 END) AS missing_Admission_Type,
     SUM(CASE WHEN Primary_Diagnosis_Group IS NULL OR TRIM(Primary_Diagnosis_Group) = '' THEN 1 ELSE 0 END) AS missing_Primary_Diagnosis_Group
FROM hospital_work;

-- lets carry ot feature engineering by using a CTE TO Categorize patients into tiers
WITH Patient_risk_category AS (
 SELECT Patient_id, Age, Gender, Medication_Adherence_Score, Readmitted_Within_30_Days,
  -- create a clinical category using case
  CASE
      WHEN  Medication_Adherence_Score < 0.5 THEN 'High_risk (Poor Adherence)'
      WHEN  Medication_Adherence_Score BETWEEN 0.5 AND 0.8 THEN 'Moderate_risk'
 ELSE 'Low Risk (Good Adherence)' 
  END AS Adherence_risk_tier
 FROM hospital_work)
-- now we query the cte 
SELECT Adherence_risk_tier, COUNT(Patient_id) AS Total_Ptients, SUM(Readmitted_Within_30_Days) AS total_readmitted,
ROUND(SUM(Readmitted_Within_30_Days) / COUNT(Patient_id) * 100, 2) AS Readmission_rate_pct
FROM Patient_risk_category
GROUP BY Adherence_risk_tier;

-- FROM THE OUT PUT OF THS QUERY WE CAN SAY THAT MEDICATION ADHERENCE EVEN THOUGH IT IS IMPORTANT IS NT THE MAIN REASON FOR HIH READMISSION RATE
SELECT Primary_Diagnosis_Group, COUNT(Patient_id) AS Total_patients, SUM(Readmitted_Within_30_Days) AS Total_readmission,
ROUND(SUM(Readmitted_Within_30_Days) / COUNT(Patient_id) * 100, 2 ) AS readmission_rate_pct
FROM hospital_work
GROUP BY Primary_Diagnosis_Group
HAVING Total_patients > 50;

-- lets try comorbidity index
SELECT Comorbidity_Index, COUNT(Patient_id) AS Total_patients, SUM(Readmitted_Within_30_Days) AS Total_readmission,
ROUND(SUM(Readmitted_Within_30_Days) / COUNT(Patient_id) * 100, 2 ) AS readmission_rate_pct
FROM hospital_work
GROUP BY Comorbidity_Index
HAVING Total_patients > 50;

SELECT Chronic_Disease_Count, COUNT(Patient_id) AS Total_patients, SUM(Readmitted_Within_30_Days) AS Total_readmission,
ROUND(SUM(Readmitted_Within_30_Days) / COUNT(Patient_id) * 100, 2 ) AS readmission_rate_pct
FROM hospital_work
GROUP BY Chronic_Disease_Count
HAVING Total_patients > 50;

-- 1. Generational bins VS Readmission risk
SELECT 
CASE
 WHEN Age < 40 THEN '1. Young_Adult (<35)'
 WHEN Age BETWEEN 35 AND 60 THEN '2. Middle_aged (35-60)'
 WHEN Age BETWEEN 60 AND 70 THEN '3.Senior' ELSE '4. Elderly (70+)'
 END  AS Age_category,
 COUNT(Patient_id) AS Total_Patients,
 ROUND(AVG(Length_of_stay), 1) AS Avg_stay_days,
 ROUND(SUM(Readmitted_Within_30_Days)  / COUNT(Patient_id) * 100, 2) AS Readmission_rate
 FROM hospital_work
 GROUP BY Age_category
 ORDER BY Age_category;
 
 -- Patient Profiles Compound risk
 WITH Compound_Risk AS (
    SELECT 
        Patient_id,
        Primary_Diagnosis_Group,
        CASE 
            WHEN Medication_Adherence_Score < 0.50 AND HbA1c_Level > 8.0 THEN 'High Compound Risk'
            ELSE 'Standard Risk'
        END AS Clinical_Risk_Profile
    FROM hospital_work
)
SELECT 
    Primary_Diagnosis_Group,
    Clinical_Risk_Profile,
    COUNT(*) AS Total_Patients
FROM Compound_Risk
GROUP BY Primary_Diagnosis_Group, Clinical_Risk_Profile
ORDER BY Primary_Diagnosis_Group, Clinical_Risk_Profile;

-- Using subqueries for clinical benchmarking; isolating patients below hospitals average adherence
SELECT 
    Patient_id,
    Age,
    Primary_Diagnosis_Group,
    Medication_Adherence_Score
FROM hospital_work
WHERE Medication_Adherence_Score < (
    -- This subquery calculates the hospital-wide average dynamically
    SELECT AVG(Medication_Adherence_Score) FROM hospital_work
)
ORDER BY Medication_Adherence_Score ASC
LIMIT 100;

-- 4. Anomaly detection for unusually long hospital stays 
-- use cte and subquery to find outliers
WITH Diagnosis_Averages AS (
    SELECT 
        Primary_Diagnosis_Group, 
        AVG(Length_of_Stay) AS Avg_LOS
    FROM hospital_work
    GROUP BY Primary_Diagnosis_Group
)
SELECT 
    h.Patient_id,
    h.Primary_Diagnosis_Group,
    h.Length_of_Stay,
    ROUND(d.Avg_LOS, 1) AS Typical_Stay_For_Diagnosis
FROM hospital_work h
JOIN Diagnosis_Averages d 
    ON h.Primary_Diagnosis_Group = d.Primary_Diagnosis_Group
WHERE h.Length_of_Stay > (d.Avg_LOS * 1.5) -- Flags stays that are 50% longer than average
ORDER BY h.Length_of_Stay DESC;

-- 5. Data Ranking and Partitioning Use a windows function to rank diagnosis by severity within gender
SELECT 
    Gender,
    Primary_Diagnosis_Group,
    Total_Readmissions,
    DENSE_RANK() OVER(PARTITION BY Gender ORDER BY Total_Readmissions DESC) AS Severity_Rank
FROM (
    SELECT 
        Gender,
        Primary_Diagnosis_Group,
        SUM(Readmitted_Within_30_Days) AS Total_Readmissions
    FROM hospital_work
    GROUP BY Gender, Primary_Diagnosis_Group
) AS Aggregated_Data;

-- 6. Quartile split for length of stay
SELECT 
    Length_of_Stay_Quartile,
    MIN(Length_of_Stay) AS Min_Days,
    MAX(Length_of_Stay) AS Max_Days,
    COUNT(Patient_id) AS Patient_Volume
FROM (
    SELECT 
        Patient_id,
        Length_of_Stay,
        NTILE(4) OVER(ORDER BY Length_of_Stay ASC) AS Length_of_Stay_Quartile
    FROM hospital_work
) AS Quartile_Data
GROUP BY Length_of_Stay_Quartile;

-- 7. WORST DISCHARGE DESTINATION PER DIAGNOSIS
WITH Ranked_Destinations AS (
    SELECT 
        Primary_Diagnosis_Group,
        Discharge_Disposition,
        COUNT(Patient_id) AS Total_Patients,
        ROW_NUMBER() OVER(PARTITION BY Primary_Diagnosis_Group ORDER BY COUNT(Patient_id) DESC) AS Dest_Rank
    FROM hospital_work
    GROUP BY Primary_Diagnosis_Group, Discharge_Disposition
)
SELECT * FROM Ranked_Destinations
WHERE Dest_Rank = 1; -- Only shows the NO 1  most common discharge destination per diagnosis

-- 8. MEDICATION ADHERENCE VS HBA1C CONTROL CORROLTION prepare
SELECT 
    ROUND(Medication_Adherence_Score, 1) AS Adherence_Tenths,
    ROUND(AVG(HbA1c_Level), 2) AS Average_HbA1c,
    COUNT(Patient_id) AS Sample_Size
FROM hospital_work
GROUP BY ROUND(Medication_Adherence_Score, 1)
ORDER BY Adherence_Tenths DESC;

-- 9. The Cross Tabulation Matrix 
SELECT 
    Primary_Diagnosis_Group,
    SUM(CASE WHEN Discharge_Disposition = 'HOME' THEN 1 ELSE 0 END) AS Discharged_Home,
    SUM(CASE WHEN Discharge_Disposition = 'REHAB' THEN 1 ELSE 0 END) AS Discharged_Rehab,
    SUM(CASE WHEN Discharge_Disposition = 'NURSING FACILITY' THEN 1 ELSE 0 END) AS Discharged_Nursing_Facility
FROM hospital_work
GROUP BY Primary_Diagnosis_Group;

-- 10. The Utimate Executive Summary View A Master Table For Power BI
SELECT 
    Primary_Diagnosis_Group,
    Discharge_Disposition,
    COUNT(Patient_id) AS Total_Encounters,
    ROUND(AVG(Length_of_Stay), 1) AS Avg_LOS,
    ROUND(AVG(Medication_Adherence_Score), 2) AS Avg_Adherence,
    SUM(Readmitted_Within_30_Days) AS Total_Readmissions,
    ROUND((SUM(Readmitted_Within_30_Days) / COUNT(Patient_id)) * 100, 2) AS Readmission_Rate
FROM hospital_work
GROUP BY 
    Primary_Diagnosis_Group,
    Discharge_Disposition
ORDER BY 
    Total_Encounters DESC;
    