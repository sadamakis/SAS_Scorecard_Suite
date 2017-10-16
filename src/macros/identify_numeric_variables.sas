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
/* Program Name:             ---  identify_numeric_variables.sas										*/ 
/* Description:              ---  Identify numeric variables from a dataset. 							*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro identify_numeric_variables(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
numeric_variables, /*Name of the macro variable that contains all the numeric variables that will be used for modelling*/
numeric_contents /*Name of the table that contain the contents of the numeric variables from &input_table. dataset*/
);
%GLOBAL &numeric_variables.;

%let &numeric_variables. = ;
proc contents data=&input_table. (drop= &target_variable. &id_variable. &weight_variable.) noprint out=content_dset (keep=label name varnum TYPE);
run;

data &numeric_contents.;
	set content_dset;
	where TYPE=1;
run;

proc sql noprint;
select name into :&numeric_variables. separated by ' '
from &numeric_contents.
;
quit;
%mend identify_numeric_variables;
/**********************************************************************************************/
