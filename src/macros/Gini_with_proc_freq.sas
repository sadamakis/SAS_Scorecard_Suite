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
/* Program Name:             ---  Gini_with_proc_freq.sas												*/
/* Description:              ---  Macro that calculates the Gini coefficient from a table that contains 
the target variable, the score variable and the weight variable											*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro Gini_with_proc_freq(
/**************************************************************************/
/*Input*/
input_dataset_prob, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
score_variable, /*Score variable should be, e.g., scorecard output or predicted probability*/
/**************************************************************************/
/*Output*/
GINI_outdset /*Dataset that contains the Gini coefficient*/
);
proc freq data=&input_dataset_prob. (keep= &score_variable. &target_variable. &weight_variable.);
table &score_variable.*&target_variable. /noprint measures sparse;
output out = &GINI_outdset. smdrc;
weight &weight_variable.;
run;

data &GINI_outdset.;
set &GINI_outdset.;
gini=_smdrc_*-1;
gini_ase=E_smdrc;
run;
%mend Gini_with_proc_freq;
/***********************************************************************************/
