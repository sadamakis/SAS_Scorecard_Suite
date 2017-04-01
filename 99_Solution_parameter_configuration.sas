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
/*Set the path that contains the output tables of the Solution*/
%let outpath = X:\Data_Mart\Analysis\Decision_Science\01_UK\Vanquis\Cards\02_Acquisitions\01_Model_Development\VB_UKCC_AF01\01_Database_Design\Productionise macros;
/*Set the name of the table that contains the following variables: 
1) target variable
2) id variable
3) weight variable
4) all the variables that will be used in cluster analysis (both character and numeric)
*/
%let table_name = outdata.Original_table;
/*Set the target variable name in the dataset. Target variable is not used in Cluster analysis, but is used in the macros*/
%let target_variable_name = bad_flag;
/*Set the weight variable name in the original dataset*/
%let weight_variable_name = weight;
/*Set the ID variable name in the original dataset*/
%let ID_variable_name = transact_id;
/*********************************************************************************/
/***********   End parameters configuration     ***************/
/*********************************************************************************/
