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
/* Program Name:             ---  rescore_bootstrap_coefficients.sas									*/
/* Description:              ---  Rescore datasets using bootstrap estimates							*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro rescore_bootstrap_coefficients(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_development, /*Development data that will be used to create a logistic regression model*/
target_variable, /*Name of target variable*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
bootstrap_score_dataset, /*Dataset that contains the target variable, the weight variable and the predicted probabilities*/
GINI_outdset /*Dataset that contains the Gini coefficient*/
);

proc contents data=&predictors_coefficients_outtable.  (drop= Intercept _LNLIKE_ _LINK_ _NAME_ _STATUS_ _TYPE_) out=predictors_coefficients_c (keep= NAME) noprint;
run;
proc sql noprint;
select name into :variables_in_bootstrap_model separated by ' '
from predictors_coefficients_c
;
quit;
%put &variables_in_bootstrap_model.;
%put %sysfunc(countw(&variables_in_bootstrap_model.));

proc means data=&predictors_coefficients_outtable. noprint;
	var &variables_in_bootstrap_model.;
	output out=bootstrap_estimates_temp mean=;
run;
data bootstrap_estimates_temp;
	set bootstrap_estimates_temp;
	n = 1;
	drop _type_ _freq_;
run;

data bootstrap_estimates_last;
	set &predictors_coefficients_outtable.;
	by _LINK_;
	n = 1;
	if last._LINK_ then output;
run;

proc sql;
create table predictors_coefficients_boot (drop= n) as 
select
	t1._LINK_
	, t1._TYPE_
	, t1._STATUS_
	, t1._NAME_
	, t2.*
from bootstrap_estimates_last as t1
left join bootstrap_estimates_temp as t2
on t1.n = t2.n
;
quit;

proc score data=&modelling_data_development. score=predictors_coefficients_boot out=&bootstrap_score_dataset. type=parms;
	var &variables_in_bootstrap_model.;
run;
data &bootstrap_score_dataset.;
	set &bootstrap_score_dataset.;
	IP_1 = exp(&target_variable.2)/(1+exp(&target_variable.2));
	IP_0 = 1 - IP_1;
	keep &target_variable. &weight_variable. IP_0 IP_1;
run;

%Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob = &bootstrap_score_dataset., /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable., /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable = IP_0, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset = &GINI_outdset. /*Dataset that contains the Gini coefficient*/
);

%mend rescore_bootstrap_coefficients;
