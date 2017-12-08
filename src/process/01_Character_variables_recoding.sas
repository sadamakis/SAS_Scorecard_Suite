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
/* Program Name:             ---  01_Character_variables_recoding.sas                                   */
/* Description:              ---  Use this code to convert character variables to Weight of Evidence 
variables  																					            */
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

%include "&macros_path.\character_missing.sas";
%include "&macros_path.\find_1_level_chars.sas";
%include "&macros_path.\missing_has_1_level_join.sas";
%include "&macros_path.\replace_character_missing_values.sas";
%include "&macros_path.\number_of_levels.sas";
%include "&macros_path.\drop_char_vars_with_many_levels.sas";
%include "&macros_path.\recode_character_variables.sas";
%include "&macros_path.\merge_two_tables.sas";
%include "&macros_path.\change_character_lengths.sas";
%include "&macros_path.\identify_character_variables.sas";
%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\NOD_BIN_character_wrapper.sas";
%include "&macros_path.\check_number_of_rows.sas";
%include "&macros_path.\green.sas";
%include "&macros_path.\run_green_wrapper.sas";
%include "&macros_path.\ivs_and_woe_table.sas";
%include "&macros_path.\character_to_binary_transreg.sas";
%include "&macros_path.\convert_numeric_to_character.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output1 "&log_path.\01_Character_variables_recoding_output_&datetime_var..log";
filename logout1 "&log_path.\01_Character_variables_recoding_log_&datetime_var..log";
proc printto print=output1 log=logout1 new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

%character_missing(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table = output.character_missing /*Name of output table that will produce a summary for the missing values*/
);

%find_1_level_chars(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table = output.find_1_level_chars /*Name of output table that will produce a summary for the missing values*/
);

%missing_has_1_level_join(
/*********************************************************************************/
/*Input*/
character_missing_table = output.character_missing, /*Output table from character_missing macro*/
has_1_level_table = output.find_1_level_chars, /*Output table from find_1_level_chars macro*/
argument_missing_percent = 99, /*Missing percentage threshold for selecting variables. For selecting all variables, set this to 100*/
argument_has_1_level = 0, /*Argument for selecting variables that have more than one level. Set this to 0 for selecting variables with more than 1 level*/
/*********************************************************************************/
/*Output*/
output_table = output.character_summary /*Output table from the join*/
);

%replace_character_missing_values(
/*********************************************************************************/
/*Input*/
input_table = &table_name., /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
character_summary = output.character_summary, /*Name of table that contains only the character variables that will be in the model*/
argument_missing_value_replace = M, /*Character that the missing values will be replaced with*/
/*********************************************************************************/
/*Output*/
output_table = output.character_vars_recode /*Name of table that will have the target variable, the ID variable, the weight variable and all the character variables that will be in the model with missing values replaced*/
);

/*********************************************************************************/
/*Select the variables that will be transformed to WOE*/
%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = output.character_vars_recode, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_var_levels, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_var_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put The variables that will be transformed to WOE are: &char_var_levels.;
%put %sysfunc(countw(&char_var_levels.)) variables will be transformed to WOE.;
/*********************************************************************************/

%number_of_levels(
/**************************************************************************/
/*Input*/
input_table = output.character_vars_recode, /*Table that has the variables the variables that we would like to check the number of levels*/
list_of_variables = &char_var_levels., /*List of variables of which the number of levels will be produced*/
/**************************************************************************/
/*Output*/
output_format_table = output.format_char_levels, /*Table that contains the format information*/
outtable_num_levels = output.number_of_levels /*Summary table with all the variables that will be checked and the number of levels*/
);


/**************************************************************************/
/**************************************************************************/
/* User-amendable part: If there are predictors with a high number of
levels, e.g. postal code, then fix this to continue. The default setting 
drops variables with more than 100 levels. If there are variables with many levels
that the user wants to keep, then it is advisable to recode these variables
at this stage.*/
%drop_char_vars_with_many_levels(
/*********************************************************************************/
/*Input*/
input_table = output.character_vars_recode, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
intable_num_levels = output.number_of_levels, /*Summary table with all the variables that will be checked and the number of levels*/
n_levels_thres = 100, /*Discard variables that have more levels than this threshold (exclusive)*/
/*********************************************************************************/
/*Output*/
output_table = output.character_vars_recode /*Name of output table that has predictors with acceptable number of levels*/
);
/**************************************************************************/
/**************************************************************************/

%recode_character_variables(
/**************************************************************************/
/*Input*/
input_format_table = output.format_char_levels, /*Table that has the formats that will be used in PROC FORMAT*/
input_dset = output.character_vars_recode, /*Name of table that has the variables to be collapsed*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
number_of_levels_thres = 100, /*Inclusive threshold. The macro will select only variables with levels below this threshold*/
/**************************************************************************/
/*Output*/
output_format_table = output.character_vars_rcd_iteration2 /*Table that contains the formatted variables with the target, the weight and the id variables*/
);

%change_character_lengths(
/*********************************************************************************/
/*Input*/
table_to_change_lengths = output.character_vars_rcd_iteration2, /*Table name of which fields need to change the length*/
character_summary = summary, /*Name of table that contains only the character variables that will be in the model*/
minimum_length = 10, /*Minimum length that the new fields will have*/
/*********************************************************************************/
/*Output*/
output_table = output.character_vars_rcd_iteration2 /*Output table with the new lengths*/
);

/*********************************************************************************/
/*Select the variables that will be transformed to WOE*/
%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = output.character_vars_rcd_iteration2, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = character_variables_to_analyse, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_var_analyse_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put The variables that will be transformed to WOE are: &character_variables_to_analyse.;
%put %sysfunc(countw(&character_variables_to_analyse.)) variables will be transformed to WOE.;
/*********************************************************************************/

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.character_vars_rcd_iteration2, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = , /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = &character_variables_to_analyse., /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Maximum number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.char_original_information_value, /*Dataset with all the information values*/
woe_format_outds = output.char_original_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.char_original_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);

/**************************************************************************/
/**************************************************************************/
/*Collapse levels using NOD_BIN macro*/
%NOD_BIN_character_wrapper(
/*********************************************************************************/
/*Input*/
input_dset = output.character_vars_rcd_iteration2, /*Name of the input dataset that contains the variables we want to recode and the target variable*/
target_variable = &target_variable_name., /*Name of the target variable*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
vars_list = &character_variables_to_analyse., /*List of predictor variables that we want to transform to WOE*/
recoded_var_prefix = char, /*Prefix for recoded variables*/
NOD_BIN_macro = &macros_path.\NOD_BIN_v13.sas, /*Path to NOD_BIN macro*/
/*************************************************************************************/
/*Set Lund and Raimi parameters*/
RL_method = IV, /*IV (collapse maximises Information Value) or LL (collapse maximises Log likelihood)*/
RL_mode = A, /*A (all pairs of levels are compared when collapsing) or J (only adjacent pairs of levels in the ordering of X are compared when collapsing)*/
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
output_original_recode_summary = output.char_summary_recode, /*Output table that contains the original with the recoded variables summary (min, max)*/
output_recode_summary = output.char_vars_recode, /*Output table that contains the code that is used to create the WOE variables from the recoded variables*/ 
output_recode_data = output.char_vars_format_woe /*Output table that contains the data with the target variable with the WOE variables - this will be used for modelling*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = output.char_vars_format_woe, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = collapse_variables_woe, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = collapse_woe_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put The variables after WOE transformation are: &collapse_variables_woe.;
%put %sysfunc(countw(&collapse_variables_woe.)) variables WOE.;

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.char_vars_format_woe, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = &collapse_variables_woe., /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = , /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Maximum number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.clpse_original_information_value, /*Dataset with all the information values*/
woe_format_outds = output.clpse_orignl_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.clpse_orignl_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);
/**************************************************************************/
/**************************************************************************/

/**************************************************************************/
/**************************************************************************/
/*Alternative way to collapse levels using PROC CLUSTER*/
%run_green_wrapper(
/**************************************************************************/
/*Input*/
input_dset = output.character_vars_rcd_iteration2, /*Name of table that has the variables to be collapsed*/
variables_to_recode = &character_variables_to_analyse., /*List of variables that will be collapsed*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/**************************************************************************/
/*Output*/
output_format_table = output.format_char, /*Table that contains the format information*/
output_formatted_data = output.character_vars_rcd_format /*Table that contains the recoded variables*/
);

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.character_vars_rcd_format, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = , /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = &character_variables_to_analyse., /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Maximum number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.character_information_value, /*Dataset with all the information values*/
woe_format_outds = output.character_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.character_vars_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);
/**************************************************************************/
/**************************************************************************/

/**************************************************************************/
/**************************************************************************/
/*Alternative way that converts character variables to binary*/
/*Convert original character variables to binary*/
%character_to_binary_transreg(
/*********************************************************************************/
/*Input*/
input_table = output.character_vars_rcd_iteration2, /*Table that has the character variables that will be convert to binary*/
character_variables_list = &character_variables_to_analyse., /*List of character variables separated by space*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
keep_all_levels = 0, /*Set to 1 to keep all the levels from the character variables and 0 to keep all the levels 
apart from one level which will be the reference level*/
/*********************************************************************************/
/*Output*/
output_design_table = output.original_char_to_binary, /*Table that has the binary variable only*/
output_contents_table = output.original_char_to_binary_contents /*Table that has the labels of the binary variables, so that it will be possible to 
reference them later.*/
);
/**************************************************************************/
/*Convert colapsed WOE character variables to binary*/
%convert_numeric_to_character(
/**************************************************************************/
/*Input*/
input_dset = output.Char_vars_format_woe, /*Input table that contains the numeric variables that should be converted to character*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
character_format = 13.10, /*Format inside the PUT statement*/
/**************************************************************************/
/*Output*/
output_dset = output.Char_vars_format_woe_char /*Name of table that the numeric variables are converted to character*/
);

%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = output.Char_vars_format_woe_char, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_vars_for_bin, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_vars_for_bin_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put &char_vars_for_bin.;
%put %sysfunc(countw(&char_vars_for_bin.));

%character_to_binary_transreg(
/*********************************************************************************/
/*Input*/
input_table = output.Char_vars_format_woe_char, /*Table that has the character variables that will be convert to binary*/
character_variables_list = &char_vars_for_bin., /*List of character variables separated by space*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
keep_all_levels = 0, /*Set to 1 to keep all the levels from the character variables and 0 to keep all the levels 
apart from one level which will be the reference level*/
/*********************************************************************************/
/*Output*/
output_design_table = output.clpsed_char_to_binary, /*Table that has the binary variable only*/
output_contents_table = output.clpsed_char_to_binary_contents /*Table that has the labels of the binary variables, so that it will be possible to 
reference them later.*/
);
/**************************************************************************/

/**************************************************************************/
/**************************************************************************/

proc printto;
run;




