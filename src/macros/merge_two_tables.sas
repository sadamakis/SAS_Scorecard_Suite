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
/* Program Name:             ---  merge_two_tables.sas													*/ 
/* Description:              ---  Join two tables														*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro merge_two_tables(
/*********************************************************************************/
/*Input*/
dataset_1, /*Dataset 1 which will be on the left side of the join*/
dataset_2, /*Dataset 1 which will be on the right side of the join*/
id_variable, /*Name of ID (or key) variable that will be used to join the two tables*/
/*********************************************************************************/
/*Output*/
merge_output_dataset /*Output table from the join*/
);
proc sql;
create table &merge_output_dataset. as 
select 
	t1.*
	, t2.*
from &dataset_1. as t1
left join &dataset_2. as t2
on t1.&id_variable. = t2.&id_variable.
;
quit;
%mend merge_two_tables;
/**********************************************************************************************/
