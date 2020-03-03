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
/* Program Name:             ---  merge_tables.sas													*/ 
/* Description:              ---  Join many tables														*/
/*                                                                                                      */
/* Date Originally Created:  ---  March 2020                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro merge_tables(
/*********************************************************************************/
/*Input*/
datasets_to_merge, /*Names of datasets to merge, separated by space*/
id_variable, /*Name of ID (or key) variable that will be used to join the two tables*/
/*********************************************************************************/
/*Output*/
merge_output_dataset /*Output table from the join*/
);

proc sql;
create table &merge_output_dataset. as 
select 
%do k = 1 %to %sysfunc(countw(&datasets_to_merge., ' '));
	%if &k.=1 %then %do;
		t&k..*
	%end;
	%else %do;
		, t&k..*
	%end;
%end;
%do k = 1 %to %sysfunc(countw(&datasets_to_merge., ' '));
	%if &k.=1 %then %do;
		from %scan(&datasets_to_merge., &k., ' ') as t&k.
	%end;
	%else %do;
		inner join %scan(&datasets_to_merge., &k., ' ') as t&k. 
		on t1.&id_variable. = t&k..&id_variable.
	%end;
%end;
;
quit;
%mend merge_tables;
/**********************************************************************************************/
