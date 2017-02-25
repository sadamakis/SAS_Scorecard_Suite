/**********************************************************************************************/
/*Join two tables*/
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
