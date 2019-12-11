/* Disclaimer
Copyright (C), Sotirios Adamakis
This software may be used, copied, or redistributed only with the permission of Sotirios Adamakis. 
If used, copied, or redistributed it should not be sold and this copyright notice should be reproduced 
on each copy made. All code in this document is provided "as is" by Sotirios Adamakis without warranty 
of any kind, either express or implied, including but not limited to the implied warranties of 
merchantability and fitness for a particular purpose. Recipients acknowledge and agree that 
Sotirios Adamakis shall not be liable for any damages whatsoever arising out of their use of this 
material. In addition, Sotirios Adamakis will provide no support, updates or patches for the materials contained herein.
*/
/*------------------------------------------------------------------------------------------------------*/
/* Author:                   ---  Sotirios Adamakis                                                     */
/* Program Name:             ---  sensitivity_code_execution.sas		    							*/
/* Description:              ---  Perform Sensitivity Analysis on All Raw Independent Variables of A Model and Generate Report                                      															*/
/* Note: If the model has more than one segment, please run the sensitivity analysis macro separately for each segment. The input dataset 
           should only include observations from the specific segment, but the scoring code can include one/multiple segments as long as the 
           segmentation variables are retained in the input dataset;                                    */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/


/* Run sensitivity analysis on model development data */

options compress=yes obs=max source2 mprint nomlogic nosymbolgen;
/* Sensitivity analysis macro */
%include "../sensitivity_analysis.sas";
/* Data location */
libname data_loc '..';
/* Scorefile location */
%let scorefile=Side_Projects/Analytical_Solutions/Scorecard_Suite/development/Sensitivity analysis/scoring_macro.sas;

/******************************************************************************/
/*Create the data*/
/******************************************************************************/
data FPF;
                set data_loc.FPF_merge;
run;

/*Select the last record of the application, only for accounts that pass the CYR stage*/
proc sort data=FPF (where=(not(missing(APPL_CRTN_DT)))) out=FPF_s;
                by appl_id row_num;
run;
data FPF_score_last;
set FPF_s;
                by appl_id;
                if last.appl_id;
run;

/*Select the first record at the hard pull stage - this is where the score is calculated*/
proc sort data=FPF (where=(not(missing(APPL_CRTN_DT)))) out=FPF_s_first;
                by appl_id row_num;
run;
data FPF_score_first;
set FPF_s_first;
                by appl_id;
                if first.appl_id;
run;

/*Add attributes for exclusions*/
proc sql;
create table FPF_score_att as
select 
                t1.*
                , t2.str_roll
                , t2.mob_nbr
                , t2.fico_score_nbr_app
                , t2.mrl_2015
                , t2.final_loan_amt_app
                , t2.chrgoff_ind
                , t2.chrgoff_rsn_cd 
                , t2.acct_open_dt
                , t2.chrgoff_dt
                , t2.chrgoff_amt
                , t2.loan_origtn_amt
                /*BK: bankruptcy -
                DC: deceased
                FR: fraud
                PL: policy -
                NC: not charged-off
                */

from FPF_score_first as t1
left join data_loc.merge_data_fnl_cl as t2
on t1.appl_id = t2.appl_id
;
quit;

/*Create month variable and 1st party fraud flag*/
data FPF_score_att_new;
                set FPF_score_att;
/*Create an open market flag*/
                if APPL_REC_DT >= '14OCT2018'd then open_market_time_period = 1;
                else open_market_time_period = 0;
/*Create month variable*/
                month = cat(year(APPL_REC_DT), put(month(APPL_REC_DT), z2.));
/*Days to charge-off*/
                time_to_chrgoff = chrgoff_dt - acct_open_dt;
/*Charge-off month*/
                chrgoff_month = ceil(time_to_chrgoff/30.5);
                format CO_monthend Open_month_beg date9.;
                CO_monthend= intnx('MONTH',chrgoff_dt,0,'e');
                Open_month_beg= intnx('MONTH',acct_open_dt, 0,'b');

                MOB_at_CO= intck('month',Open_month_beg,CO_monthend)+1;

/*Fraud indicator*/
                if str_roll='Y' and chrgoff_ind='1' then stroller_ind = 1;
                else stroller_ind=0;
/*           if (chrgoff_rsn_cd in ('BK', 'PL') and MOB_at_CO<=7 and not(missing(time_to_chrgoff))) then co_7mob_ind=1;*/
/*           else co_7mob_ind=0;*/
                if (chrgoff_ind='1' and MOB_at_CO<=7 and not(missing(MOB_at_CO))) then co_7mob_ind=1;
                else co_7mob_ind=0;
                if stroller_ind=0 and co_7mob_ind=1 then non_stroller_ind=1;
                else non_stroller_ind=0;
                if stroller_ind = 1 or co_7mob_ind=1 then fpf_flag=1;
                else fpf_flag=0;
                if fpf_flag=1 and MOB_at_CO<=7 and not(missing(MOB_at_CO)) then fpf_flag_performance = 1;
                else fpf_flag_performance = 0;
/*Produce the 1st party fraud score*/
                SSN_ISSUE_YR_TXT=1.0*SSN_ISSUE_YR_TXT1;

/***********************************************************************************************/
/***********************************************************************************************/
/*********** CUSTOMIZED SECTION - HARD CODE DERIVED VARIABLES IN YOUR SCORING CODE
                                                AND DROP THE DERIVED VARIABLE CODE FROM THE SCORING CODE ***************************/
if (bca0300 le 90) and (bca0300-bcc0300 ge 1) then ind_charge_card_1=1;
else ind_charge_card_1=0;
if bcc0300 gt 0 and bcc0300 le 90 then ind_BC_1=1; else ind_BC_1=0;
if MTF0300 gt 0 and MTF0300 le 90 then ind_mortgage_1=1; else ind_mortgage_1=0;
if rta0300 gt 0 and rta0300 le 90 then ind_retail_1 =1; else ind_retail_1=0;
if AUA1300 ge 0 and AUA1300 le 90 then ind_auto_1=1; else ind_auto_1=0;
if (ILN5020 le 999999997) then ind_installment_1=1; else ind_installment_1=0;
if (HLC2000 le 97) then ind_heloc_1=1; else ind_heloc_1=0;

total_unique_trade_all=(ind_charge_card_1+ind_BC_1+ind_mortgage_1+ind_retail_1+ind_auto_1+ind_installment_1+ind_heloc_1);

/************************************/
/* Step 2: create model segment */
if total_unique_trade_all <= 2 then seg =1;else seg =2;

If SSN_ISSUE_YR_TXT =. or SSN_ISSUE_YR_TXT=0 or birth_yr_nbr=. or birth_yr_nbr =0 then SSNGAP =9999;
Else SSNGAP=(SSN_ISSUE_YR_TXT- birth_yr_nbr); 

if seg =1 then do;
                if IQB9410 = 0 then inq_b_pc_3m = 9999 ; else inq_b_pc_3m = round((IQb9415 /IQB9410)*100, 1);

                if ALL0416>90 or ALL5320>999999990 then avg_cred=999999999;
                else if ALL0416=0 then avg_cred=999999995;
                else avg_cred=round(ALL5320/ALL0416, 0.1);
end;
if seg=2 then do;
                if ALL0300 > 90 or BCA0436 =99 then  pct_bankcar_act_op_6m = 999;
                else if BCA0436 =98 then pct_bankcar_act_op_6m = 998;
                else if all0300 =0 then pct_bankcar_act_op_6m =997;
                else  pct_bankcar_act_op_6m = round(BCA0436/ALL0300, 0.000001);

                if RTR3424>90 and  BCC3424>90 then util_gt_90_1=99;
                else if BCC3424>90 then util_gt_90_1=RTR3424;
                else if RTR3424>90 then util_gt_90_1=BCC3424;
                else util_gt_90_1=BCC3424 + RTR3424;
end;
/***********************************************************************************************/
/***********************************************************************************************/
%include "/sasdata/dec_sci/user_projects/DSSPROD/crm_models2/fraud/Consumer_lending/fpf/code/model_governance/FPF_scoring_macro_v4_no_macro.sas";
                weight = 1;
run;

data FPF_score_opened_excl;
                set FPF_score_att_new;
                if missing(extnl_acct_id) or mrl_2015>=6 or final_loan_amt_app<=5000 or fico_score_nbr_app<720 or chrgoff_rsn_cd in ('DC', 'FR') or missing(ALL0300) then exclusion_flag_fraud_strategy = 1;
                else exclusion_flag_fraud_strategy = 0;
                if missing(extnl_acct_id) or chrgoff_rsn_cd in ('DC', 'FR') or missing(ALL0300) then exclusion_flag_qa_fraud = 1;
                else exclusion_flag_qa_fraud = 0;
run;

data segment_1;
                set FPF_score_opened_excl (where=(seg=1 and exclusion_flag_fraud_strategy = 0));
run;
proc means data=segment_1 N NMISS MEAN STD MIN p95 p99 MAX;
var 
BCA5430
ALX8220
TIME_AT_RESIDENCE_VAR
SSNGAP
all5020
inq_b_pc_3m  
avg_cred  
BAX3510
IQA9410
;
run;

data segment_2;
                set FPF_score_opened_excl (where=(seg=2 and exclusion_flag_fraud_strategy = 0));
run;
proc means data=segment_2 N NMISS MEAN STD MIN p95 p99 MAX;
var 
ALL5320  
SSNGAP 
TIME_AT_RESIDENCE_VAR 
IQT9413 
pct_bankcar_act_op_6m 
util_gt_90_1
PIL8120  
BCA8370
BCC5620
IQB9416
;
run;
/******************************************************************************/


********************************************************************************************************************************************;
**** 2. Define "varlist" and "maxlist";
%let var_list_seg1=
BCA5430
ALX8220
TIME_AT_RESIDENCE_VAR
SSNGAP /*- Calculated from SSN_ISSUE_YR_TXT, birth_yr_nbr*/
all5020
inq_b_pc_3m /*- Calculated from IQb9415 (this is binary and will be excluded), IQB9410*/
avg_cred /*- Calculated from ALL0416, ALL5320*/
BAX3510 
/*IQA9410 - Remove as this is binary*/
;

%let var_list_seg1_var=
999999990
9990
9990
9990
999999990
9990  
999999990  
90 
/*90*/
;

%let var_list_seg2=
ALL5320  
SSNGAP /*- Calculated from SSN_ISSUE_YR_TXT, birth_yr_nbr*/
TIME_AT_RESIDENCE_VAR 
/*IQT9413 - Remove as this is binary*/
pct_bankcar_act_op_6m /*- Calculated from ALL0300, BCA0436*/
util_gt_90_1 /*- Calculated from RTR3424, BCC3424*/
PIL8120  
BCA8370
BCC5620
IQB9416
;

%let var_list_seg2_var=
999999990  
9990 
9990 
/*9990  */
90
90
9990  
9990
999999990
90
;

***************************************************************************************;
%macro fpf_sensitivity1(percent=, pct_nm=);

%sensitivity(
indata=segment_1, 
outdata=out_seg1_pct&pct_nm., 
varlist=&var_list_seg1.,
maxlist=&var_list_seg1_var., 
wt=weight,
scorefile=&scorefile., 
scorename=ponzi_scr_1st_loan,
pct=&percent, 
modelname=Segment 1, 
outprt= );

%mend fpf_sensitivity1;

%fpf_sensitivity1(percent=0.05, pct_nm=5);
%fpf_sensitivity1(percent=0.1, pct_nm=10);
%fpf_sensitivity1(percent=0.2, pct_nm=20);
***************************************************************************************;
***************************************************************************************;

%macro fpf_sensitivity2(percent=, pct_nm=);

%sensitivity(
indata=segment_2, 
outdata=out_seg2_pct&pct_nm., 
varlist=&var_list_seg2.,
maxlist=&var_list_seg2_var., 
wt=weight,
scorefile=&scorefile., 
scorename=ponzi_scr_1st_loan,
pct=&percent, 
modelname=Segment 2, 
outprt= );

%mend fpf_sensitivity2;

%fpf_sensitivity2(percent=0.05, pct_nm=5);
%fpf_sensitivity2(percent=0.1, pct_nm=10);
%fpf_sensitivity2(percent=0.2, pct_nm=20);
