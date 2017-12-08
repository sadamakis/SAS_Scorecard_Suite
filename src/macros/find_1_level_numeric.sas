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
/* Program Name:             ---  find_1_level_numeric.sas												*/
/* Description:              ---  Check whether there are predictors with only 1 level. If so, then 
drop these fields. The code is relevant to numeric variables. 											*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro find_1_level_numeric(
/*********************************************************************************/
/*Input*/
input_table, /*Name of table that has the character variables*/
target_variable, /*Name of target variable - leave blank if missing*/
id_variable, /*Name of ID (or key) variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset. 
If there are no weights in the dataset then create a field with values 1 in every row*/
/*********************************************************************************/
/*Output*/
output_table, /*Name of output table that will produce a summary for the missing values*/
);
proc means data=&input_table. noprint;
	output out=input_table_min (drop=_type_ _freq_ &target_variable. &id_variable. &weight_variable.) min= ;
run;
proc transpose data=input_table_min out=input_table_min_t;
run;
proc means data=&input_table. noprint;
	output out=input_table_max (drop=_type_ _freq_ &target_variable. &id_variable. &weight_variable.) max= ;
run;
proc transpose data=input_table_max out=input_table_max_t;
run;
proc sql;
create table &output_table. as 
select 
	t1._NAME_ as name
	, case when t2.col1-t1.col1=0 then 1 
	else 0 end as has_1_level
from input_table_min_t as t1
left join input_table_max_t as t2
on t1._NAME_ = t2._NAME_
order by t1._NAME_
;
quit;
%mend find_1_level_numeric;
/*********************************************************************************/
