/*********************************************************************************/
/***********   Start parameters configuration    ***************/
/*********************************************************************************/
/*Set path that contains the macros*/
%let macros_path = X:\Decision_Science\11_Team\03_Users\Sotiris\Solutions\Scorecard_suite\Scorecard_suite\src\macros;
/*Set path that will have the output and log files that are produced from this code*/
%let log_path = X:\Decision_Science\11_Team\03_Users\Sotiris\Solutions\Scorecard_suite\Scorecard_suite\logs;
/*Set the path that contains the tables relevant to this code*/
%let data_path = X:\Decision_Science\11_Team\03_Users\Sotiris\Solutions\Scorecard_suite\Scorecard_suite\data;
/*Set the name of the table that contains the following variables: 
1) target variable
2) id variable
3) weight variable
4) all the variables that will be used in cluster analysis (both character and numeric)
*/
%let table_name = input.Original_table;
/*Set the target variable name in the original dataset*/
%let target_variable_name = bad_flag;
/*Set the weight variable name in the original dataset*/
%let weight_variable_name = weight;
/*Set the ID variable name in the original dataset*/
%let ID_variable_name = transact_id;
/*********************************************************************************/
/***********   End parameters configuration     ***************/
/*********************************************************************************/
