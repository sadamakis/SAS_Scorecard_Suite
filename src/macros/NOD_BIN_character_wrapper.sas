/* Disclaimer
Coyright (C), Sotirios Adamakis
This software may be used, copied, or redistributed only with the permission of Sotirios Adamakis. 
If used, copied, or redistributed it should not be sold and this copyright notice should be reproduced 
on each copy made. All code in this document is provided "as is" by Sotirios Adamakis without warranty 
of any kind, either express or implied, including but not limited to the implied warranties of 
merchantability and fitness for a particular purpose. Recipients acknowledge and agree that 
Sotirios Adamakis shall not be liable for any damages whatsoever arising out of their use of this 
material. In addition, Sotirios Adamakis will provide no support for the materials contained herein.
*/
/*------------------------------------------------------------------------------------------------------*/
/* Author:                   ---  Sotirios Adamakis                                                     */
/* Program Name:             ---  NOD_BIN_character_wrapper.sas											*/ 
/* Description:              ---  Macro that wraps around Lund and Raimi's NOD_BIN.sas macro taken from 
Lund and Raimi paper (Collapsing Levels of Predictor Variables for Logistic Regression and Weight of 
Evidence Coding, http://www.mwsug.org/proceedings/2012/SA/MWSUG-2012-SA03.pdf). This macro addresses 
character variables and collapses levels and produces Weight of Evidence transformed variables.			*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro NOD_BIN_character_wrapper(
/*********************************************************************************/
/*Input*/
input_dset = , /*Name of the input dataset that contains the variables we want to recode and the target variable*/
target_variable = , /*Name of the target variable*/
id_variable = , /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = , /*Name of weight variable in the input dataset. This should exist in the dataset.*/
vars_list = , /*List of predictor variables that we want to transform to WOE*/
recoded_var_prefix = , /*Prefix for recoded variables*/
NOD_BIN_macro = , /*NOD_BIN macro name with path*/
/*************************************************************************************/
/*Set Lund and Raimi parameters*/
RL_method = , /*IV (collapse maximises Information Value) or LL (collapse maximises Log likelihood)*/
RL_mode = , /*A (all pairs of levels are compared when collapsing) or J (only adjacent pairs of levels in the ordering of X are compared when collapsing)*/
RL_miss = ,  /*Treat missing values for collapsing: MISS <other is noMISS> */
RL_min_pct = , /* space = 0 or integer 0 to 99 */
RL_min_num = , /* space = 0 or integer >= 0 */
RL_verbose = , /* YES <other is NO>: used to display the entire history of collapsing in the SUMMARY REPORT. Otherwise this history is not displayed in the SUMMARY REPORT*/
RL_ll_stat = , /* YES <other is NO: used to display entropy (base e), Nested_ChiSq, and the prob-value for the Nested ChiSq*/
RL_woe = ,  /* WOE <other is NO: used to print the WOE coded transform of X for each iteration of collapsing */
RL_order = , /* D or A: If D, then the lower value of Y is set to B and the greater value of Y is set to G. The G value is modeled. That is, G appears in the numerator of the weight-of-evidence expression. If A, then the reverse is true.*/
RL_woeadj = ,  /* space = 0, or 0, or 0.5: Weight of evidence adjusted factor to deal with zero cells*/
/*********************************************************************************/
/*Output*/
output_original_recode_summary = , /*Output table that contains the original with the recoded variables summary (min, max)*/
output_recode_summary = , /*Output table that contains the code that is used to create the WOE variables from the recoded variables*/ 
output_recode_data = /*Output table that contains the data with the target variable with the WOE variables - this will be used for modelling*/
);

%include "&NOD_BIN_macro.";

%let varnum = %sysfunc(countw(&vars_list.));

data input_table (drop = rnd reps);
	set &input_dset.;
	rnd = round(&weight_variable.);
	do reps = 1 to rnd;
		output;
	end;
run;

%do i = 1 %to &varnum.;
%let current_variable = %scan(&vars_list.,&i.);;

%if &i. = 1 %then %do;
data &output_original_recode_summary.;
format original_variable $32. recoded_variable $32.;
	original_variable = "&current_variable.";
	recoded_variable = "&recoded_var_prefix.&i.";
run;
%end;
%else %do;
data recode_summary_temp;
format original_variable $32. recoded_variable $32.;
	original_variable = "&current_variable.";
	recoded_variable = "&recoded_var_prefix.&i.";
run;
proc append base=&output_original_recode_summary. data=recode_summary_temp force;
run;
%end;

%end;

proc sql noprint;
select original_variable, recoded_variable into :temp_curr_variable separated by ' ', 
:temp_recoded_variable separated by ' '
from &output_original_recode_summary.
;
quit;
%put &temp_curr_variable.;
%put &temp_recoded_variable.;

data rank1 (drop=
%do i = 1 %to &varnum.;
%scan(&temp_curr_variable., &i.) 
%end;
);
	set input_table (keep= &target_variable. &id_variable. &weight_variable. &vars_list.);
%do i = 1 %to &varnum.;
/*%scan(&temp_recoded_variable., &i.) = compress(compress(compress(compress(compress(%scan(&temp_curr_variable., &i.)), ","), "."), "%"), "!");*/
%scan(&temp_recoded_variable., &i.) = compress(compress(compress(%scan(&temp_curr_variable., &i.)), ","), "!");
%end;
run;

/************************************************************************************************/
/*Loop across all variables in the list*/
%do iter=1 %to &varnum.;
%let currvar = %scan(&temp_recoded_variable.,&iter.);
%put The variable analysed is &currvar.;

%NOD_BIN(
DATASET =  rank1, /*Input dataset that contains the target and the predictor we want to collapse*/
X =  &currvar., /*Name of the predictor we want to collapse*/
Y =  &target_variable., /*Name of the target variable*/
W =  1,  /*Weight variable. If no weights, then use 1*/
METHOD =  &RL_method.,  /*IV (collapse maximises Information Value) or LL (collapse maximises Log likelihood)*/
MODE =  &RL_mode.,  /*A (all pairs of levels are compared when collapsing) or J (only adjacent pairs of levels in the ordering of X are compared when collapsing)*/
MISS =  &RL_miss.,   /*Treat missing values for collapsing: MISS <other is noMISS> */
MIN_PCT = &RL_min_pct. , /* space = 0 or integer 0 to 99 */
MIN_NUM = &RL_min_num. , /* space = 0 or integer >= 0 */
VERBOSE = &RL_verbose. , /* YES <other is NO>: used to display the entire history of collapsing in the SUMMARY REPORT. Otherwise this history is not displayed in the SUMMARY REPORT*/
LL_STAT = &RL_ll_stat., /* YES <other is NO: used to display entropy (base e), Nested_ChiSq, and the prob-value for the Nested ChiSq*/
WOE = &RL_woe.,   /* WOE <other is NO: used to print the WOE coded transform of X for each iteration of collapsing */
ORDER = &RL_order., /* D or A */
WOEADJ = &RL_woeadj.  /* space = 0, or 0, or 0.5 */
);

proc sort data=denorm (where=(Forced_Lag ne 'NO')) out=denorm_s;
	by descending k;
run;
data _null_;
	set denorm_s;
	call symput('max_k', k);
run;
%put &max_k.;
data denorm_selected;
	set denorm;
	where k<=&max_k.;
run;
/*Select the step that maximises the IV*/
%let sort_by = IV;
proc sort data=denorm_selected out=denorm_selected_s;
	by &sort_by.;
run;
data _null_;
	set denorm_selected_s;
	call symput('k', strip(k));
run;

%if &iter. = 1 %then %do;
data &output_recode_summary.;
format variable $32.;
	set ___&currvar._woe&k.;
	variable = "&recoded_var_prefix.&iter.";
run;
%end;
%else %do;
data recode_temp;
format variable $32.;
	set ___&currvar._woe&k.;
	variable = "&recoded_var_prefix.&iter.";
run;
proc append base=&output_recode_summary. data=recode_temp force;
run;
%end;

%end;

/*Create a new dataset with all the recoded variables*/
proc sort data=&output_recode_summary. out=&output_recode_summary._s nodupkey;
	by variable;
run;
data _null_;
	set &output_recode_summary._s;
	call symput ('n_woe_variables', _n_);
run;
%put &n_woe_variables.;
%do i = 1 %to &n_woe_variables.;
data _null_;
	set &output_recode_summary._s;
	if _n_=&i. then call symput ("woe_variable_&i.", cats(variable,'_woe'));
run;
%put &&woe_variable_&i..;
%end;

data _null_;
	set &output_recode_summary.;
	call symput ('n_recode', _n_);
run;
%put &n_recode.;
%do i = 1 %to &n_recode.;
data _null_;
	set &output_recode_summary.;
	if _n_=&i. then call symput ("recode_&i.", all_code);
run;
%put &&recode_&i..;
%end;

data rank_temp (keep= &target_variable. &id_variable. 
	%do i = 1 %to &n_woe_variables.;
	&&woe_variable_&i..
	%end;
);
	set rank1;
	%do i = 1 %to &n_recode.;
	&&recode_&i..
	%end;
run;

proc sort data=rank_temp out=rank_temp_dst NODUPKEY;
	by &id_variable.;
run;

proc sql;
create table &output_recode_data. as 
select distinct
	t1.&target_variable.
	, t1.&id_variable. 
	, t1.&weight_variable.
	%do i = 1 %to &n_woe_variables.;
	, t2.&&woe_variable_&i..
	%end;
from &input_dset. as t1
left join rank_temp_dst as t2
on t1.&id_variable. = t2.&id_variable.
;
quit;

proc sql noprint;
	drop table &output_recode_summary._s;
quit;

%mend NOD_BIN_character_wrapper;


