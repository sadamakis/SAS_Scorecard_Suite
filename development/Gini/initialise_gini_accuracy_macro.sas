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
/* Program Name:             ---  initialise_gini_accuracy_macro.sas	           								*/
/* Description:              ---  Part of Gini calculation macros   									*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

%let server_macro_folder= /Scorecard_Suite/development/Gini;                /*Add location where all Macro SAS codes are stored*/
%let projectpath   = /Scorecard_Suite/development/Gini;                                 /*Add project location*/  
%let program   = qa_fraud;                          /*Add program name*/

%inc "&server_macro_folder/gini_accuracy_calculation.sas";
%inc "&server_macro_folder/lift_table_macro.sas";
%inc "&server_macro_folder/quick_format.sas";
%inc "&server_macro_folder/gini_core_macro.sas";

options compress = binary;

libname out "&projectpath./data"; /*Project data location*/

/*proc printto log   = "&projectpath./output/&program..log" new; run;*/
/*proc printto print = "&projectpath./output/&program..lst" new; run;*/
/*Actual GINI values will be in the .lst output file*/

%performance_report( indatas= TPF_benchmark,                                                                                        /*Required: Datasets for which lift tables and charts are required*/
                 score= fraud_scr_15,                                                                                                   
                 yvar= fraud_performance,                                                                                                       /*Required: Outcome variable*/           
                 sortorder=descending,                                                                                              /*Required: Score rank-order direction*/
                 seg_var=,                                                                                                                                        /*Optional: Model segmentation variable - Char format only, will error on numeric*/
                 bins=20,                                                                                                                                           /*Required: Number of bins*/
                 title1= QA_Fraud_PD_Accuracy,                                                                            /*Required: Graph Title 1*/
                 title2= Title_2 ,                                                                                              /*Optional: Graph Title 2*/
                 weight=,                                                                                                                                          /*Optional: Weight variable*/
                 outfile=/sasdata/dec_sci/user_projects/DSSPROD/crm_models2/fraud/Consumer_lending/tpf/code/model_governance/team_macros_output/Gini_Accuracy_6_2_5/qa_fraud_accuracy.txt);                     /*Required: Specify output txt file - see instructions below*/
