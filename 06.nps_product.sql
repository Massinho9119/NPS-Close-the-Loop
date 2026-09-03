--tmp table banner prep code
CREATE TEMPORARY TABLE banner_prep AS
SELECT DISTINCT b.Region AS region, 
b.country_description as country, a.sales_organization,
c.brand AS banner, a.distribution_channel, 
type
FROM `elc-cdpcrm-prj-prd.crm_analytics.dim_distribution_channel_country` AS a
JOIN `elc-cdpcrm-prj-prd.crm_analytics.dim_country` AS b ON a.sales_organization=b.sales_organization
JOIN `elc-cdpcrm-prj-prd.crm_analytics.dim_brand_type` AS c ON a.distribution_channel=c.distribution_channel
;


--tmp table survey code for the two previous complete fiscal months from the date of execution
CREATE TEMPORARY TABLE all_survey AS
SELECT DISTINCT 
a.survey_h_hid, a.survey_type,
a.fiscal_date, a.fiscal_year, a.fiscal_month,
CASE WHEN a.purchase_channel = 'Internet' 	
    THEN 'E-commerce'
		ELSE 'Brick and Mortar'
		END AS channel,
a.source_site,
s.site_name,
b.region, 
b.country, 
b.banner, 
t.distribution_channel,
b.type,
h.receipt_h_hid,
h.complete_ophth, 
h.complete_sun, 
h.plano_sun, 
h.contact_lens, 
h.dr_service_exams,
CASE WHEN h.lens_focal_type=True OR h.lens_only_ophth=True OR h.lens_only_sun=True THEN True ELSE False END AS lens_only,
h.frame_only_ophth, 
h.accessory,
h.reader
FROM 
    (SELECT * 
    FROM elc-cdpcrm-prj-prd.vlt_mrt.survey_url AS a
    INNER JOIN elc-cdpcrm-prj-prd.vlt_mrt.calendar AS c ON c.fiscal_date=a.invitation_date
    WHERE  
    (
	
  (EXTRACT(YEAR FROM invitation_date) = EXTRACT(YEAR FROM DATE_SUB(current_date, INTERVAL 1 MONTH)) 
  AND EXTRACT(MONTH FROM invitation_date) = EXTRACT(MONTH FROM DATE_SUB(current_date, INTERVAL 1 MONTH)))
  OR
    (EXTRACT(YEAR FROM invitation_date) = EXTRACT(YEAR FROM DATE_SUB(current_date, INTERVAL 2 MONTH)) 
  AND EXTRACT(MONTH FROM invitation_date) = EXTRACT(MONTH FROM DATE_SUB(current_date, INTERVAL 2 MONTH)))

    )

AND a.survey_type NOT IN ('CCEMAIL','CCSMS','PICKUP_Optical') 
    ) AS a 

LEFT JOIN elc-cdpcrm-prj-prd.vlt_mrt.transaction_headers AS t
                                                ON a.txnheader_h_hid=t.txnheader_h_hid
LEFT JOIN banner_prep AS b ON t.distribution_channel=b.distribution_channel
                              AND t.sales_organization=b.sales_organization
LEFT JOIN elc-cdpcrm-prj-prd.vlt_mrt.sites s on t.site_h_hid=s.site_h_hid
LEFT JOIN elc-cdpcrm-prj-prd.vlt_mrt.transaction_receipt AS h ON t.receipt_h_hid=h.receipt_h_hid --così recupero tutti quelli che hanno lo stesso receipt.
;


--tmp table survey step2 code for the two previous complete fiscal months from the date of execution
CREATE TEMPORARY TABLE all_survey_step2 AS
SELECT 
survey_h_hid, 
survey_type, 
fiscal_date, fiscal_year, fiscal_month,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
CASE WHEN optical_t > 0 THEN True ELSE False END AS optical_flag,
CASE WHEN plano_t > 0 THEN True ELSE False END AS plano_flag,
CASE WHEN contacts_t > 0 THEN True ELSE False END AS contact_lens_flag,
CASE WHEN dr_service_exams_t > 0 THEN True ELSE False END AS dr_service_exams_flag,
CASE WHEN accessory_t > 0 THEN True ELSE False END AS accessory_flag,
CASE WHEN reader_t > 0 THEN True ELSE False END AS reader_flag
FROM 
	(SELECT distribution_channel,
  survey_h_hid, survey_type, 
	fiscal_date, fiscal_year, fiscal_month,
  source_site,
  site_name,
  region, 
  country, 
  banner, 
  type,
  channel,
	SUM(CASE WHEN complete_ophth=True OR complete_sun=True OR lens_only=True OR frame_only_ophth=True THEN 1 ELSE 0 END) AS optical_t,
	SUM(CASE WHEN plano_sun=True THEN 1 ELSE 0 END) AS plano_t,
	SUM(CASE WHEN contact_lens=True THEN 1 ELSE 0 END) AS contacts_t,
	SUM(CASE WHEN dr_service_exams=True THEN 1 ELSE 0 END) AS dr_service_exams_t,
	SUM(CASE WHEN accessory=True THEN 1 ELSE 0 END) AS accessory_t,
  SUM(CASE WHEN reader=True THEN 1 ELSE 0 END) AS reader_t
	FROM all_survey
	GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13
) AS x
;

--all_survey table step1 code-->it contains the data for the two previous fiscal months
CREATE OR REPLACE TABLE elc-cdpcrm-prj-prd.tmp_looker_crm.all_survey_with_score_step1 AS
SELECT a.survey_h_hid, 
CASE 
WHEN a.survey_type IN ('Optical','Sun','PICKUP_Optical') THEN 'NPS'
WHEN a.survey_type IN ('STELLA_Optical','SNOVA_Optical','STELLA_Sun','SNOVA_Sun') THEN 'Meta NPS'
WHEN a.survey_type IN ('NUANCE_Optical') THEN 'Nuance NPS'
WHEN a.survey_type IN ('EXAM_Optical') THEN 'EXAM NPS' 
WHEN a.survey_type IN ('Product') THEN 'CEPS' 
WHEN a.survey_type IN ('STELLA_Product','SNOVA_Product') THEN 'Meta CEPS' 
WHEN a.survey_type IN ('NUANCE_Product') THEN 'Nuance CEPS'
ELSE 'OTHER' END AS survey_type,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
fiscal_date, fiscal_year, fiscal_month,
source_site,
site_name,
optical_flag,
plano_flag,
contact_lens_flag,
dr_service_exams_flag,
accessory_flag,
reader_flag,
CASE 
WHEN CONCAT(IFNULL(b.opt_ltr_score,''),IFNULL(b.sun_ltr_score,''),IFNULL(b.product_ltr_score,''),IFNULL(b.score,'')) IN ('0','1','2','3','4','5','6','7','8','9','10') THEN CONCAT(IFNULL(b.opt_ltr_score,''),IFNULL(b.sun_ltr_score,''),IFNULL(b.product_ltr_score,''),IFNULL(b.score,''))
ELSE NULL END AS score,
b.doctor_ltr_score AS doctor_score
FROM all_survey_step2 AS a
LEFT JOIN  elc-cdpcrm-prj-prd.vlt_mrt.survey_results b ON a.survey_h_hid = b.survey_h_hid;


--all_survey table step2 code-->it contains the data for the two previous fiscal months
CREATE OR REPLACE TABLE elc-cdpcrm-prj-prd.tmp_looker_crm.all_survey_with_score_step2 AS
with pa1 AS
(
SELECT 
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
fiscal_year,
fiscal_month,
fiscal_date,
optical_flag,
plano_flag,
contact_lens_flag,
dr_service_exams_flag,
accessory_flag,
reader_flag,
COUNT(DISTINCT survey_h_hid) As survey_sent,
COUNT(DISTINCT CASE WHEN score IS NOT NULL THEN survey_h_hid ELSE NULL END) AS voters,
COUNT(DISTINCT CASE WHEN score IN ('0','1','2','3','4','5','6') THEN survey_h_hid ELSE NULL END) AS detractors,
COUNT(DISTINCT CASE WHEN score IN ('7','8') THEN survey_h_hid ELSE NULL END) AS passive,
COUNT(DISTINCT CASE WHEN score IN ('9','10') THEN survey_h_hid ELSE NULL END) AS promoters,
COUNT(DISTINCT CASE WHEN doctor_score IN  ('0','1','2','3','4','5','6','7','8','9','10') THEN survey_h_hid ELSE NULL END) AS doctor_voters,
COUNT(DISTINCT CASE WHEN doctor_score IN ('0','1','2','3','4','5','6') THEN survey_h_hid ELSE NULL END) AS doctor_detractors,
COUNT(DISTINCT CASE WHEN doctor_score IN ('7','8') THEN survey_h_hid ELSE NULL END) AS doctor_passive,
COUNT(DISTINCT CASE WHEN doctor_score IN ('9','10') THEN survey_h_hid ELSE NULL END) AS doctor_promoters,
FROM elc-cdpcrm-prj-prd.tmp_looker_crm.all_survey_with_score_step1
GROUP BY ALL
),

pa2 AS
(

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'OVERALL' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
GROUP BY ALL

UNION ALL 

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'OPTICAL' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE optical_flag=True
GROUP BY ALL

UNION ALL

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'PLANO SUN' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE plano_flag=True
GROUP BY ALL

UNION ALL

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'CONTACTS' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE contact_lens_flag=True
GROUP BY ALL

UNION ALL

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type, 
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'ACCESSORY' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE accessory_flag=True
GROUP BY ALL

UNION ALL

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type, 
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'READER' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE reader_flag=True
GROUP BY ALL

UNION ALL

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type,
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
'DR EXAM' AS product,
SUM(survey_sent) AS survey_sent,
SUM(voters) AS voters,
SUM(detractors) AS detractors,
SUM(passive) AS passive,
SUM(promoters) AS promoters,
SUM(doctor_voters) AS doctor_voters,
SUM(doctor_detractors) AS doctor_detractors,
SUM(doctor_passive) AS doctor_passive,
SUM(doctor_promoters) AS doctor_promoters
FROM pa1
WHERE 
dr_service_exams_flag = True
AND ((survey_type='EXAM NPS' AND fiscal_date < '2026-01-01')
    OR fiscal_date >= '2026-01-01')
GROUP BY ALL
)

SELECT 
fiscal_year,
fiscal_month,
fiscal_date,
survey_type, 
source_site,
site_name,
region, 
country, 
banner, 
distribution_channel,
type,
channel,
product,
survey_sent,
voters,
detractors,
passive,
promoters,
doctor_voters,
doctor_detractors,
doctor_passive,
doctor_promoters,
CASE WHEN voters= 0 THEN NULL ELSE ROUND(((promoters/voters)-(detractors/voters))*100) END AS score,
CASE WHEN doctor_voters= 0 THEN NULL ELSE ROUND(((doctor_promoters/doctor_voters)-(doctor_detractors/doctor_voters))*100) END AS doctor_score
FROM pa2 
where distribution_channel not in ('H1','H2','H3','H4','Y1');

--check to delete from main table
DELETE from elc-cdpcrm-prj-prd.looker_crm_analytics.all_survey_with_score
WHERE 
  concat(
  cast(cast(fiscal_year as INTEGER) *100 + cast(fiscal_month as INTEGER) as string)
  , banner
  , country
  )
  in (
  SELECT DISTINCT 
      concat(
      cast(cast(fiscal_year as INTEGER) *100 + cast(fiscal_month as INTEGER) as string)
      ,banner
      ,country
  )
    from elc-cdpcrm-prj-prd.tmp_looker_crm.all_survey_with_score_step2
  );


-- insert the latest fiscal months data into the main table
INSERT INTO elc-cdpcrm-prj-prd.looker_crm_analytics.all_survey_with_score (
  fiscal_year, fiscal_month, fiscal_date, survey_type, source_site, site_name, 
  region, country, banner, distribution_channel, type, channel, product, 
  survey_sent, voters, detractors, passive, promoters, 
  doctor_voters, doctor_detractors, doctor_passive, doctor_promoters, 
  score, doctor_score
)
SELECT 
  fiscal_year, fiscal_month, fiscal_date, survey_type, source_site, site_name, 
  region, country, banner, distribution_channel, type, channel, product, 
  survey_sent, voters, detractors, passive, promoters, 
  doctor_voters, doctor_detractors, doctor_passive, doctor_promoters, 
  score, doctor_score
FROM elc-cdpcrm-prj-prd.tmp_looker_crm.all_survey_with_score_step2;


