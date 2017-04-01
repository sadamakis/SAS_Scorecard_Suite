/**************************************************************************/
/*This macro checks whether a dataset exists and produces the number of rows. There are two macro variables returned from this code:*/
/*- &dsid.: if this is 0, then the dataset does not exist. Otherwise the dataset exists. */
/*- &nlobs.: if this is null then the dataset does not exist. Otherwise it will have the number of rows in the table.*/
%macro check_number_of_rows(
/**************************************************************************/
/*Input*/
table /*Name of table to check*/
);
%global dsid;
%global nlobs;
%let dsid = %sysfunc(open(&table., IS));
%let nlobs=;
%if &DSID ne 0 %then %do;
%let nlobs = %sysfunc(attrn(&dsid,NLOBS));
%end;
%let rc = %sysfunc(close(&dsid));
%mend check_number_of_rows;
/**************************************************************************/
