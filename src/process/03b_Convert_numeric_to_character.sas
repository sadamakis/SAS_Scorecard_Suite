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
/* Program Name:             ---  03b_Convert_numeric_to_character.sas                                   */
/* Description:              ---  Converts numeric variables to character variables and creates
	Weight of Evidence variables                                                                        */
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

%include "&programPath.\000_Solution_parameter_configuration.sas";

options compress=yes;

libname output "&data_path.\output";

%include "&macros_path.\convert_numeric_to_character.sas";
%include "&macros_path.\identify_character_variables.sas";
%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\check_number_of_rows.sas";
%include "&macros_path.\NOD_BIN_character_wrapper.sas";
%include "&macros_path.\green.sas";
%include "&macros_path.\run_green_wrapper.sas";
%include "&macros_path.\ivs_and_woe_table.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output3b "&log_path.\03b_Convert_numeric_to_character_output_&datetime_var..log";
filename logout3b "&log_path.\03b_Convert_numeric_to_character_log_&datetime_var..log";
proc printto print=output3b log=logout3b new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/*********************************************************************************/
%convert_numeric_to_character(
/**************************************************************************/
/*Input*/
input_dset = output.Numeric_vars_min_d, /*Input table that contains the numeric variables that should be converted to character*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
character_format = 13.10, /*Format inside the PUT statement*/
/**************************************************************************/
/*Output*/
output_dset = output.Numeric_vars_min_d_char /*Name of table that the numeric variables are converted to character*/
);

%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = output.Numeric_vars_min_d_char, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_vars_to_recode, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents = char_var_recode_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%put &char_vars_to_recode.;
%put %sysfunc(countw(&char_vars_to_recode.));

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.Numeric_vars_min_d_char, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = , /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = &char_vars_to_recode. /*&character_variables_to_analyse.*/, /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.char_convert_information_value, /*Dataset with all the information values*/
woe_format_outds = output.char_convert_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.char_convert_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);

/**************************************************************************/
/**************************************************************************/
/*Collapse levels using NOD_BIN macro*/
%NOD_BIN_character_wrapper(
/*********************************************************************************/
/*Input*/
input_dset = output.Numeric_vars_min_d_char, /*Name of the input dataset that contains the variables we want to recode and the target variable*/
target_variable = &target_variable_name., /*Name of the target variable*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
vars_list = &char_vars_to_recode., /*List of predictor variables that we want to transform to WOE*/
recoded_var_prefix = var, /*Prefix for recoded variables*/
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
output_original_recode_summary = output.char_convert_recode, /*Output table that contains the original with the recoded variables summary (min, max)*/
output_recode_summary = output.char_convert_vars_recode, /*Output table that contains the code that is used to create the WOE variables from the recoded variables*/ 
output_recode_data = output.char_convert_vars_format_woe /*Output table that contains the data with the target variable with the WOE variables - this will be used for modelling*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = output.char_convert_vars_format_woe, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = convert_collapse_variables_woe, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = convert_collapse_woe_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put The variables after WOE transformation are: &convert_collapse_variables_woe.;
%put %sysfunc(countw(&convert_collapse_variables_woe.)) variables WOE.;

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.char_convert_vars_format_woe, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = &convert_collapse_variables_woe., /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = , /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.clpse_cnvrt_information_value, /*Dataset with all the information values*/
woe_format_outds = output.clpse_cnvrt_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.clpse_cnvrt_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);
/**************************************************************************/
/**************************************************************************/

/**************************************************************************/
/**************************************************************************/
/*Alternative way to collapse levels using PROC CLUSTER*/
%run_green_wrapper(
/**************************************************************************/
/*Input*/
input_dset = output.Numeric_vars_min_d_char, /*Name of table that has the variables to be collapsed*/
variables_to_recode = &char_vars_to_recode., /*List of variables that will be collapsed*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/**************************************************************************/
/*Output*/
output_format_table = output.format_char_numeric, /*Table that contains the format information*/
output_formatted_data = output.Numeric_vars_min_d_format /*Table that contains the recoded variables*/
);

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = output.Numeric_vars_min_d_format, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = , /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = &char_vars_to_recode. /*&character_variables_to_analyse.*/, /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = &target_variable_name., /*Name of the target variable*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = output.num_char_information_value, /*Dataset with all the information values*/
woe_format_outds = output.num_char_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = output.num_char_vars_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);
/**************************************************************************/
/**************************************************************************/

proc printto;
run;
