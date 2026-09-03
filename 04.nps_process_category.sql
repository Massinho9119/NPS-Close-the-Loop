CREATE TABLE IF NOT EXISTS `elc-cdpcrm-prj-prd.looker_crm_analytics.nps_survey_comment_categorization` 
(survey_h_hid STRING, 
invitation_date TIMESTAMP, 
comment STRING, 
comment_category STRING);
  
insert into `elc-cdpcrm-prj-prd.looker_crm_analytics.nps_survey_comment_categorization` 
(survey_h_hid, invitation_date, comment, comment_category)
with 
    mydata as (
        select 
            survey_h_hid,
            invitation_date,
            CONCAT(IFNULL(opt_ltr_followup_comment,''),IFNULL(sun_ltr_followup_comment,''),IFNULL(product_ltr_followup_comment,''),IFNULL(verbatim,'')) as comment,
        FROM `elc-cdpcrm-prj-prd.tmp_looker_crm.tmp_nps_survey_results_partitioned`
        --> name tmp_table to be changed
        where partition_int = {{part}} 
        and CONCAT(IFNULL(opt_ltr_followup_comment,''),IFNULL(sun_ltr_followup_comment,''),IFNULL(product_ltr_followup_comment,''),IFNULL(verbatim,'')) != "" 
    ), 
    a as 
    (
        SELECT
            ml_generate_text_llm_result AS result,
            comment,
            survey_h_hid,
            invitation_date,
        FROM
            ML.GENERATE_TEXT ( 
                MODEL `elc-cdpcrm-prj-prd.looker_crm_analytics.gemini_flash`,
                (
                    SELECT
                        CONCAT('Multiple-choice problem: Based on which is the aspect the customer is talking about, assign each comment to one of the following categories: "Aftersales" "Conventions/Insurance" "Product" "Staff Issues" "Store Appointment" "Subscribtions" "Customer Service" "Doctor Experience" "General Experience" "Logistic and Transportation" "Omnichnannel" "Pricing" "In-Store Experience" "Product Store Website" "Web-Store Delivery Time" "Associate" "Supply Chain" "Other". Please only print the category name without anything else. Without further explanation about your criteria of choice. The output must be json format like: {"Comment Category": "Aftersales", "Conventions/Insurance", "Product", "Staff Issues", "Store Appointment", "Subscribtions", "Customer Service", "Doctor Experience", "General Experience", "Logistic and Transportation", "Omnichnannel", "Pricing", "In-Store Experience", "Product Store Website", "Web-Store Delivery Time", "Associate", "Supply Chain", "Other" }./n . The text on which to perform the operation is the following:', NULLIF(comment,"")) AS prompt,
                        comment,
                        survey_h_hid,
                        invitation_date,
                    FROM
                        mydata
                ),
                STRUCT (0.1 AS temperature, 1000 AS max_output_tokens, TRUE as flatten_json_output) 
                )
    ),

    b as 
    (
        SELECT
            survey_h_hid,
            invitation_date,
            comment,
            result,
            REGEXP_EXTRACT(result, r'```json\s*(\{[\s\S]*?\})\s*```') AS result2
        FROM  `a`
    )

SELECT
    survey_h_hid,
    invitation_date,
    comment,
    -- JSON_VALUE(result, "$.Comment Category") AS comment_category1,
    -- JSON_VALUE(result2, "$.Comment Category") AS comment_category2,
    IFNULL(JSON_VALUE(result, "$.Comment Category"),JSON_VALUE(result2, "$.Comment Category") ) AS comment_category
FROM b;