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
/* Program Name:             ---  initialize_PSI_CSI.sas	            								*/
/* Description:              ---  Part of PSI macros    												*/
/*                                                                                                      */
/* Date Originally Created:  ---  October 2017                                                          */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/
/***************************************************************************************************/

/*PSI*/
%let data_directory  =/Scorecard_Suite/data/output;                                  /* Specify data directory */
%let output_directory = /Scorecard_Suite/data/output;                   /* Specify output directory */
%let macro_directory = /Scorecard_Suite/development/PSI;                                                   /* Specify source macro directory */
%let program   = PSI;                                        /* Specify program name */

%include "&macro_directory./quick_format.sas";
%include "&macro_directory./psi_execution.sas";
%include "&macro_directory./psi_macro.sas";

/*This macro calculates overall PSI for a score*/
/***********************************************/

%psi_macro(
         indatas =FPF_score_qa_fraud_psi FPF_score_qa_fraud_l_psi,          /* Req: input datasets sepearated by a space e.g. data1 data2 */
          labels =FPF_score_qa_fraud_psi FPF_score_qa_fraud_l_psi,          /* Req: labels to show data names - can be equal to indatas */
          outtab =outtab,    /* Req: output data contains PSI table */
         outstat =outstat,   /* Req: output data contains PSI values */
           title =FPF_PSI,          /* Req: title for the project */
           score =ponzi_scr_1st_loan,          /* Req: the variable to calculate PSI */
      scoreinfmt =,          /* Opt: For numeric variable, a format can be used */
      outfmtdata =outfmtdata,/* Opt: For numeric variable, a format output can be produced */
          weight =,          /* Opt: weight variable */
            bins =10,        /* Req: Number of bins */
         noprint =NO,                           /* Req: No change */
             can =cancel,         /* Req: No change */
           debug =No                             /* Req: No change */
            );

/*******************************************************************************************/
/*CSI*/
data FPF_SCORE_qa_fraud_f_seg1 FPF_SCORE_qa_fraud_f_seg2;
                set FPF_score_opened_exclusions (where=(exclusion_flag_fraud_strategy = 0));
                if APPL_REC_DT>='01MAR2018'd and APPL_REC_DT<='28FEB2019'd and seg=1 then output FPF_SCORE_qa_fraud_f_seg1;

                if APPL_REC_DT>='01NOV2018'd and APPL_REC_DT<='28FEB2019'd and seg=2 then output FPF_SCORE_qa_fraud_f_seg2;
run;

data FPF_SCORE_qa_fraud_l_seg1 FPF_SCORE_qa_fraud_l_seg2;
                set FPF_score_opened_exclusions_l (where=(exclusion_flag_fraud_strategy = 0));
                if APPL_REC_DT>='01MAR2018'd and APPL_REC_DT<='28FEB2019'd and seg=1 then output FPF_SCORE_qa_fraud_l_seg1;

                if APPL_REC_DT>='01NOV2018'd and APPL_REC_DT<='28FEB2019'd and seg=2 then output FPF_SCORE_qa_fraud_l_seg2;
run;

%psi_execution(
                                indatas =FPF_SCORE_qa_fraud_f_seg1 FPF_SCORE_qa_fraud_l_seg1,                                        /* Req: input datasets sepearated by a space e.g. data1 data2 */
        labels  =FPF_SCORE_benchmark FPF_SCORE_validation,                                          /* Req: labels to show data names - can be equal to indatas */
       varlist  =w_BCA5430 w_ALX8220 w_TIME_AT_RESIDENCE_VAR w_SSNGAP w_HAWK_MSG_CD_2 w_OCCUPATION_DESC1 w_SSN_Result_Code w_phone_mismatch w_all5020 w_emailsource
w_TIME_AT_RESIDENCE_VAR_nzp w_SSNGAP_nzp w_inq_b_pc_3m_nzp w_BAX3510_nzp w_emailsource_nzp w_avg_cred_nzp w_IQA9410_nzp w_SSN_Result_Code_nzp
SSN_Result_Code 
,                                                 /* Req: add variable list separated by a space e.g. var1 var2 */
       fmtlist  =,                                       /* Opt: variable list format */
          bins  =5,                                      /* Req: Number of bins */
       outtabs  =outtabs,     /* Req: output data contains PSI table */
       outstats =outstats,    /* Req: output data contains PSI values */
       title    =FPF_CSI,                                          /* Req: title for the project */
       weight   =,                                     /* Opt: weight variable */
       can      =cancel                             /* Req: No change */
                                );
%psi_execution(
                                indatas =FPF_SCORE_qa_fraud_f_seg2 FPF_SCORE_qa_fraud_l_seg2,                                        /* Req: input datasets sepearated by a space e.g. data1 data2 */
        labels  =FPF_SCORE_benchmark FPF_SCORE_validation,                                          /* Req: labels to show data names - can be equal to indatas */
       varlist  =w_emailsource w_ALL5320 w_SSNGAP w_TIME_AT_RESIDENCE_VAR w_IQT9413 w_i_addr_p_mismtc w_pct_bankcar_act_op_6m w_util_gt_90_1 w_CHECKING w_PIL8120 w_SSN_Result_Code
w_ALL5320_nzp w_BCA8370_nzp w_BCC5620_nzp w_IQB9416_nzp w_PIL8120_nzp w_i_fst_sav_nzp w_util_gt_90_1_nzp w_emailsource_nzp
CHECKING SSN_Result_Code SAVINGS 

,                                                 /* Req: add variable list separated by a space e.g. var1 var2 */
       fmtlist  =,                                       /* Opt: variable list format */
          bins  =5,                                      /* Req: Number of bins */
       outtabs  =outtabs,     /* Req: output data contains PSI table */
       outstats =outstats,    /* Req: output data contains PSI values */
       title    =FPF_CSI,                                          /* Req: title for the project */
       weight   =,                                     /* Opt: weight variable */
      can      =cancel                             /* Req: No change */
                                );
