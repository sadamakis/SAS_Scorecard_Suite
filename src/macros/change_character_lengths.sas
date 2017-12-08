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
/* Program Name:             ---  change_character_lengths.sas											*/
/* Description:              ---  Change the length of character fields so that there will be no 
truncation at a later step of the solution																*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro change_character_lengths(
/*********************************************************************************/
/*Input*/
table_to_change_lengths, /*Table name of which fields need to change the length*/
character_summary, /*Name of table that contains only the character variables that will be in the model*/
minimum_length, /*Minimum length that the new fields will have*/
/*********************************************************************************/
/*Output*/
output_table /*Output table with the new lengths*/
);
proc contents data=&table_to_change_lengths. out=table_contents noprint;
run;
proc sql noprint;
select t1.NAME, max(t1.LENGTH, t1.FORMATL, t1.INFORML, &minimum_length.) 
into :chars_to_change_length separated by ' ', :new_length separated by ' '
from table_contents as t1
inner join &character_summary. as t2
on t1.NAME = t2.original_name
;
quit;
%put Characters to change length &chars_to_change_length.;
%put New lengths &new_length.;

data &output_table.;
%do i = 1 %to %sysfunc(countw(&chars_to_change_length.));
length %scan(&chars_to_change_length., &i.) $%scan(&new_length., &i.).;
format %scan(&chars_to_change_length., &i.) $%scan(&new_length., &i.).;
informat %scan(&chars_to_change_length., &i.) $%scan(&new_length., &i.).;
%end;
	set &table_to_change_lengths.;
run;
%mend change_character_lengths;
/**********************************************************************************************/
