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
/* Program Name:             ---  identify_character_variables.sas										*/ 
/* Description:              ---  Identify character variables from a dataset. 							*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro identify_character_variables(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
character_variables, /*Name of the macro variable that contains all the character variables that will be used for modelling*/
character_contents /*Name of the table that contain the contents of the character variables from &input_table. dataset*/
);
%GLOBAL &character_variables.;

%let &character_variables. = ;
proc contents data=&input_table. (drop= &target_variable. &id_variable. &weight_variable.) noprint out=content_dset (keep=label name varnum TYPE);
run;

data &character_contents.;
	set content_dset;
	where TYPE=2;
run;

proc sql noprint;
select name into :&character_variables. separated by ' '
from &character_contents.
;
quit;
%mend identify_character_variables;
/**********************************************************************************************/
