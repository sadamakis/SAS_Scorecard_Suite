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
/* Program Name:             ---  4a_Model_building_one_sample.sas                                      */
/* Description:              ---  Build models using the one sample approach, as opposed to bootstrapping                                                                                           */
/*                                                                                                      */
/* Date Originally Created:  ---                                                                        */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/

/*********************************************************************************/
/***********   Start parameters configuration    ***************/
/*********************************************************************************/
/*Set path that contains the macros*/
%let macros_path = X:\Decision_Science\01_Model_Development\21_VBL_Cards\02_Acquisitions\VB_UKCC_AF001\Code\Productionise macros\Scorecard_suite;
/*Set path that will have the output and log files that are produced from this code*/
%let output_files = X:\Decision_Science\01_Model_Development\21_VBL_Cards\02_Acquisitions\VB_UKCC_AF001\Code\Productionise macros\Scorecard_suite\Logs;
/*Set the path that contains the table with:
 - target variable
 - weight 
 - ID variable
 - predictors (both numerical and categorical)*/
%let dmartpth = X:\Data_Mart\Analysis\Decision_Science\01_UK\Vanquis\Cards\02_Acquisitions\01_Model_Development\VB_UKCC_AF01\01_Database_Design;
/*Set the path that contains the output tables from this code*/
%let outpath = X:\Data_Mart\Analysis\Decision_Science\01_UK\Vanquis\Cards\02_Acquisitions\01_Model_Development\VB_UKCC_AF01\01_Database_Design\Productionise macros;
/*********************************************************************************/
/***********   End parameters configuration     ***************/
/*********************************************************************************/

options compress=yes;

libname dmart "&dmartpth.";
libname outdata "&outpath.";

%include "&macros_path.\logistic_regression.sas";
%include "&macros_path.\Gini_with_proc_freq.sas";
%include "&macros_path.\gini_for_set_predictors.sas";
%include "&macros_path.\roc_curve_gini_actual_vs_predctd.sas" / lrecl=1000;

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output4a "&output_files.\4a_Model_building_one_sample_output_&datetime_var..log";
filename logout4a "&output_files.\4a_Model_building_one_sample_log_&datetime_var..log";
proc printto print=output4a log=logout4a new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/*Split data to development and validation*/
proc sql;
create table outdata.Modelling_data as 
select 
	t1.*
	, t2.m_date_active 
from outdata.Numeric_vars_min_d as t1
left join dmart.Apps_201503_accnum (keep= transact_id m_date_active) as t2
on t1.transact_id = t2.transact_id
;
quit;
data outdata.Modelling_data_development (drop= m_date_active) outdata.Modelling_data_validation (drop= m_date_active);
	set outdata.Modelling_data;
	if m_date_active<='01DEC2014'd then output outdata.Modelling_data_development;
	else output outdata.Modelling_data_validation;
run;
/***********************************************************************************/

%logistic_regression(
/***********************************************************************************/
/*Input*/
modelling_data_development = outdata.Modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = outdata.Modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
model_selection_method = stepwise, /*Choose from none, stepwise, backward, forward, score*/
slentry = 0.05, /*Entry criteria for model selection method*/
slstay = 0.05, /*Stay criteria for model selection method*/
force_numeric_vars = , /*List of numeric variables, separated by space, that should be forced in the model. 
These are going to be the only numeric variables in the model. If no variables will be forced in the model, 
then leave this blank.*/ 
force_character_vars = , /*List of character variables, separated by space, that should be forced in the model. 
These are going to be the only character variables in the model. If no variables will be forced in the 
model, then leave this blank.*/
force_interactions = /*num168_woe*num170_woe num27_woe*num291_woe AcornCode_C_rcd_woe*num110_woe FraudCategory_SPA_rcd_woe*FraudCategory_SP_rcd_woe*/, /*List of interactions, separated by space, that should be forced in the model. 
If no interactions will be forced in the model, then leave this blank.*/
use_interactions = N, /*Y if 2-way interactions of ALL the variables will be used in the model*/
/***********************************************************************************/
/*Output*/
output_model = outdata.output_model, /*Dataset with the logistic regression model*/
output_coefficients = outdata.output_coefficients, /*Dataset with the coefficients from the final model*/
outtable_development_score = outdata.outtable_development_score, /*Development sample with the predicted probability*/
outtable_validation_score = outdata.outtable_validation_score, /*Validation sample with the predicted probability*/
outtable_model_build_summary = outdata.outtable_model_build_summary /*Model building summary table*/
);

%gini_for_set_predictors(
/***********************************************************************************/
/*Input*/
input_model_build_summary = outdata.outtable_model_build_summary, /*Model building summary dataset. This dataset is created when enabling 
ModelBuildingSummary option in PROC LOGISTIC*/
input_number_variables_in_model = 3, /*Number of variables that will be in the model.*/
modelling_data_development = outdata.Modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = outdata.Modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/***********************************************************************************/
/*Output*/
output_model = outdata.output_model_set, /*Dataset with the logistic regression model*/
output_coefficients = outdata.output_coefficients_set, /*Dataset with the coefficients from the final model*/
outtable_development_score = outdata.outtable_development_score_set, /*Development sample with the predicted probability*/
outtable_validation_score = outdata.outtable_validation_score_set, /*Validation sample with the predicted probability*/
outtable_gini_development = outdata.outtable_gini_development_set, /*Table that calculates the Gini coefficient for the development sample*/
outtable_gini_validation = outdata.outtable_gini_validation_set /*Table that calculates the Gini coefficient for the validation sample*/
);

%roc_curve_gini_actual_vs_predctd(
/**************************************************************************/
/*Input*/
input_dataset_prob = outdata.Outtable_development_score_set, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
score_variable = IP_1, /*Score variable should be, e.g., scorecard output or predicted probability*/
number_of_groups = 20, /*Score variable will be split in groups using PROC RANK so that actual and predicted 
probabilities will be calculated in each band. The higher the number of groups the better the Gini 
approximation, but the longer the macro will take to run.*/
/**************************************************************************/
/*Output*/
AUC_outdset = outdata.AUC_outdset, /*The dataset that has the values for the area under the curve per bin. This dataset can be 
used to plot the area under the curve. Use the following code to generate the graph:
goptions reset=all;
axis1 label=("False positive rate") order=(0 to 1 by 0.10);
axis2 label=("True positive rate") order=(0 to 1 by 0.10);
proc gplot data=&AUC_outdset.;
      symbol v=dot h=1 interpol=join;
      plot true_positive_rate*false_positive_rate / overlay haxis=axis1 vaxis=axis2;
      title "ROC curve";
run;
*/
GINI_outdset = outdata.GINI_outdset, /*Dataset that contains the Gini coefficient approximation. Trapezoidal rule is used for the approximation.*/
predicted_expected_outdset = outdata.predicted_expected_outdset /*Output dataset that contains actual and predicted bad rate per score band. 
Use the following code to produce the graph of actual vs expected bad rate per score band:
goptions reset=all;
axis1 label=("Score band") order=(0 to 10 by 1);
axis2 label=("Bad rate") order=(0 to 0.2 by 0.010);
Legend1 value=(color=blue height=1 'Actual bad rate' 'Predicted bad rate');
proc gplot data=&predicted_expected_outdset.;
	symbol v=dot h=1 interpol=join;
	plot (target_actual_prob target_predicted_prob)*sscoreband / overlay legend=legend1 haxis=axis1 vaxis=axis2;
	title "Scorecard performance";
run;
*/
);

goptions reset=all;
axis1 label=("False positive rate") order=(0 to 1 by 0.10);
axis2 label=("True positive rate") order=(0 to 1 by 0.10);
proc gplot data=outdata.AUC_outdset;
      symbol v=dot h=1 interpol=join;
      plot true_positive_rate*false_positive_rate / overlay haxis=axis1 vaxis=axis2;
      title "ROC curve";
run;

goptions reset=all;
axis1 label=("Score band") /*order=(0 to 10 by 1)*/;
axis2 label=("Bad rate") /*order=(0 to 0.01 by 0.010)*/;
Legend1 value=(color=blue height=1 'Actual bad rate' 'Predicted bad rate');
proc gplot data=outdata.predicted_expected_outdset;
	symbol v=dot h=1 interpol=join;
	plot (target_actual_prob target_predicted_prob)*sscoreband / overlay legend=legend1 haxis=axis1 vaxis=axis2;
	title "Scorecard performance";
run;
/*********************************************************************************/
/*********************************************************************************/

proc printto;
run;
