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
/* Program Name:             ---  missing_has_1_level_join.sas											*/ 
/* Description:              ---  Select character variables with non-missing values above a specific 
threshold which also have more than one level. There is dependency on macros "character_missing" 
and "find_1_level_chars".																				*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro missing_has_1_level_join(
/*********************************************************************************/
/*Input*/
character_missing_table, /*Output table from character_missing macro*/
has_1_level_table, /*Output table from find_1_level_chars macro*/
argument_missing_percent, /*Missing percentage threshold for selecting variables. For selecting all variables, set this to 100*/
argument_has_1_level, /*Argument for selecting variables that have more than one level. Set this to 0 for selecting variables with more than 1 level*/
/*********************************************************************************/
/*Output*/
output_table /*Output table from the join*/
);
proc sql;
create table &output_table. as 
select 
	t1.*, 
	t2.has_1_level
from &character_missing_table. as t1
left join &has_1_level_table. as t2
on t1.NAME = t2.NAME
where pctmiss < &argument_missing_percent. and has_1_level = &argument_has_1_level.
order by pctmiss
;
quit;
%mend missing_has_1_level_join;
/**********************************************************************************************/
