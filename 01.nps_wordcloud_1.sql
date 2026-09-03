CREATE OR REPLACE TABLE `elc-cdpcrm-prj-prd.tmp_looker_crm.tmp_nps_survey_results_partitioned`

PARTITION BY

  RANGE_BUCKET(partition_int, GENERATE_ARRAY(0, 20))

AS (

  SELECT *, CAST(FLOOR(CAST(RIGHT(survey_id, 2) AS INT64) / 5) AS INT64) AS partition_int

  FROM `elc-cdpcrm-prj-prd.vlt_mrt.survey_results`

  WHERE date(invitation_date) = current_date() - 1

)