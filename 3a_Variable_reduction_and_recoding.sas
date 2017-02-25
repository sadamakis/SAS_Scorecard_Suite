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
/* Program Name:             ---  3a_Variable_reduction_and_recoding.sas                                */
/* Description:              ---  Fix issues with predictors that are highly correlated. The output from
this step is a dataset that treats highly correlated in the following ways: 
- Select only one variable, the one that has the best two sample t-test with the target variable
- min, max or average of the variables that are highly correlated
- min, max or average of the standardised variables that are highly correlated
- min, max or average of variables that are highly correlated multiplied by the importance weight. The 
higher the correlation of a predictor with the target variable the higher the importance weight. 
Sum of the importance weights of the variables that are correlated equals to the number of the correlated
variables. 
- min, max or average of standardised variables that are highly correlated multiplied by the importance 
weight. The higher the correlation of a predictor with the target variable the higher the importance weight. 
Sum of the importance weights of the variables that are correlated equals to the number of the correlated
variables. 																								*/
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

%include "&macros_path.\merge_two_tables.sas";
%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\variable_reduction.sas";
%include "&macros_path.\recode_numeric_vars.sas";

/*********************************************************************************/
/*********************************************************************************/
filename output3a "&output_files.\3a_variable_reduction_and_recoding_output_%sysfunc(compress(%sysfunc(datetime(),datetime20.0),':')).log";
filename logout3a "&output_files.\3a_variable_reduction_and_recoding_log_%sysfunc(compress(%sysfunc(datetime(),datetime20.0),':')).log";
proc printto print=output3a log=logout3a new;
run;
proc datasets lib=work kill nolist memtype=data;
quit;

/*********************************************************************************/
%merge_two_tables(
/*********************************************************************************/
/*Input*/
dataset_1 = outdata.num_vars_format_woe, /*Dataset 1 which will be on the left side of the join*/
dataset_2 = outdata.Char_vars_format_woe, /*Dataset 1 which will be on the right side of the join*/
id_variable = transact_id, /*Name of ID (or key) variable that will be used to join the two tables*/
/*********************************************************************************/
/*Output*/
merge_output_dataset = outdata.num_char_merge /*Output table from the join*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = outdata.num_char_merge/*numeric_vars_201503*/, /*Name of table that has the character variables*/
target_variable = bad_flag, /*Name of target variable - leave blank if missing*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = SamplingWeight, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = numeric_variables_to_analyse  /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
);
%put &numeric_variables_to_analyse.;
%put %sysfunc(countw(&numeric_variables_to_analyse.));

%variable_reduction(
/*********************************************************************************/
/*Input*/
input_dset = outdata.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
numeric_vars = &numeric_variables_to_analyse., /*List of numeric variables that should be reduced*/
maxeigen = 0.2, /*Argument in PROC VARCLUS. The largest permissible value of the second eigenvalue in each cluster. 
The lower the value	the more splits will be performed.*/
target_variable = bad_flag, /*The name of the dependent variable (it should be binary)*/
weight_variable = SamplingWeight, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/*********************************************************************************/
/*Output*/
out_dset_one_var_per_cluster = outdata.out_dset_one_var_per_cluster, /*The output dataset that provides the list of variables that can be used for modelling. 
	The code keeps only one variable from every cluster - the variable that has the minimum 1-Rsquare. 
	The lower the 1-Rsquare is the higher the variance explained by that variable in the cluster and the 
	lower variable explained in other clusters.*/
out_dset_all_vars = outdata.varclus_importance_weight_woe, /*The output dataset that has the result of PROC VARCLUS and the p-values from the 
	two sample t-tests.*/
varclus_ttest = outdata.varclus_ttest_woe /*The output dataset that has a summary of the VARCLUS output and the t-test output*/
); 

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = outdata.num_char_merge/*numeric_vars_201503*/, /*The name of the dataset that contain all the numeric variables*/
target_variable = bad_flag, /*The name of the dependent variable (it should be binary)*/
weight_variable = SamplingWeight, /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = transact_id, /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = outdata.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = dominant, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = , /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = outdata.coded_vars_min_d, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = outdata.numeric_vars_min_d /*Dataset that has the numeric variables transformed*/
);

proc printto;
run;



