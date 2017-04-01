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
/* Program Name:             ---  05a_Bootstrapping_model_selection.sas                                  */
/* Description:              ---  Build models using bootstrap sampling.  								*/
/*                                                                                                      */
/* Date Originally Created:  ---                                                                        */
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

%include "&programPath.\99_Solution_parameter_configuration.sas";

options compress=yes;

libname outdata "&outpath.";

%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\identify_character_variables.sas";
%include "&macros_path.\Gini_with_proc_freq.sas";
%include "&macros_path.\bootstrap_model_selection_IC.sas" / lrecl=1000;
%include "&macros_path.\bootstrap_coefficients_estimate.sas";
%include "&macros_path.\plot_bootstrap_diagnostics.sas";
%include "&macros_path.\rescore_bootstrap_coefficients.sas";
%include "&macros_path.\transform_prob_to_scorecard.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output5a "&output_files.\05a_Bootstrapping_model_selection_output_&datetime_var..log";
filename logout5a "&output_files.\05a_Bootstrapping_model_selection_log_&datetime_var..log";
proc printto print=output5a log=logout5a new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/***********************************************************************************/
/*Split data to development and validation*/
proc sql;
create table outdata.Modelling_data_boot as 
select 
	t1.*
	, t2.development_flag 
from outdata.numeric_vars_min_d as t1
left join outdata.Original_table_dev_val_split as t2
on t1.transact_id = t2.transact_id
;
quit;
data outdata.Modelling_data_bt_development (drop= development_flag) outdata.Modelling_data_bt_validation (drop= development_flag);
	set outdata.Modelling_data;
	if development_flag=1 then output outdata.Modelling_data_bt_development;
	else output outdata.Modelling_data_bt_validation;
run;
/***********************************************************************************/

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = outdata.Modelling_data_bt_development, /*Name of table that has the character variables*/
target_variable = bad_flag, /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = num_variables, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = num_variables_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &num_variables.;
%put %sysfunc(countw(&num_variables.));

%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = outdata.Modelling_data_bt_development, /*Name of table that has the character variables*/
target_variable = bad_flag, /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_variables, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_variables_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put &char_variables.;

%let target_variable = bad_flag;
proc sql noprint;
select count(*) into: nlobs
from outdata.Modelling_data_bt_development
where &target_variable. = 0
;
quit;
%put &nlobs.;

%bootstrap_model_selection_IC(
/*********************************************************************************/
/*Input*/
modelling_data_development = outdata.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_validation = outdata.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model. 
LIMITATION: The table name should be up to 30 characters.*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
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
predictors_outtable_AIC = outdata.predictors_outtable_AIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on AIC*/
predictors_outtable_BIC = outdata.predictors_outtable_BIC, /*Table that stores the variables' summary, i.e. how many times they were 
entered in the model, based on BIC*/
summary_outtable_AIC = outdata.summary_outtable_AIC, /*Table that stores the AIC summary*/
summary_outtable_BIC = outdata.summary_outtable_BIC, /*Table that stores the BIC summary*/
gini_outtable_development_AIC = outdata.gini_outtable_development_AIC, /*Table that stores the Gini coefficients for the development sample using
AIC as the model selection criterion*/
gini_outtable_validation_AIC = outdata.gini_outtable_validation_AIC, /*Table that stores the Gini coefficients for the validation sample using
AIC as the model selection criterion*/
gini_outtable_development_BIC = outdata.gini_outtable_development_BIC, /*Table that stores the Gini coefficients for the development sample using
BIC as the model selection criterion*/
gini_outtable_validation_BIC = outdata.gini_outtable_validation_BIC, /*Table that stores the Gini coefficients for the validation sample using
BIC as the model selection criterion*/
KS_outtable_development_AIC = outdata.KS_outtable_development_AIC, /*Table that stores the KS statistics for the development sample using
AIC as the model selection criterion*/
KS_outtable_validation_AIC = outdata.KS_outtable_validation_AIC, /*Table that stores the KS statistics for the validation sample using
AIC as the model selection criterion*/
KS_outtable_development_BIC = outdata.KS_outtable_development_BIC, /*Table that stores the KS statistics for the development sample using
BIC as the model selection criterion*/
KS_outtable_validation_BIC = outdata.KS_outtable_validation_BIC /*Table that stores the KS statistics for the validation sample using
BIC as the model selection criterion*/
);

/*Select numeric variables that will go in the model*/
proc sql noprint;
select _name_ into: predictors_in_the_model separated by ' '
from outdata.predictors_outtable_BIC
where average_IC>=60
;
quit;
%put &predictors_in_the_model.;
%put %sysfunc(countw(&predictors_in_the_model.));

/*Once the variables in the model have been defined, we can use bootstrapping to finalise the coefficient estimates*/
%bootstrap_coefficients_estimate(
/*********************************************************************************/
/*Input*/
modelling_data_development = outdata.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = outdata.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be weight, 
as this name is reserved in the macro*/
varlist_cont = &predictors_in_the_model., /*List of continuous variables that will go in the model*/
varlist_disc = , /*List of categorical variables that will go in the model*/
nboots = 5, /*Number of bootstrap samples*/
sampling_method = urs, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize = &nlobs., /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_coefficients_outtable = outdata.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
gini_outtable_development = outdata.gini_outtable_development, /*Table that stores the Gini coefficients for the development sample*/
gini_outtable_validation = outdata.gini_outtable_validation, /*Table that stores the Gini coefficients for the development sample*/
KS_outtable_development = outdata.KS_outtable_development, /*Table that stores the KS statistics for the development sample*/
KS_outtable_validation = outdata.KS_outtable_validation /*Table that stores the KS statistics for the validation sample*/
);

/*Plot bootstrap diagnostics*/
%plot_bootstrap_diagnostics(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = outdata.predictors_coeffcnts_smmry /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
);

/*Compare the folloowing two models:
	- Coefficients averaged over the bootstrap samples
	- Coefficients obtained when running logistic regression with the same predictors, but without bootstrapping*/
%rescore_bootstrap_coefficients(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = outdata.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_development = outdata.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
target_variable = bad_flag, /*Name of target variable*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
bootstrap_score_dataset = outdata.bootstrap_score_dataset_dev, /*Dataset that contains the target variable, the weight variable and the predicted probabilities*/
GINI_outdset = outdata.bootstrap_GINI_dev /*Dataset that contains the Gini coefficient*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = outdata.bootstrap_score_dataset_dev, /*Input dataset that has the estimated 
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
output_score_dataset = outdata.bootstrap_score_dev /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

%rescore_bootstrap_coefficients(
/*********************************************************************************/
/*Input*/
predictors_coefficients_outtable = outdata.predictors_coeffcnts_smmry, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
modelling_data_development = outdata.Modelling_data_bt_validation, /*Development data that will be used to create a logistic regression model*/
target_variable = bad_flag, /*Name of target variable*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
bootstrap_score_dataset = outdata.bootstrap_score_dataset_val, /*Dataset that contains the target variable, the weight variable and the predicted probabilities*/
GINI_outdset = outdata.bootstrap_GINI_val /*Dataset that contains the Gini coefficient*/
);

%transform_prob_to_scorecard(
/*********************************************************************************/
/*Input*/
input_pred_prob_dataset = outdata.bootstrap_score_dataset_val, /*Input dataset that has the estimated 
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
output_score_dataset = outdata.bootstrap_score_val /*Output dataset that has the computated
scorecard value. The name of the new field is "scorecard".*/
);

%bootstrap_coefficients_estimate(
/*********************************************************************************/
/*Input*/
modelling_data_development = outdata.Modelling_data_bt_development, /*Development data that will be used to create a logistic regression model*/
modelling_data_validation = outdata.Modelling_data_bt_validation, /*Validation data that will be used to validate the logistic regression model*/
target_variable = bad_flag,  /*Name of target variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row. This should not be weight, 
as this name is reserved in the macro*/
varlist_cont = &predictors_in_the_model., /*List of continuous variables that will go in the model*/
varlist_disc = , /*List of categorical variables that will go in the model*/
nboots = 1, /*Number of bootstrap samples*/
sampling_method = srs, /*srs or urs: sampling method for bootstrapping. srs for simple random selection 
(no replacement), urs for random selection with replacement*/
bootsize = &nlobs., /*Bootstrap sample for 'goods'. In credit risk and fraud the 'bad flag' is undersampled. The bootstrap 
sample selects all the bads and &bootsize. number of goods. This is to decrease the running time of the algorithm, 
which can be very long - typically each bootstrap sample with ~300 variables takes about ~30 mins*/
/*********************************************************************************/
/*Output*/
predictors_coefficients_outtable = outdata.predictors_cffcnts_smmry_one, /*Table that stores the predictor coefficients for each bootstrap sample.
LIMITATION: The table name should be up to 30 characters.*/
gini_outtable_development = outdata.gini_outtable_development_one, /*Table that stores the Gini coefficients for the development sample*/
gini_outtable_validation = outdata.gini_outtable_validation_one, /*Table that stores the Gini coefficients for the development sample*/
KS_outtable_development = outdata.KS_outtable_development_one, /*Table that stores the KS statistics for the development sample*/
KS_outtable_validation = outdata.KS_outtable_validation_one /*Table that stores the KS statistics for the validation sample*/
);
/*********************************************************************************/
/*********************************************************************************/

proc printto;
run;






