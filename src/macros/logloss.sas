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
/* Program Name:             ---  logloss.sas												*/
/* Description:              ---  Macro that calculates the log-loss from a table that contains 
the target variable, the score variable and the weight variable											*/
/*                                                                                                      */
/* Date Originally Created:  ---  March 2020                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/
%macro logloss(
/**************************************************************************/
/*Input*/
input_dataset_prob, /*Name of dataset that should have the score or predicted probability, e.g. output table from PROC LOGISTIC*/
target_variable,  /*Name of target variable - leave blank if missing*/
weight_variable, /*Name of weight variable in the input dataset. This should exist in the dataset
If there are no weights in the dataset then create a field with values 1 in every row*/
predicted_probability, /*Predicted probability from the model output*/
eps, /*Correcting factor*/
/**************************************************************************/
/*Output*/
logloss_outdset /*Dataset that contains the Gini coefficient*/
);

data logloss;
    set &input_dataset_prob. (keep= &predicted_probability. &target_variable. &weight_variable.);
    log_loss_i = (&target_variable.*log(&predicted_probability.+&eps.) + (1-&target_variable.)*log(1-&predicted_probability.+&eps.))*&weight_variable.;
run;

proc sql;
create table &logloss_outdset. as 
select
    -sum(log_loss_i)/sum(&weight_variable.) as log_loss
from logloss
;
quit;
%mend logloss;
/***********************************************************************************/
