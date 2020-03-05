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
/* Program Name:             ---  03a_Variable_reduction_and_recoding.sas                               */
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

libname chrctrcd "&data_path.\output\01_character_recoding";
libname numrcd "&data_path.\output\02_numeric_recoding";
libname varrdctn "&data_path.\output\03a_variable_reduction";

%include "&macros_path.\merge_two_tables.sas";
%include "&macros_path.\merge_tables.sas";
%include "&macros_path.\identify_numeric_variables.sas";
%include "&macros_path.\variable_reduction.sas";
%include "&macros_path.\recode_numeric_vars.sas";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output3a "&log_path.\03a_variable_reduction_and_recoding_output_&datetime_var..log";
filename logout3a "&log_path.\03a_variable_reduction_and_recoding_log_&datetime_var..log";
proc printto print=output3a log=logout3a new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

/*********************************************************************************/
%merge_two_tables(
/*********************************************************************************/
/*Input*/
dataset_1 = numrcd.num_vars_format_woe, /*Dataset 1, which will be on the left side of the join*/
dataset_2 = chrctrcd.Char_vars_format_woe, /*Dataset 2, which will be on the right side of the join*/
/*- Use dataset_2=chrctrcd.Char_vars_format_woe for the WOE transformation of the character variables*/
/*- Use dataset_2=chrctrcd.clpsed_char_to_binary for the binary variables that are derived from the WOE transformations of the character variables*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable that will be used to join the two tables*/
/*********************************************************************************/
/*Output*/
merge_output_dataset = varrdctn.num_char_merge /*Output table from the join*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = varrdctn.num_char_merge/*numeric_vars_201503*/, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = numeric_variables_to_analyse,  /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = numeric_variables_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &numeric_variables_to_analyse.;
%put %sysfunc(countw(&numeric_variables_to_analyse.));

%variable_reduction(
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
numeric_vars = &numeric_variables_to_analyse., /*List of numeric variables that should be reduced*/
maxeigen = 0.5, /*Argument in PROC VARCLUS. The largest permissible value of the second eigenvalue in each cluster. 
The lower the value	the more splits will be performed.*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/*********************************************************************************/
/*Output*/
out_dset_one_var_per_cluster = varrdctn.out_dset_one_var_per_cluster, /*The output dataset that provides the list of variables that can be used for modelling. 
	The code keeps only one variable from every cluster - the variable that has the minimum 1-Rsquare. 
	The lower the 1-Rsquare is the higher the variance explained by that variable in the cluster and the 
	lower variable explained in other clusters.*/
out_dset_all_vars = varrdctn.varclus_importance_weight_woe, /*The output dataset that has the result of PROC VARCLUS and the p-values from the 
	two sample t-tests.*/
varclus_ttest = varrdctn.varclus_ttest_woe /*The output dataset that has a summary of the VARCLUS output and the t-test output*/
); 

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
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
variable_suffix = , /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_d, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_d /*Dataset that has the numeric variables transformed*/
);


/********************************************************************************************************************/
/********************************************************************************************************************/
/********************************************************************************************************************/


%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = mean, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iw_mean, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iw_mean, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iw_mean /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = min, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iw_min, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iw_min, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iw_min /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = max, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iw_max, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iw_max, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iw_max /*Dataset that has the numeric variables transformed*/
);


/********************************************************************************************************************/
/********************************************************************************************************************/
/********************************************************************************************************************/


%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = no_transform, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = mean, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = nt_mean, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_nt_mean, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_nt_mean /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = no_transform, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = min, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = nt_min, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_nt_min, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_nt_min /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = no_transform, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = max, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = nt_max, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_nt_max, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_nt_max /*Dataset that has the numeric variables transformed*/
);


/********************************************************************************************************************/
/********************************************************************************************************************/
/********************************************************************************************************************/


%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = mean, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = std_mean, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_std_mean, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_std_mean /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = min, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = std_min, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_std_min, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_std_min /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = max, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = std_max, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_std_max, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_std_max /*Dataset that has the numeric variables transformed*/
);


/********************************************************************************************************************/
/********************************************************************************************************************/
/********************************************************************************************************************/


%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight_standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = mean, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iwstd_mean, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iwstd_mean, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iwstd_mean /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight_standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = min, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iwstd_min, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iwstd_min, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iwstd_min /*Dataset that has the numeric variables transformed*/
);

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.num_char_merge, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_weight_woe, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
argument_transform = importance_weight_standardised, /*Use the following values: 
no_transform: if the input variables will be used in the argument_function
standardised: if the standardised values will be used in the argument_function
importance_weight: if importance weight will be multiplied with the input variables before entering in the argument_function
importance_weight_standardised: if the importance weight will be multiplied with the standardised input variables before entering in the argument_function
dominant: if only the most important variable (in terms of lower two sample t-test p-value) from each cluster will be selected
*/
argument_function = max, /*Leave blank if argument_transform=dominant. Otherwise, choose the function that will be used to summarise the clusters. 
Use the following values:
min: for minimum
max: for maximum
mean: for average
*/
variable_suffix = iwstd_max, /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_iwstd_max, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_iwstd_max /*Dataset that has the numeric variables transformed*/
);


/********************************************************************************************************************/
/********************************************************************************************************************/
/********************************************************************************************************************/

%merge_tables(
/*********************************************************************************/
/*Input*/
datasets_to_merge = varrdctn.Numeric_vars_min_d 
varrdctn.Numeric_vars_min_iwstd_max varrdctn.Numeric_vars_min_iwstd_mean varrdctn.Numeric_vars_min_iwstd_min 
varrdctn.Numeric_vars_min_iw_max varrdctn.Numeric_vars_min_iw_mean varrdctn.Numeric_vars_min_iw_min 
varrdctn.Numeric_vars_min_nt_max varrdctn.Numeric_vars_min_nt_mean varrdctn.Numeric_vars_min_nt_min 
varrdctn.Numeric_vars_min_std_max varrdctn.Numeric_vars_min_std_mean varrdctn.Numeric_vars_min_std_min, /*Names of datasets to merge, separated by space*/
id_variable = transact_id, /*Name of ID (or key) variable that will be used to join the two tables*/
/*********************************************************************************/
/*Output*/
merge_output_dataset = varrdctn.numeric_vars_min /*Output table from the join*/
);

%identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table = varrdctn.numeric_vars_min, /*Name of table that has the character variables*/
target_variable = &target_variable_name., /*Name of target variable - leave blank if missing*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables = numeric_variables_to_analyse,  /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents = numeric_variables_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%put &numeric_variables_to_analyse.;
%put %sysfunc(countw(&numeric_variables_to_analyse.));

%variable_reduction(
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.numeric_vars_min, /*The name of the dataset that contain all the numeric variables*/
numeric_vars = &numeric_variables_to_analyse., /*List of numeric variables that should be reduced*/
maxeigen = 0.5, /*Argument in PROC VARCLUS. The largest permissible value of the second eigenvalue in each cluster. 
The lower the value	the more splits will be performed.*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
/*********************************************************************************/
/*Output*/
out_dset_one_var_per_cluster = varrdctn.out_dset_one_var_per_clstr_all, /*The output dataset that provides the list of variables that can be used for modelling. 
	The code keeps only one variable from every cluster - the variable that has the minimum 1-Rsquare. 
	The lower the 1-Rsquare is the higher the variance explained by that variable in the cluster and the 
	lower variable explained in other clusters.*/
out_dset_all_vars = varrdctn.varclus_importance_wght_woe_all, /*The output dataset that has the result of PROC VARCLUS and the p-values from the 
	two sample t-tests.*/
varclus_ttest = varrdctn.varclus_ttest_woe_all /*The output dataset that has a summary of the VARCLUS output and the t-test output*/
); 

%recode_numeric_vars (
/*********************************************************************************/
/*Input*/
input_dset = varrdctn.numeric_vars_min, /*The name of the dataset that contain all the numeric variables*/
target_variable = &target_variable_name., /*The name of the dependent variable (it should be binary)*/
weight_variable = &weight_variable_name., /*Name of weight variable in the input dataset. This should exist in the dataset.*/
id_variable = &ID_variable_name., /*Name of ID (or key) variable - leave blank if missing*/
variable_reduction_output_dset = varrdctn.varclus_importance_wght_woe_all, /*out_dset_all_vars dataset that is produced from the variable_reduction macro*/
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
variable_suffix = , /*Suffix of the variable name that will be created. Leave blank if argument_transform=dominant. Otherwise, some suggestions could be:
nt_min, nt_max, nt_mean: for 'no transform' argument_transform, ('min', 'max', 'mean') argument_function
std_min, std_max, std_mean: for 'standardised' argument_transform, ('min', 'max', 'mean') argument_function
iw_min, iw_max, iw_mean: for 'importance_weight' argument_transform, ('min', 'max', 'mean') argument_function
iwstd_min, iwstd_max, iwstd_mean: for 'importance_weight_standardised' argument_transform, ('min', 'max', 'mean') argument_function
blank: for 'dominant' argument_transform
*/
/*********************************************************************************/
/*Output*/
coded_vars_dset = varrdctn.coded_vars_min_all, /*Dataset that contains what function and transformation was applied to each cluster*/
output_dset = varrdctn.numeric_vars_min_all /*Dataset that has the numeric variables transformed*/
);

/*********************************************************************************/
/*********************************************************************************/
proc printto;
run;

