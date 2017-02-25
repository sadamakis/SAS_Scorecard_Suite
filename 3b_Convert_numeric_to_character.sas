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
/* Program Name:             ---  3b_Convert_numeric_to_character.sas                                   */
/* Description:              ---  Converts numeric variables to character variables and creates
	Weight of Evidence variables                                                                        */
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
/*Set the path that contains the output tables from this code*/
%let outpath = X:\Data_Mart\Analysis\Decision_Science\01_UK\Vanquis\Cards\02_Acquisitions\01_Model_Development\VB_UKCC_AF01\01_Database_Design\Productionise macros;
/*********************************************************************************/
/***********   End parameters configuration     ***************/
/*********************************************************************************/

options compress=yes;

libname outdata "&outpath.";

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
filename output3b "&output_files.\3b_Convert_numeric_to_character_output_&datetime_var..log";
filename logout3b "&output_files.\3b_Convert_numeric_to_character_log_&datetime_var..log";
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
input_dset = outdata.Numeric_vars_min_d, /*Input table that contains the numeric variables that should be converted to character*/
target_variable = bad_flag, /*The name of the dependent variable (it should be binary)*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
character_format = 13.10, /*Format inside the PUT statement*/
/**************************************************************************/
/*Output*/
output_dset = outdata.Numeric_vars_min_d_char /*Name of table that the numeric variables are converted to character*/
);

%identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table = outdata.Numeric_vars_min_d_char, /*Name of table that has the character variables*/
target_variable = bad_flag, /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables = char_vars_to_recode /*Name of the macro variable that contains all the character variables that will be used for modelling*/
);
%put &char_vars_to_recode.;
%put %sysfunc(countw(&char_vars_to_recode.));

%run_green_wrapper(
/**************************************************************************/
/*Input*/
input_dset = outdata.Numeric_vars_min_d_char, /*Name of table that has the variables to be collapsed*/
variables_to_recode = &char_vars_to_recode., /*List of variables that will be collapsed*/
target_variable = bad_flag, /*The name of the dependent variable (it should be binary)*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/**************************************************************************/
/*Output*/
output_format_table = outdata.format_char_numeric, /*Table that contains the format information*/
output_formatted_data = outdata.Numeric_vars_min_d_format /*Table that contains the recoded variables*/
);

%ivs_and_woe_table(
/*********************************************************************************/
/*Input*/
input_dset = outdata.Numeric_vars_min_d_format, /*Name of the input dataset that contains the variables to be recoded, the target variable and the weight*/
numeric_variables_list = , /*List of numeric variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
character_variables_list = &char_vars_to_recode. /*&character_variables_to_analyse.*/, /*List of character variables to calculate the WOE and the IVs separated by space. This can be left as null.*/
target_variable = bad_flag, /*Name of the target variable*/
weight_variable = weight, /*Name of weight variable in the input dataset. This should exist in the dataset*/
groups = 30, /*Number of binning groups for the numeric variables*/
adj_fact = 0.5, /*Adjusted factor for weight of evidence*/
/*********************************************************************************/
/*Output*/
inf_val_outds = outdata.num_char_information_value, /*Dataset with all the information values*/
woe_format_outds = outdata.num_char_woe_format_dataset, /*Dataset with the Weight of Evidence variables*/
output_formatted_data = outdata.num_char_vars_rcd_format_woe /*Original dataset, but with WOE variables instead of the original variables*/
);
/**************************************************************************/
/**************************************************************************/

proc printto;
run;
