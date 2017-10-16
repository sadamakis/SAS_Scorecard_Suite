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
/* Program Name:             ---  check_number_of_rows.sas												*/
/* Description:              ---  This macro checks whether a dataset exists and produces the number 
of rows. There are two macro variables returned from this code:
 - &dsid.: if this is 0, then the dataset does not exist. Otherwise the dataset exists.
 - &nlobs.: if this is null then the dataset does not exist. Otherwise it will have the number of rows 
	in the table.																						*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
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
