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
/* Program Name:             ---  Sensitivity_Analysis.sas									*/
/* Description:              ---  Perform Sensitivity Analysis on All Raw Independent Variables of A Model and Generate Report                                      															*/
/* Note: If the model has more than one segment, please run the sensitivity analysis macro separately for each segment. The input dataset 
           should only include observations from the specific segment, but the scoring code can include one/multiple segments as long as the 
           segmentation variables are retained in the input dataset;                                    */
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

%macro sensitivity
(              /** Input Parameters **/
indata= ,      /* indata: name of the input dataset, which includes all raw independent variables of the model at minimum */
outdata= ,     /* outdata: name of the output dataset, which stores aggregated sensitivity analysis result */
varlist= ,     /* varlist: list of raw independent variables in the model */
maxlist= ,     /* maxlist: the maximum valid value of each independent variable, all values greater than what specified in "maxlist" are 
                            special values and will not be changed during sensitivity analysis, 0 should be specified for independent variables  
                            without any special value; input as a list of numeric values positioned corresponding to "varlist" */
wt= ,          /* wt: weight variable from input dataset; if left blank, the default value 1 is assigned to all observations */
scorefile= ,   /* scorefile: name and path of the file storing model scoring code, which includes raw variable treatments and final scoring 
                              equations; all raw variables should not be overwritten within the scoring code */
scorename= ,   /* scorename: name of the variable representing the final model score in "scorefile" */
pct= ,         /* pct: percentage change of each independent variable; input as a decimal */
modelname= ,   /* modelname: name of the model or model segment */
outprt=        /* outprt: specify if the "outdata" which stores the aggregated sensitivity results will be printed, "Y"/"y" for yes and "N"/"n"  
                           for no; if left blank, the default action is to print */
);

************************************************************************************************************************************************;
**** Step 1. Extract the name and maximum valid value of each independent variable, and the total number of independent variables;

%let _k=1;
%do %while ("%scan(&varlist.,&_k.,%str( ))" ne "");
                %let _mvvar=%scan(&varlist.,&_k.,%str( ));
                %let _mvmax=%scan(&maxlist.,&_k.,%str( ));
                %global mvvar&_k mvmax&_k; 
                %let mvvar&_k=&_mvvar.;
                %let mvmax&_k=&_mvmax.;
                %let _k=%eval(&_k.+1);
%end;

%global _nbvar;
%let _nbvar=%eval(&_k.-1);

************************************************************************************************************************************************;
**** Step 2. Calculate the base model score;

data procdata(drop=&scorename.);
                set &indata.;
/***********************************************************************************************/
/***********************************************************************************************/
/*********** CUSTOMIZED SECTION - HARD CODE DERIVED VARIABLES IN YOUR SCORING CODE
                                                AND DROP THE DERIVED VARIABLE CODE FROM THE SCORING CODE ***************************/
if (bca0300 le 90) and (bca0300-bcc0300 ge 1) then ind_charge_card_1=1;
else ind_charge_card_1=0;
if bcc0300 gt 0 and bcc0300 le 90 then ind_BC_1=1; else ind_BC_1=0;
if MTF0300 gt 0 and MTF0300 le 90 then ind_mortgage_1=1; else ind_mortgage_1=0;
if rta0300 gt 0 and rta0300 le 90 then ind_retail_1 =1; else ind_retail_1=0;
if AUA1300 ge 0 and AUA1300 le 90 then ind_auto_1=1; else ind_auto_1=0;
if (ILN5020 le 999999997) then ind_installment_1=1; else ind_installment_1=0;
if (HLC2000 le 97) then ind_heloc_1=1; else ind_heloc_1=0;

total_unique_trade_all=(ind_charge_card_1+ind_BC_1+ind_mortgage_1+ind_retail_1+ind_auto_1+ind_installment_1+ind_heloc_1);

/************************************/
/* Step 2: create model segment */
if total_unique_trade_all <= 2 then seg =1;else seg =2;

If SSN_ISSUE_YR_TXT =. or SSN_ISSUE_YR_TXT=0 or birth_yr_nbr=. or birth_yr_nbr =0 then SSNGAP =9999;
Else SSNGAP=(SSN_ISSUE_YR_TXT- birth_yr_nbr); 

if seg =1 then do;
                if IQB9410 = 0 then inq_b_pc_3m = 9999 ; else inq_b_pc_3m = round((IQb9415 /IQB9410)*100, 1);

                if ALL0416>90 or ALL5320>999999990 then avg_cred=999999999;
                else if ALL0416=0 then avg_cred=999999995;
                else avg_cred=round(ALL5320/ALL0416, 0.1);
end;
if seg=2 then do;
                if ALL0300 > 90 or BCA0436 =99 then  pct_bankcar_act_op_6m = 999;
                else if BCA0436 =98 then pct_bankcar_act_op_6m = 998;
                else if all0300 =0 then pct_bankcar_act_op_6m =997;
                else  pct_bankcar_act_op_6m = round(BCA0436/ALL0300, 0.000001);

                if RTR3424>90 and  BCC3424>90 then util_gt_90_1=99;
                else if BCC3424>90 then util_gt_90_1=RTR3424;
                else if RTR3424>90 then util_gt_90_1=BCC3424;
                else util_gt_90_1=BCC3424 + RTR3424;
end;
/***********************************************************************************************/
/***********************************************************************************************/
                /* keep a copy of the raw values of all independent variables */
                %do _ki=1 %to &_nbvar.;
                                raw_&&mvvar&_ki.=&&mvvar&_ki.;
                %end;

                /* define weight variable */
                %if "&wt."="" %then %do; wtvar=1; %end;
                %else %do; wtvar=&wt.; %end;

                /* store the base model score */
                %include "&scorefile.";
                score_base=&scorename.;
run;

************************************************************************************************************************************************;
**** Step 3. Macro to calculate model score for increase/decrease of one independent variable;

                %macro sensitivity_indiv
                (iindata=procdata,
                ioutdata=,
                ivar= ,                  /* ivar: the single independent variable that will be increased/decreased, the rest variables will be unchanged */
                imax= ,                  /* imax: the maximum valid value of the single independent variable specified in "ivar" */
                iwt=wtvar,
                iscorefile=&scorefile.,
                iscorename=&scorename.,
                ipct=&pct.,
                imodelname=&modelname.,
                ioutprt= );              /* ioutprt: specify if the single sensitivity results will be printed individually, "Y"/"y" for yes and "N"/"n" 
                                          for no; if left blank, the default action is not to print */

                **** Step 3.1. Calculate the model score with the increase of &ivar.;
                data &iindata.(drop=&iscorename.);
                                set &iindata.;

                                /* increase non-special values of &ivar. by &ipct. and keep special values unchanged */
                                %if &imax.=0 %then %do;
                                                &ivar.=&ivar.*(1+&ipct.);
                                %end;
                                %else %do;
                                                if &ivar.>&imax. then &ivar.=&ivar.;
                                                else &ivar.=min((&ivar.*(1+&ipct.)), &imax.);
                                %end;
                
                                /* store the corresponding model score */
                                %include "&iscorefile.";
                                sinc_&ivar.=&iscorename.;

                                /* set the independent variable back to its raw values */
                                &ivar.=raw_&ivar.;
                run;

                **** Step 3.2. Calculate the model score with the decrease of &ivar.;
                data &iindata.(drop=&iscorename.);
                                set &iindata.;

                                /* decrease non-special values of &ivar. by &ipct. and keep special values unchanged */
                                %if &imax.=0 %then %do;
                                                &ivar.=&ivar.*(1-&ipct.);
                                %end;
                                %else %do;
                                                if &ivar.>&imax. then &ivar.=&ivar.;
                                                else &ivar.=&ivar.*(1-&ipct.);
                                %end;

                                /* store the corresponding model score */           
                                %include "&iscorefile.";
                                sdec_&ivar.=&iscorename.;

                                /* set the independent variable back to its raw values */                
                                &ivar.=raw_&ivar. ;
                run;

                **** Step 3.3. Calculate the mean of the updated model scores, and print the single sensitivity result if needed;
                proc sql noprint;
                                create table &ioutdata. as
                                select "&ivar." as variable_name,
                                       sum(sinc_&ivar.*&iwt.)/sum(&iwt.) as increase_mean_score,
                                                   sum(sdec_&ivar.*&iwt.)/sum(&iwt.) as decrease_mean_score
                                from &iindata.;
                quit;

                %if %upcase(&ioutprt.)=Y %then %do;   
                                proc print data=&ioutdata. noobs;
                                                title "Sensitivity Analysis Result: &ivar. in &imodelname.";
                                                title2 "Percentage Change of &ivar.: %sysfunc(putn(&ipct., percent8.1))";
                                run;
                %end;

                %mend sensitivity_indiv;

************************************************************************************************************************************************;
**** Step 4. Apply the sensitivity_indiv macro to all independent variables;

%do _kj=1 %to &_nbvar.;
                %sensitivity_indiv(ioutdata=result&_kj., ivar=&&mvvar&_kj., imax=&&mvmax&_kj.);
%end;

************************************************************************************************************************************************;
**** Step 5. Define the table format for summarizing aggregated sensitivity analysis result; 

proc sql;
                create table &outdata.  
                (                                               /** Output Parameters: **/
     variable_name char(32),                         /* name of independent variable */                               
                 base_mean_score num format=12.8,                /* mean of base model score */ 
                 increase_mean_score num format=12.8,            /* mean of updated model score with the increase of the independent variable in "variable_name" colomn */
     decrease_mean_score num format=12.8,            /* mean of updated model score with the decrease of the independent variable in "variable_name" colomn */
                increase_mean_change num format=percent8.2,     /* relative change of model score with the increase of the independent variable in "variable_name" colomn */
     decrease_mean_change num format=percent8.2      /* relative change of model score with the decrease of the independent variable in "variable_name" colomn */
                );
quit;

************************************************************************************************************************************************;
**** Step 6. Calculate the mean of the base/updated model scores and the relative changes for all independent variables, and print the aggregated 
             sensitivity analysis result if needed; 

%do _kk=1 %to &_nbvar.;
                proc sql noprint;
                                insert into &outdata. 
                                select "&&mvvar&_kk." ,
                                       sum(score_base*wtvar)/sum(wtvar),
                                       sum(sinc_&&mvvar&_kk.*wtvar)/sum(wtvar),
                                       sum(sdec_&&mvvar&_kk.*wtvar)/sum(wtvar),
                                       (sum(sinc_&&mvvar&_kk.*wtvar)/sum(wtvar) - sum(score_base*wtvar)/sum(wtvar))/(sum(score_base*wtvar)/sum(wtvar)),
                                       (sum(sdec_&&mvvar&_kk.*wtvar)/sum(wtvar) - sum(score_base*wtvar)/sum(wtvar))/(sum(score_base*wtvar)/sum(wtvar)) 
        from procdata;
                quit;
%end;

%if %upcase(&outprt.)=Y or "&outprt."="" %then %do;
                proc print data=&outdata. noobs;
                                title "Sensitivity Analysis Results: &modelname.";
                                title2 "Percentage Change of Every Independent Variable: %sysfunc(putn(&pct., percent8.1))";
                run;
%end;

%mend sensitivity;
