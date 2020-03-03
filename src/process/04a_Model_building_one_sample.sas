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
/* Program Name:             ---  04a_Model_building_one_sample.sas                                     */
/* Description:              ---  Build models using the one sample approach, as opposed to bootstrapping                                                                                           */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/

/*Macro that stores the name and the path of the current program into macro variables*/
%macro program
(
/*********************************************************************************/
/*Output*/
progName, /*Macro variable the contains the SAS file name*/
progPath /*Macro variable that contains the path where the SAS file is stored*/
);
%global &progName. &progPath.;

    %let progPathName = %sysfunc(GetOption(SysIn));
    %* if running in interactive mode, the above line will not work, and the next line should;
    %if  %length(&progPathName) = 0 %then %let progPathName = %sysget(SAS_ExecFilePath);

	%let &progName. = %scan(&progPathName., -1, '\');
	%let progColumn = %eval(%index(&progPathName., &&&progName..)-2);
	%let &progPath. = %substr(&progPathName., 1, &progColumn.);

%mend program;
%program
(
/*********************************************************************************/
/*Output*/
progName = programName, /*Macro variable the contains the SAS file name*/
progPath = programPath /*Macro variable that contains the path where the SAS file is stored*/
);

%include "&programPath.\000_Solution_parameter_configuration.sas";

options compress=yes;

libname input "&data_path.\input";
libname output "&data_path.\output";

%include "&macros_path.\logistic_regression.sas";
%include "&macros_path.\Gini_with_proc_freq.sas";
%include "&macros_path.\logloss.sas";
%include "&macros_path.\gini_for_set_predictors.sas";
%include "&macros_path.\roc_curve_gini_actual_vs_predctd.sas" / lrecl=1000;
%include "&macros_path.\transform_prob_to_scorecard.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output4a "&log_path.\04a_Model_building_one_sample_output_&datetime_var..log";
filename logout4a "&log_path.\04a_Model_building_one_sample_log_&datetime_var..log";
proc printto print=output4a log=logout4a new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/***********************************************************************************/
/*Split data to development and validation*/
proc sql;
create table output.Modelling_data as 
select 
	t1.*
	, t2.development_flag 
from output.char_convert_vars_woe_char as t1
left join &table_name._dev_val_split as t2
on t1.&ID_variable_name. = t2.&ID_variable_name.
;
quit;
data output.Modelling_data_development (drop= development_flag) output.Modelling_data_validation (drop= development_flag);
	set output.Modelling_data;
	if development_flag=1 then output output.Modelling_data_development;
	else output output.Modelling_data_validation;
run;
/***********************************************************************************/

%logistic_regression(
/***********************************************************************************/
/*Input*/
modelling_data_development = output.Modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = output.Modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
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
output_model = output.output_model, /*Dataset with the logistic regression model*/
output_coefficients = output.output_coefficients, /*Dataset with the coefficients from the final model*/
outtable_development_score = output.outtable_development_score, /*Development sample with the predicted probability*/
outtable_validation_score = output.outtable_validation_score, /*Validation sample with the predicted probability*/
outtable_model_build_summary = output.outtable_model_build_summary /*Model building summary table*/
);

%gini_for_set_predictors(
/***********************************************************************************/
/*Input*/
input_model_build_summary = output.outtable_model_build_summary, /*Model building summary dataset. This dataset is created when enabling 
ModelBuildingSummary option in PROC LOGISTIC*/
input_number_variables_in_model = 3, /*Number of variables that will be in the model.*/
modelling_data_development = output.Modelling_data_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = output.Modelling_data_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/***********************************************************************************/
/*Output*/
output_model = output.output_model_set, /*Dataset with the logistic regression model*/
output_coefficients = output.output_coefficients_set, /*Dataset with the coefficients from the final model*/
outtable_development_score = output.outtable_development_score_set, /*Development sample with the predicted probability*/
outtable_validation_score = output.outtable_validation_score_set, /*Validation sample with the predicted probability*/
outtable_gini_development = output.outtable_gini_development_set, /*Table that calculates the Gini coefficient for the development sample*/
outtable_gini_validation = output.outtable_gini_validation_set /*Table that calculates the Gini coefficient for the validation sample*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = output.outtable_development_score_set, /*Input dataset that has the estimated 
probability.*/
probability_variable = IP_1, /*Variable that has the probabilities for the outcome*/
odds = 30, /*Specifies the Non-Event/Event odds that correspond to the score value that you 
specify in the Scorecard Points property.*/
scorecard_points = 600, /*Specifies a score that is associated with the odds that are specified in 
the Odds property. For example, if you use the default values of 200 and 50 for the Odds, a score of 
200 represents odds of 50 to 1 (that is P(Non-Event)/P(Event)=50).*/
point_double_odds = 20, /*Increase in score points that generates the score that corresponds to 
twice the odds.*/
reverse_scorecard = 1, /*Specifies whether the generated scorecard points should be reversed. 
Set to 0 if the higher the event rate the higher the score, and set to 1 if the higher the event rate 
the lower the score.*/
/*********************************************************************************/
/*Output*/
output_score_dataset = output.outtable_development_score_table /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = output.Outtable_validation_score_set, /*Input dataset that has the estimated 
probability.*/
probability_variable = P_1, /*Variable that has the probabilities for the outcome*/
odds = 30, /*Specifies the Non-Event/Event odds that correspond to the score value that you 
specify in the Scorecard Points property.*/
scorecard_points = 600, /*Specifies a score that is associated with the odds that are specified in 
the Odds property. For example, if you use the default values of 200 and 50 for the Odds, a score of 
200 represents odds of 50 to 1 (that is P(Non-Event)/P(Event)=50).*/
point_double_odds = 20, /*Increase in score points that generates the score that corresponds to 
twice the odds.*/
reverse_scorecard = 1, /*Specifies whether the generated scorecard points should be reversed. 
Set to 0 if the higher the event rate the higher the score, and set to 1 if the higher the event rate 
the lower the score.*/
/*********************************************************************************/
/*Output*/
output_score_dataset = output.outtable_validation_score_table /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

%roc_curve_gini_actual_vs_predctd(
/**************************************************************************/
/*Input*/
input_dataset_prob = output.Outtable_development_score_table, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset*/
score_variable = IP_1, /*Score variable should be, e.g., scorecard output or predicted probability*/
number_of_groups = 20, /*Score variable will be split in groups using PROC RANK so that actual and predicted 
probabilities will be calculated in each band. The higher the number of groups the better the Gini 
approximation, but the longer the macro will take to run.*/
/**************************************************************************/
/*Output*/
AUC_outdset = output.AUC_outdset, /*The dataset that has the values for the area under the curve per bin. This dataset can be 
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
GINI_outdset = output.GINI_outdset, /*Dataset that contains the Gini coefficient approximation. Trapezoidal rule is used for the approximation.*/
predicted_expected_outdset = output.predicted_expected_outdset, /*Output dataset that contains actual and predicted bad rate per score band. 
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
lift_curve_dataset = output.lift_curve_dataset /*Output dataset that will be used to produce the lift curves*/
);

goptions reset=all;
axis1 label=("False Positive Rate") order=(0 to 1 by 0.10);
axis2 label=("True Positive Rate") order=(0 to 1 by 0.10);
proc gplot data=output.AUC_outdset;
      symbol v=dot h=1 interpol=join;
      plot true_positive_rate*false_positive_rate / overlay haxis=axis1 vaxis=axis2;
      title "ROC Curve";
run;
goptions reset=all;

goptions reset=all;
axis1 label=("Score Band") /*order=(0 to 10 by 1)*/;
axis2 label=("Bad Rate") /*order=(0 to 0.01 by 0.010)*/;
Legend1 value=(color=blue height=1 'Actual bad rate' 'Predicted bad rate');
proc gplot data=output.predicted_expected_outdset;
	symbol v=dot h=1 interpol=join;
	plot (target_actual_prob target_predicted_prob)*sscoreband / overlay legend=legend1 haxis=axis1 vaxis=axis2;
	title "Scorecard Performance";
run;
goptions reset=all;

goptions reset=all;
axis1 label=("Score Band");
axis2 label=("Lift");
proc gplot data=output.Lift_curve_dataset;
      symbol v=dot h=1 interpol=join;
      plot lift*reversed_n / overlay haxis=axis1 vaxis=axis2;
      title "Lift Curve";
run;
goptions reset=all;

goptions reset=all;
axis1 label=("Score Band");
axis2 label=("Cumulative Lift");
proc gplot data=output.Lift_curve_dataset;
      symbol v=dot h=1 interpol=join;
      plot cumulative_lift*reversed_n / overlay haxis=axis1 vaxis=axis2;
      title "Cumulative Lift Curve";
run;
goptions reset=all;

/*********************************************************************************/
/*********************************************************************************/

proc printto;
run;
