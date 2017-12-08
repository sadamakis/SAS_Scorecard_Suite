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
/* Program Name:             ---  000_Solution_parameter_configuration.sas                              */
/* Description:              ---  Sets the following parameters that will be used by the solution:
 - macros folder path
 - folder path that stores the log files of the solution
 - folder path that uses input tables and outputs tables
 - table name that has predictors and target variable
 - target variable name
 - weight variable name
 - ID (key) variable name - unique identifier for every row in the dataset                              */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
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
