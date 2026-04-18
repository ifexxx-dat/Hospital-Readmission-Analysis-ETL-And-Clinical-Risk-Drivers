Hospital Readmission Analysis: ETL & Clinical Risk Drivers

Project Overview
This project analyzes a healthcare dataset containing 18,000 patient records to identify the primary drivers of 30-day hospital readmissions. The objective was to build a robust ETL pipeline, engineer clinical features, and uncover actionable insights to reduce readmission rates.

During the Exploratory Data Analysis (EDA) phase, advanced querying revealed that the dataset was synthetically generated and balanced for machine learning classification rather than reflecting organic clinical variance.

Tech Stack & Tools
• Database: MySQL
• Techniques Used: Common Table Expressions (CTEs), Window Functions (NTILE, DENSE_RANK), Subqueries, Feature Engineering (CASE statements), Data Type Casting, and Schema Design.

Phase 1: ETL & Data Cleaning

To ensure data integrity, I established a secure staging environment (hospital_working_data) to protect the raw source data. The cleaning pipeline included:

• Schema Correction: Identified and resolved a column shift error caused by a CSV import wizard misaligning Insurance_Type and Gender data. Rebuilt the table schema and successfully re-mapped the data.

• Text Standardization: Applied UPPER(TRIM()) to all categorical columns (e.g., Discharge_Disposition, Gender) to prevent grouping errors during aggregation.

• The Duplicate Paradox (Advanced Fingerprinting): Initial aggregate checks suggested 296 duplicate rows based on Age, Gender, LOS, and Adherence. However, by expanding the composite key to include granular clinical markers (HbA1c_Level), I proved the dataset contained zero duplicates, validating the integrity of highly similar patient profiles.

Phase 2: Feature Engineering & EDA

Instead of analyzing raw decimals, I used SQL to engineer business-friendly clinical metrics:

• Adherence Risk Tiers: Built a CTE using a CASE statement to categorize patients' Medication Adherence Scores into High, Moderate, and Low Risk groups.
• Anomaly Detection: Utilized Window Functions and Subqueries to flag patient outliers whose Length of Stay exceeded 150% of the baseline average for their specific primary diagnosis.
• Cohort Ranking: Applied NTILE(4) to segment patients into quartiles based on hospital stay duration for comparative readmission analysis.

Key Findings & The "Synthetic Dat Discovery
1. Medication Adherence Impact: Segmenting the dataset by adherence risk tiers revealed remarkably flat readmission rates across all groups (ranging only from 73.4% to 75.5%), suggesting adherence was not the primary driver of readmission.
   
2. The ML-Balancing Artifact: Further analysis grouped patients by Primary_Diagnosis. The query returned perfectly uniform patient cohorts (approx. 3,600 patients each) with near-identical readmission rates (~74%) across completely different diseases (Cardiac, Infection, Diabetes).
   
3. Conclusion: These uniform distributions mathematically confirm the dataset is a synthetic, ML-balanced dataset created for predictive modeling training. Identifying this artifact prevented the reporting of false clinical insights and demonstrated strong data literacy.

Featured SQL Queries
Feel free to explore the full .sql script in this repository. Here is a highlight of the anomaly detection query used to find length-of-stay outliers:

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
WHERE h.Length_of_Stay > (d.Avg_LOS * 1.5)
ORDER BY h.Length_of_Stay DESC;

Author
Okoli Ifechukwu Chinwe

Contact me
Linedin ; http://linkedin.com/in/ife-okoli
