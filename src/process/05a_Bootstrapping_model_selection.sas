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
/* Program Name:             ---  05a_Bootstrapping_model_selection.sas                                 */
/* Description:              ---  Build models using bootstrap sampling.  								*/
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

%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\identify_character_variables.sas";
%include "&macros_path.\Gini_with_proc_freq.sas";
%include "&macros_path.\logloss.sas";
%include "&macros_path.\bootstrap_model_selection_IC.sas" / lrecl=1000;
%include "&macros_path.\bootstrap_coefficients_estimate.sas";
%include "&macros_path.\plot_bootstrap_diagnostics.sas";
%include "&macros_path.\character_to_binary_transreg.sas";
%include "&macros_path.\rescore_bootstrap_coefficients.sas";
%include "&macros_path.\transform_prob_to_scorecard.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output5a "&log_path.\05a_Bootstrapping_model_selection_output_&datetime_var..log";
filename logout5a "&log_path.\05a_Bootstrapping_model_selection_log_&datetime_var..log";
proc printto print=output5a log=logout5a new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/***********************************************************************************/
/*Split data to development and validation*/
proc sql;
create table output.Modelling_data_boot as 
select 
	t1.*
	, t2.development_flag 
from output.char_convert_vars_woe_char as t1
left join &table_name._dev_val_split as t2
on t1.&ID_variable_name. = t2.&ID_variable_name.
;
quit;
data output.Modelling_data_bt_development (drop= development_flag) output.Modelling_data_bt_validation (drop= development_flag);
	set output.Modelling_data;
	if development_flag=1 then output output.Modelling_data_bt_development;
	else output output.Modelling_data_bt_validation;
run;
/***********************************************************************************/

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = output.Modelling_data_bt_development, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = num_variables, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = num_variables_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &num_variables.;

%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = output.Modelling_data_bt_development, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_variables, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_variables_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put &char_variables.;

proc sql noprint;
select count(*) into: nlobs
from output.Modelling_data_bt_development
where &target_variable_name. = 0
;
quit;
%put &nlobs.;

%bootstrap_model_selection_IC(
/*********************************************************************************/
/*Input*/
modelling_data_development = output.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_validation = output.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model. 
LIMITATION: The table name should be up to 30 characters.*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be weight, 
as this name is reserved in the macro*/
varlist_cont = &num_variables., /*List of continuous variables that will go in the model*/
varlist_disc = &char_variables., /*List of categorical variables that will go in the model*/
nboots = 5, /*Number of bootstrap samples*/
sampling_method = urs, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize = &nlobs., /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_outtable_AIC = output.predictors_outtable_AIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on AIC*/
predictors_outtable_BIC = output.predictors_outtable_BIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on BIC*/
summary_outtable_AIC = output.summary_outtable_AIC, /*Table that stores the AIC summary*/
summary_outtable_BIC = output.summary_outtable_BIC, /*Table that stores the BIC summary*/
metrics_outtable_development_AIC = output.metrics_outtable_development_AIC, /*Table that stores the model metrics for the development sample using
AIC as the model selection criterion, e.g. Gini coefficients, log-losses, KS statistics*/
metrics_outtable_validation_AIC = output.metrics_outtable_validation_AIC, /*Table that stores the model metrics for the validation sample using
AIC as the model selection criterion, e.g. Gini coefficients, log-losses, KS statistics*/
metrics_outtable_development_BIC = output.metrics_outtable_development_BIC, /*Table that stores the model metrics for the development sample using
BIC as the model selection criterion, e.g. Gini coefficients, log-losses, KS statistics*/
metrics_outtable_validation_BIC = output.metrics_outtable_validation_BIC /*Table that stores the model metrics for the validation sample using
BIC as the model selection criterion, e.g. Gini coefficients, log-losses, KS statistics*/
);

/*Select variables that will go in the model*/
%let num_predictors_in_the_model=;
proc sql noprint;
select _name_ into: num_predictors_in_the_model separated by ' '
from output.predictors_outtable_AIC as t1
inner join num_variables_contents as t2
on t1._name_ = t2.NAME
where t1.average_IC>=60
;
quit;
%put &num_predictors_in_the_model.;
%let char_predictors_in_the_model=;
proc sql noprint;
select _name_ into: char_predictors_in_the_model separated by ' '
from output.predictors_outtable_AIC as t1
inner join char_variables_contents as t2
on t1._name_ = t2.NAME
where t1.average_IC>=60
;
quit;
%put &char_predictors_in_the_model.;

/*Once the variables in the model have been defined, we can use bootstrapping to finalise the coefficient estimates*/
%bootstrap_coefficients_estimate(
/*********************************************************************************/
/*Input*/
modelling_data_development = output.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = output.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be weight, 
as this name is reserved in the macro*/
varlist_cont = &num_predictors_in_the_model., /*List of continuous variables that will go in the model*/
varlist_disc = &char_predictors_in_the_model., /*List of categorical variables that will go in the model*/
nboots = 5, /*Number of bootstrap samples*/
sampling_method = urs, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize = &nlobs., /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_coefficients_outtable = output.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
metrics_outtable_development = output.metrics_outtable_development, /*Table that stores model metrics for the development sample, e.g. the Gini coefficients, log-losses, KS statistics*/
metrics_outtable_validation =  output.metrics_outtable_validation /*Table that stores model metrics for the validation sample, e.g. the Gini coefficients, log-losses, KS statistics*/
);

/*Plot bootstrap diagnostics*/
%plot_bootstrap_diagnostics(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = output.predictors_coeffcnts_smmry /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
);

/*Otherwise we can do the same analysis without bootstrapping*/
%bootstrap_coefficients_estimate(
/*********************************************************************************/
/*Input*/
modelling_data_development = output.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = output.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = &target_variable_name.,  /*Name of target variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be weight, 
as this name is reserved in the macro*/
varlist_cont = &num_predictors_in_the_model., /*List of continuous variables that will go in the model*/
varlist_disc = &char_predictors_in_the_model., /*List of categorical variables that will go in the model*/
nboots = 1, /*Number of bootstrap samples*/
sampling_method = srs, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize = &nlobs., /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_coefficients_outtable = output.predictors_cffcnts_smmry_one, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
metrics_outtable_development = output.metrics_outtable_development_one, /*Table that stores model metrics for the development sample, e.g. the Gini coefficients, log-losses, KS statistics*/
metrics_outtable_validation =  output.metrics_outtable_validation_one /*Table that stores model metrics for the validation sample, e.g. the Gini coefficients, log-losses, KS statistics*/
);

/*Compare the folloowing two models:
	- Coefficients averaged over the bootstrap samples
	- Coefficients obtained when running logistic regression with the same predictors, but without bootstrapping*/
%rescore_bootstrap_coefficients(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = output.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_development = output.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
target_variable = &target_variable_name., /*Name of target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
varlist_disc = &char_predictors_in_the_model., /*List of categorical variables that will go in the model*/
/*********************************************************************************/
/*Output*/
bootstrap_score_dataset = output.bootstrap_score_dataset_dev, /*Dataset that contains the target variable, the weight variable and the predicted probabilities*/
metrics_outdset = output.bootstrap_metrics_dev /*Dataset that contains the model metrics, e.g. Gini coefficient, log-loss*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = output.bootstrap_score_dataset_dev, /*Input dataset that has the estimated 
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
output_score_dataset = output.bootstrap_score_dev /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

%rescore_bootstrap_coefficients(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = output.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_development = output.Modelling_data_bt_validation, /*Development data that will be used to create a logistic regression model*/
target_variable = &target_variable_name., /*Name of target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
varlist_disc = &char_predictors_in_the_model., /*List of categorical variables that will go in the model*/
/*********************************************************************************/
/*Output*/
bootstrap_score_dataset = output.bootstrap_score_dataset_val, /*Dataset that contains the target variable, the weight variable and the predicted probabilities*/
metrics_outdset = output.bootstrap_metrics_val /*Dataset that contains the model metrics, e.g. Gini coefficient, log-loss*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = output.bootstrap_score_dataset_val, /*Input dataset that has the estimated 
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
output_score_dataset = output.bootstrap_score_val /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

/*******************************************************************************************************************/
/*******************************************************************************************************************/

proc printto;
run;






