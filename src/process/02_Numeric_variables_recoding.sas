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
/* Program Name:             ---  02_Numeric_variables_recoding.sas                                     */
/* Description:              ---  Use this code to convert numeric variables to Weight of Evidence   
variables                                                                                               */
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

options compress=yes dlcreatedir;

libname input "&data_path.\input";
libname numrcd "&data_path.\output\02_numeric_recoding";

%include "&macros_path.\numeric_missing.sas";
%include "&macros_path.\find_1_level_numeric.sas";
%include "&macros_path.\missing_has_1_level_join.sas";
%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\ivs_and_woe_table.sas";
%include "&macros_path.\replace_numeric_missing_values_with_mean.sas";
%include "&macros_path.\NOD_BIN_numeric_wrapper.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output2 "&log_path.\02_Numeric_variables_recoding_output_&datetime_var..log";
filename logout2 "&log_path.\02_Numeric_variables_recoding_log_&datetime_var..log";
proc printto print=output2 log=logout2 new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

%numeric_missing(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the numeric variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table = numrcd.numeric_missing /*Name of output table that will produce a summary for the missing values*/
);

%find_1_level_numeric(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the numeric variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table = numrcd.find_1_level_numeric /*Name of output table that will produce a summary for the missing values*/
);

%missing_has_1_level_join(
/*********************************************************************************/
/*Input*/
character_missing_table = numrcd.numeric_missing, /*Output table from numeric_missing macro*/
has_1_level_table = numrcd.find_1_level_numeric, /*Output table from find_1_level_numeric macro*/
argument_missing_percent = 99, /*Missing percentage threshold for selecting variables. For selecting all variables, set this to 100*/
argument_has_1_level = 0, /*Argument for selecting variables that have more than one level. Set this to 0 for selecting variables with more than 1 level*/
/*********************************************************************************/
/*Output*/
output_table = numrcd.numeric_summary /*Output table from the join*/
);

%replace_numeric_missing_values(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the numeric variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
numeric_summary = numrcd.numeric_summary, /*Name of table that contains only the numeric variables that will be in the model*/
replace_percentage = 5, /*Takes values 0-100. Replace missing values with mean for all variables that missing percentage
is below this threshold. For numeric variables with missing percentage above this threshold, the missing
values are left as missing.*/
/*********************************************************************************/
/*Output*/
output_table = numrcd.numeric_vars /*Name of table that will have the target variable, the ID variable, the weight variable and all the numeric variables that will be in the model with missing values replaced*/
);

/*********************************************************************************/
/*Select the variables that will be transformed to WOE*/
%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = numrcd.numeric_vars, /*Name of table that has the numeric variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = numeric_variables_to_analyse, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = numeric_variables_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &numeric_variables_to_analyse.;
%put %sysfunc(countw(&numeric_variables_to_analyse.));
/*********************************************************************************/

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = numrcd.Numeric_vars, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = &numeric_variables_to_analyse., /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = , /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Maximum number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = numrcd.numeric_information_value, /*Dataset with all the information values*/
woe_format_outds = numrcd.numeric_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = numrcd.numeric_vars_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);

%NOD_BIN_numeric_wrapper(
/*********************************************************************************/
/*Input*/
input_dset = numrcd.numeric_vars, /*Name of the input dataset that contains the variables we want to recode and the target variable*/
target_variable = &target_variable_name., /*Name of the target variable*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
vars_list = &numeric_variables_to_analyse., /*List of predictor variables that we want to transform to WOE*/
recoded_var_prefix = num, /*Prefix for recoded variables*/
num_groups = 30, /*Maximum number of groups we will originally split the predictor variables*/
NOD_BIN_macro = &macros_path.\NOD_BIN_v13.sas, /*Path to NOD_BIN macro*/
/*************************************************************************************/
/*Set Lund and Raimi parameters*/
RL_method = IV, /*IV (collapse maximises Information Value) or LL (collapse maximises Log likelihood)*/
RL_mode = J, /*A (all pairs of levels are compared when collapsing) or J (only adjacent pairs of levels in the ordering of X are compared when collapsing)*/
RL_miss = MISS,  /*Treat missing values for collapsing: MISS <other is noMISS> */
RL_min_pct = 5, /* space = 0 or integer 0 to 99 */
RL_min_num = , /* space = 0 or integer >= 0 */
RL_verbose = , /* YES <other is NO>: used to display the entire history of collapsing in the SUMMARY REPORT. Otherwise this history is not displayed in the SUMMARY REPORT*/
RL_ll_stat = NO, /* YES <other is NO: used to display entropy (base e), Nested_ChiSq, and the prob-value for the Nested ChiSq*/
RL_woe = NO,  /* WOE <other is NO: used to print the WOE coded transform of X for each iteration of collapsing */
RL_order = A, /* D or A: If D, then the lower value of Y is set to B and the greater value of Y is set to G. The G value is modeled. That is, G appears in the numerator of the weight-of-evidence expression. If A, then the reverse is true.*/
RL_woeadj = 0.5,  /* space = 0, or 0, or 0.5: Weight of evidence adjusted factor to deal with zero cells*/
/*********************************************************************************/
/*Output*/
output_original_recode_summary = numrcd.num_summary_recode, /*Output table that contains the original with the recoded variables summary (min, max)*/
output_recode_summary = numrcd.num_vars_recode, /*Output table that contains the code that is used to create the WOE variables from the recoded variables*/ 
output_recode_data = numrcd.num_vars_format_woe /*Output table that contains the data with the target variable with the WOE variables - this will be used for modelling*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = numrcd.num_vars_format_woe, /*Name of table that has the numeric variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = numeric_variables_woe, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = numeric_woe_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &numeric_variables_woe.;
%put %sysfunc(countw(&numeric_variables_woe.));

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = numrcd.num_vars_format_woe, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = &numeric_variables_woe., /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = , /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Maximum number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = numrcd.numeric_woe_information_value, /*Dataset with all the information values*/
woe_format_outds = numrcd.numeric_format_dataset_woe, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = numrcd.numeric_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);

proc printto;
run;





