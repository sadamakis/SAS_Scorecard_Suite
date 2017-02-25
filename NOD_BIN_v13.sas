%MACRO NOD_BIN(
DATASET =  ,
X =  ,
Y =  ,
W =  ,
METHOD =  ,  /* IV or LL */
MODE =  ,    /* A or J */
MISS =  ,    /* MISS <other is noMISS> */
MIN_PCT =  , /* space = 0 or integer 0 to 99 */
MIN_NUM =  , /* space = 0 or integer >= 0 */
VERBOSE =  , /* YES <other is NO> */
LL_STAT =  , /* YES <other is NO */
WOE =  ,     /* WOE <other is NO */
ORDER =  ,   /* D or A */
WOEADJ =     /* space = 0, or 0, or 0.5 */
);

/* Disclaimer

All SAS code in this document is provided "as is" by Bruce Lund without warranty of any kind, either express or implied,
including but not limited to the implied warranties of merchantability and fitness for a particular 
purpose. Recipients acknowledge and agree that the Bruce Lund shall not be liable for any damages
whatsoever arising out of their use of this material. In addition, the Bruce Lund will provide no support
for the materials contained herein.
*/

/* Documentation

!!! WARNING: There is only partial Input Data and Parameter Checking in this Program !!!

DATASET is a dataset name - either one or two components

X (Predictor) is a numeric or character variable which can have MISSING values
If X is character, then ! cannot be a value. The value ! is used in macro processing.
See the parameter MISS for how missing values of X are processed.
"___X_Char" is RESERVED.  Do not use ___X_Char as the name of a predictor.
If X is numeric, then X must have integer values between 0 and 99. Otherwise, the macro STOPs.

Y (Target) has values 0 and 1 without MISSING values.  For the current version %NOD_BIN
 does not accept a target with values other than 0 and 1.

W (Freq) has values which are positive integers.  It represents a FREQUENCY variable.
If there is no frequency variable in DATASET, then enter 1.

METHOD is IV or LL
-  For METHOD = IV the collapsing maximizes IV at each step
-  For METHOD = LL the collapsing maximizes Log likelihood at each step
-  METHOD = C is disabled (version 12a)

MODE is A or J
-  For MODE = A all pairs of levels are compared when collapsing
-  For MODE = J only adjacent pairs of levels in the ordering of X are compared when collapsing. 
For MODE = J The Missing Level is not eligible to be collapsed with any other Level of X 
Consider using %ORDINAL_BIN instead of %NOD_BIN when MODE = A

MISS = MISS is used if missing values for X (Predictor) are treated as a Level. 
If MODE = J, then missing is not allowed to collapse with any other Level. 
The missing Level will be one of the 2 Levels appearing in the final collapse k = 2.
-  If X is character, then the missing Level appears as "!" in the Reports.
-  If X is numeric, then the missing Level appears as "." in the Reports.
-  WOE SAS coding: The SAS code statements do not need modification when MISS = MISS is specified.

In the WOE SAS code statement, if X is character, then "space" is used in the SAS code for missing.
In the WOE SAS code statement, if X is numeric, then "." is used in the SAS code for missing.

MIN_PCT = space or number from 0 to 99. If space, then MIN_PCT defaults to 0
MIN_PCT collapses a level of X where the sample size of the level is below the MIN_PCT
 ("minimum percent") of the total.

Description of Process: As the algorithm finds pairs of levels to collapse to maximize IV (or LL),
it also identifies pairs where one (or both) or the levels has a count below MIN_PCT% of total sample. 
If one or more such pairs exist, the algorithm will collapse the pair which maximizes IV (or LL):

Example: Suppose X has 5 levels: A, B, C, D, E and A has 2%, B has 4%, C has 2%, D has 40% and E has 52%
  and suppose MIN_PCT = 5 (=5%) and MODE = A. There are 10 possible of pairs to collapse in the first iteration
  but of these there are 9 that involve at least one level under 5%. 
  Among these 9, suppose that collapsing A and B gives the maximize IV (or LL). 
  Now there are four bins {A,B}, {C}, {D}, {E} with {A,B} having 6%. 
  The process described above now repeats. Only {C} falls below 5% so this current iteration will remove 
  all bins under 5% by collapsing {C} with some other bin.

MIN_NUM = space or a number from 0 or higher. If space, then MIN_NUM defaults to 0. 
MIN_NUM replaces the percentage given by MIN_PCT with a count. 
MIN_NUM has the same effect on collapsing as does MIN_PCT. 
Both MIN_PCT and MIN_NUM can be specified at the same time and each will affect the collapsing algorithm 
as described above.

VERBOSE = YES is used to display the entire history of collapsing in the SUMMARY REPORT. 
Otherwise this history is not displayed in the SUMMARY REPORT.

LL_STAT = YES is used to display entropy (base e), Nested_ChiSq, and the prob-value for the Nested Chi_Sq.

WOE = WOE is used to print the WOE coded transform of X for each iteration of collapsing.

ORDER = D | A. If D then the lower value of Y is set to B and the greater value of Y is set to G. 
The G value is modeled. That is, G appears in the numerator of the weight-of-evidence expression.

WOEADJ = space, 0 or 0.5 If space, then space is converted to 0. 
If WOEADJ = 0.5 then 0.5 replaces 0 in a "zero cell". A "zero cell" is a level of X where the count of Y=1 
is zero or the count of Y=0 is zero.
By replacing "0" with "0.5" the macro will not STOP with ZERO CELL DETECTED error. Binning will continue and will
include (as an initial bin) all levels of X. The user should consider setting the MIN_NUM parameter to a small
integer value so that the WOEADJ cells are collapsed quickly if the total count of that cell is small. 

If there are no zero cells, then the title in Reports will show WOEADJ = N/A regardless of the input parameter
value of WOEADJ.

COMMENT AND RESTRICTIONS

1. X_STAT is the same as the model "c" statistic. X_STAT is introduced because it can be computed in a DATA Step
(does not require PROC LOGISTIC)
2. It is required that ALL cell counts in the X-Y Frequency Table are positive.
The Program ENDS if there is a zero cell and prints "ZERO CELL DETECTED". But see parameter WOEADJ.
3. SAS code for WOE transformation of X is saved in ___X_woe&num_levels_r for each collapsed level (value of &num_levels_r).
Only the first 22 characters of X are used when naming these data sets.
4. If MODE = J, then in the SUMMARY report the column MONO equals YES when X_STAT = C_STAT
5. If X is numeric then X must have only integer values between 0 and 99

*/

%LET Version = v12b;

/* In Version v12b:
   Renamed macro to NOD_BIN
   Error check for MIN_PCT and MIN_NUM implemented
   METHOD = C Disabled
   Fixed PROC PRINT ___mean_out TITLE6 regarding G, B, and ORDER
*/

options ls=230 nocenter;

%macro disclaimer;

DATA disclaimer;
length notice $80;

notice = "This program is provided without warranty.";
output;
notice = "See Disclaimer in NOD_BIN_&version..sas for important information.";
output;
notice = "WARNING: There is only partial Input Data and Parameter Checking in this Program";
output;
%IF %UPCASE(&MODE) = J %THEN %DO;
notice = "Consider using ORDINAL_BIN instead of NOD_BIN when MODE = J";
output;
%END;
/*
%IF (%UPCASE(&MIN_PCT) ne OR %UPCASE(&MIN_NUM) ne ) AND (%UPCASE(&METHOD) = C) %THEN %DO;
notice = "MIN_PCT and MIN_NUM are not active when METHOD = C";
output;
%END;
*/
run;

proc print data = disclaimer;
title "NOTICE";
run;

%mend;

%disclaimer;

%global num_levels;
%global FORCED;
%global prior_FORCED;
%global woe_file;
%global STOP;
%global LL_inter;
%global X_type;
%global Miss_Exists;
%global NOBS;
%global X_TYPE;
%global Y_TYPE;
%global W_TYPE;
%global ERROR_MSG1;
%global ERROR_MSG2;
%global ERROR_MSG3;

%LET STOP = NO;   
%LET Miss_Exists = N;
%LET FORCED = N/M;

* Parameter defaults;
%IF &Min_Pct =  %THEN %LET MIN_Pct = 0;
%IF &Min_Num =  %THEN %LET MIN_Num = 0;

%macro test_type(DATASET,X);

DATA _NULL_; set &DATASET(obs=1) nobs = nobs;
   call symput('X_TYPE',VTYPE(&X));
   call symput('Y_TYPE',VTYPE(&Y));
   %IF &W NE 1 %THEN call symput('W_TYPE',VTYPE(&W));;
   run;
%put &X_TYPE;
%put &Y_TYPE;
%put &W_TYPE;
%mend;

* Check that DATASET exists;
%IF %sysfunc(EXIST(&DATASET)) = 0 %THEN %DO;
   %LET ERROR_MSG1 = Dataset = &DATASET does not exist;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;

%test_type(&DATASET,&X);
* METHOD = C Disabled in version 12a;   
%IF (%UPCASE(&METHOD) NE LL) & (%UPCASE(&METHOD) NE IV) /*& (%UPCASE(&METHOD) NE C)*/
%THEN 
%DO; 
   %LET ERROR_MSG1 = INVALID SUBSTITUTION: METHOD = &METHOD;
   %LET ERROR_MSG2 = ;
   %IF %UPCASE(&METHOD) = SQ %THEN %DO;
      %LET ERROR_MSG2 = NOTE: METHOD = SQ is not implemented;
      %END;
   %IF %UPCASE(&METHOD) = C %THEN %DO;
      %LET ERROR_MSG2 = NOTE: METHOD = C is Disabled (v12b);
      %END;
   %LET ERROR_MSG3 = ENDING EXECUTION;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;
   
%IF (%UPCASE(&METHOD) EQ C) & (%UPCASE(&MODE) EQ J) & (%UPCASE(&MISS) EQ MISS)
%THEN 
%DO; 
   %LET ERROR_MSG1 = NOT SUPPORTED: METHOD = &METHOD with MODE = J and MISS = MISS;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;
      
%IF (%UPCASE(&MODE) NE A)
%THEN 
%DO; 
   %IF (%UPCASE(&MODE) NE J)
   %THEN
   %DO;
      %LET ERROR_MSG1 = INVALID SUBSTITUTION: MODE = &MODE;
      %LET ERROR_MSG2 = ENDING EXECUTION;
      %LET ERROR_MSG3 = ;
      %LET STOP = YES;
      %GOTO EXIT0;
      %END;
   %END;

%IF ((%UPCASE(&ORDER) NE A) AND (%UPCASE(&ORDER) NE D))
%THEN 
%DO; 
   %LET ERROR_MSG1 = INVALID SUBSTITUTION: ORDER = &ORDER;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;
   
%IF &WOEADJ =  %THEN %DO; %LET WOEADJ = 0; %END;
%IF &WOEADJ = .5 %THEN %DO; %LET WOEADJ = 0.5; %END; 
%IF (&WOEADJ NE 0.5 AND &WOEADJ NE 0) %THEN %DO; 
   %LET ERROR_MSG1 = INVALID SUBSTITUTION: WOEADJ = &WOEADJ;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;   
 
DATA __X_ERROR_MISSING_VARIABLE; SET &DATASET(obs=1);
KEEP &X &Y %IF (&W ne 1) %THEN %DO; &W %END; ;
run;
%LET VAR_not_Ref = &syserr;
PROC DELETE DATA = __X_ERROR_MISSING_VARIABLE;
run; 

%LET ERROR_MSG1 = ;
%LET ERROR_MSG2 = ;
%IF &VAR_not_Ref > 0 %THEN %DO;
   %IF (&W ne 1) %THEN %DO; 
      %LET ERROR_MSG1 = At least 1 of: &X, &Y, &W is not in Dataset = &DATASET;
      %END;
   %IF (&W eq 1) %THEN %DO; 
      %LET ERROR_MSG1 = At least 1 of: &X or &Y is not in Dataset = &DATASET;
      %END;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;
   
%IF (&W NE 1)
%THEN
%DO;
   %IF (&W_TYPE NE N) %THEN %DO;
      %LET ERROR_MSG1 = Freq variable &W is not numeric;
      %LET ERROR_MSG2 = ENDING EXECUTION;
      %LET ERROR_MSG3 = ;
      %LET STOP = YES;
      %GOTO EXIT0;
      %END;
   %END;
/* Check if Target Variable is numeric */ 
%IF &Y_TYPE NE N %THEN %DO;
   %LET ERROR_MSG1 = Target variable &Y is not numeric;
   %LET ERROR_MSG2 = ENDING EXECUTION;
   %LET ERROR_MSG3 = ;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;
    
/* Check if Target Variable has a value other than 0 or 1 */
DATA _NULL_; SET &DATASET(KEEP = &Y &X) END=EOF;
   RETAIN X_MISS 1;
   IF &Y NOT IN (0, 1)
   THEN
   DO;
      Call Symput('ERROR_MSG1',
       "&Y either has missing values OR does not only have values of 0 and 1");
      Call Symput('ERROR_MSG2',"ENDING EXECUTION");
      Call Symput('ERROR_MSG3'," ");
      Call Symput ('STOP',"YES");
      STOP;
      END;
   %IF &X_TYPE = N
   %THEN
   %DO;
      IF &X > . 
      THEN 
      DO;
         IF (&X < 0 OR &X > 99) or (FLOOR(&X) < &X)
         THEN
         DO;
            Call Symput('ERROR_MSG1',
       "%UPCASE(&X) is numeric but does not have integer values from 0 to 99");
            Call Symput('ERROR_MSG2',"ENDING EXECUTION");
            Call Symput('ERROR_MSG3'," ");
            Call Symput ('STOP',"YES");
            STOP;
            END;
         END;
      %END;

   %IF &X_TYPE = N %THEN %DO; IF &X > . THEN X_MISS = 0; %END;
   %IF &X_TYPE = C %THEN %DO; IF &X ne '' THEN X_MISS = 0; %END;
   
   IF EOF AND X_MISS = 1
   THEN
   DO;
      Call Symput('ERROR_MSG1',
       "&X has only missing values");
      Call Symput('ERROR_MSG2',"ENDING EXECUTION");
      Call Symput('ERROR_MSG3'," ");
      Call Symput ('STOP',"YES");
      STOP;
      END;
run;

%IF &STOP = YES %THEN %GOTO EXIT0;

DATA _NULL_;
   length test1 - test2 $20;
   length para1 - para2 $20;
   array test {2} $ test1 - test2;
   array para {2} $ para1 - para2;
   test1 = "&Min_Pct";
   test2 = "&Min_Num";
   para1 = "Invalid Min_Pct";
   para2 = "Invalid Min_Num";
 
do i = 1 to 2;
   OK = (length(test{i}) + 1 - notdigit(test{i}) = 0) + (test{i} = "");
   If OK = 0 then do;
      Call Symput('ERROR_MSG1',para{i});
      Call Symput('ERROR_MSG3'," ");
      Call Symput('ERROR_MSG2',"ENDING EXECUTION");
      Call Symput ('STOP',"YES");
      STOP;
      end;
   end;
if (test1 ne "" & not (0 <= test1 + 0 <= 99)   )
   or
   (test2 ne "" & not (0 <= test2 + 0)   )     
   then do;
      Call Symput('ERROR_MSG1',"invalid range for Min_Pct or Min_Num");
      Call Symput('ERROR_MSG3'," ");
      Call Symput('ERROR_MSG2',"ENDING EXECUTION");
      Call Symput('STOP',"YES");
      STOP;
      end;
run;
%IF &STOP = YES %THEN %GOTO EXIT0;

PROC MEANS data = &DATASET/*(where =(&Y ne .))*/ 
   noprint
   /* Do not include missing in PROC MEANS if &MISS ne MISS */ 
   %IF (%UPCASE(&MISS) = MISS) %THEN missing ; ;
   class &X; var &Y; %IF (%UPCASE(&W) NE 1) %THEN %DO; freq &W; %END;
   types () &X;
   output out = mean_out_0
   sum = y;
run;
options mlogic mprint;
DATA mean_in; SET mean_out_0 nobs = num_levels end = eof;
   length ___x_char $1000;
   LABEL ___x_char = "&X";
   keep ___x_char G B;
   retain zero 0;

   /* if &X is character, then replace space with ! */
   /* if &X is numeric and missing values have been allowed, continue processing missing "." */
   if _type_ = 0 then call symput('NOBS',_freq_);
   /* correction for v8c */
   /* correction for v8f -- added "& _type_ = 1" to lines below */
   if "&X_TYPE" = "C" & &X = " " & _type_ = 1 then call symput('MISS_EXISTS',"Y");
   if "&X_TYPE" = "N" & &X = . & _type_ = 1 then call symput('MISS_EXISTS',"Y");
   /* end: correction for v8f */
   /* end: correction for v8c */

   if /*"&X_TYPE" = "C" &*/ &X = " " & _type_ = 1 then &X = "!";
   if "&X_TYPE" = "C" then ___x_char = trim(&X);
   if "&X_TYPE" = "N" then ___x_char = translate(right(put(&X,2.)), '#', ' ');
   %IF %UPCASE(&ORDER) = D %THEN %DO; 
      B = _freq_ - y; 
      G = y;
      %END;
   %ELSE %IF %UPCASE(&ORDER) = A %THEN %DO; 
      G = _freq_ - y; 
      B = y;
      %END;
   if _n_ = 1 then call symput('num_levels',trim(left(put((num_levels - 1),4.)))); /*Subtracts 1 for _TYPE_=0*/
   if _n_ = 1 then call symput('num_levels_minus1',num_levels - 2);
   if _n_ = 1 
   then
   do;
      LL_Inter = B*log(B/_freq_) + G*log(G/_freq_);
      call symput('LL_inter',LL_inter);
      end;
   if G = 0 or B = 0
   then
   do;
      zero = 1;
      if G = 0 and &WOEADJ > 0 then G = &WOEADJ;
      else if B = 0 and &WOEADJ > 0 then B = &WOEADJ;      
      else call symput("STOP","YES");
      end;
   if _type_ = 1 then output;
   if eof and (zero=0)
   then
   do;
      call symput("WOEADJ","N/A");
      end;
run;

Data _NULL_;
put "&num_levels";
put "&num_levels_minus1";

%IF &STOP = YES %THEN 
%DO;
   %LET ERROR_MSG1 = ZERO CELL DETECTED;
   %LET ERROR_MSG2 = CONSIDER SETTING WOEADJ = 0.5;   
   %LET ERROR_MSG3 = ENDING EXECUTION;
   %LET STOP = YES;
   %GOTO EXIT0;
   %END;

   *options nomlogic nomprint;


%MACRO BEST_COLLAPSE_LEVELS(NUM_LEVELS_R);

* If ___x_char is "missing" (num or char) then record is not processed by PROC MEANS;
PROC MEANS data = mean_in noprint; class ___x_char; var G B;
output out = mean_out(keep = ___x_char G B _type_)
sum = G B;
run;

DATA ___mean_out; set mean_out;
   if B > 0 then RatioGvB = G/B;
   Row_Total = G + B;
   ___Temp = translate(___x_char,'','#');
   LABEL RatioGvB = "G/B";
   LABEL ___Temp = "&X";
run;
%IF %UPCASE(&MODE) = A %THEN %DO;
PROC SORT data = ___mean_out; by _type_ RatioGvB;
%END;
run;
PROC PRINT data = ___mean_out label;
Var ___Temp _type_ G B RatioGvB Row_Total;;
title1 "NOD_BIN Version &version, RUN ON &SYSDATE &SYSTIME";
title2 "Dataset= &DATASET, Predictor= &X, Target= &Y, Method= &METHOD, Mode= &MODE, Miss= &MISS, Order= &ORDER"; 
title3 "Min_Pct = &MIN_PCT, Min_Num = &MIN_NUM, WOEADJ = &WOEADJ";
title4 " ";
title5 "Collapse Step: Levels = &num_levels_r., Collapse via Min Pct|Num = &Forced";
%IF &ORDER = D %THEN %DO;
title6 "&Y = 1 are displayed as G and &Y = 0 are displayed as B";
%END;
%ELSE %DO;
title6 "&Y = 0 are displayed as G and &Y = 1 are displayed as B";
%END;
%IF %UPCASE(&MODE) = A %THEN %DO;
title7 "Sorted by Ratio of G over B";
%END;

run;

DATA _NULL_;
call symput
   ('woe_file', compress("___"||substr("&X",1,min(22,length("&X")))||"_woe"));
run;
%PUT &woe_file;

DATA  
   denorm&num_levels_r
/* For woe_code */
   &woe_file.&num_levels_r
   (keep =  /*k word_p string woe*/ all_code /*code1 code3*/) 
/* END: For woe_code */
   mean_in(keep = ___x_char G B)
      ;
   SET mean_out end = eof;

/* For woe_code */
   length word word_p string $1000;
   length all_code $3100 code1 code3 $1000;

/* END: For woe_code */

   length MONOTONIC $3;
   Label MONOTONIC = "MONO";
   retain MONOTONIC;

   length L1 - L&num_levels_r $1000;
   length ___x_char $1000;
   array Gx{*} G1 - G&num_levels_r;
   array Bx{*} B1 - B&num_levels_r;
* Add arrays for Method C ;
   array Gxx{*} Gx1 - Gx&num_levels_r;
   array Bxx{*} Bx1 - Bx&num_levels_r; 
* END Add arrays ;   
   
   array LEVELx{*} $ L1 - L&num_levels_r;

   retain G_total B_Total k collapsing_to IV LL_Model LRCS LR_Chi_Sq_Prob;
   retain G1 - G&num_levels_r B1 - B&num_levels_r L1 - L&num_levels_r;

   if _type_ = 0
   then
   do;
      G_total = G;
      B_total = B;
      k = 0;
      IV = 0;
      LL_Model = 0;
      end;
   if _type_ = 1
   then
   do;
      k + 1;
      collapsing_to = k - 1;
      Gx{k} = G;
      Bx{k} = B;
      LEVELx{k} = trim(left(___x_char));
      IV = IV + (G/G_total - B/B_total)*log((G/G_total) / (B/B_total));
      LL_Model = LL_Model + G * log(G/(G+B)) + B * log(B/(G+B));

/* New section to create WOE variables for each iteration */

      woe = log( (G/G_total) / (B/B_total) );
      X_name = "&X";
      nn = 0;
      string = " ";

      ___temp = compress(translate(___x_char,'','#'));
      do until(word = '');
         nn = nn+1;
         word = scan(___temp, nn, "+");
         if word > '' 
         then
         do;
            if "&X_TYPE" = "C" then word_p = compress('"'||word ||'"');
             else if "&X_TYPE" = "N" then word_p = compress(word);
            if nn = 1 then string = compress(string || word_p);
            else if nn > 1 then string = compress(string || "," || word_p);
            end;  
         end;

      string = translate(string,' ','!');
 
      code1 = "if " || X_name || " in (";
      code3 = ") then " || compress(X_name ||"_woe") || " = " || woe; 
      all_code = left(trim(COMPBL(code1 || string || code3 || ";")));
      output &woe_file.&num_levels_r;

/* END: New section to create WOE variables for each iteration */

      end;

   if eof
   then
   do;
      Minus2_LL = -2*LL_Model;
      LRCS = -2 * (&LL_inter - LL_Model);
      LR_Chi_Sq_Prob = 1 - PROBCHI(LRCS,k-1);
      Entropy_base_e = -LL_Model / &NOBS;
      LABEL Minus2_LL = "-2*Log L";
      LABEL LR_Chi_Sq_Prob = "Prob(x > LR_Chi_Sq)";
      LABEL LRCS = "Lik-Ratio Chi_Sq";
      LABEL LL_Model = "LL for Model";
      LABEL Entropy_base_e = "Entropy \ (base e)";

      min_C = 99999999;
      min_C_force = 99999999;
      max_C = -9;
      X_STAT = 0;
      C_STAT = 0;
      Forced = "NO ";
      call symput('FORCED',"NO ");

      s0 = 0;
      %IF (%UPCASE(&MISS) = MISS) & (%UPCASE(&MODE) = J) %THEN s0 = 1; ;

      %IF (%UPCASE(&MISS_EXISTS) = N) %THEN s0 = 0; ;

      do i = 1 + s0 to &num_levels_r - 1;
         %IF (%UPCASE(&MODE) = A) %THEN %DO; do j = i+1 to &num_levels_r; %END;
         %IF (%UPCASE(&MODE) = J) %THEN %DO; do j = i+1 to i+1; %END;
            %IF (%UPCASE(&METHOD) = C)
            %THEN
            %DO;
               do ii = 1 + s0 to &num_levels_r;
                  Gxx{ii} = Gx{ii};
                  Bxx{ii} = Bx{ii};
                  end;     
               Gxx{i} = Gx{i} + Gx{j};
               Gxx{j} = 0;
               Bxx{i} = Bx{i} + Bx{j};
               Bxx{j} = 0;
               C_ij = 0;
               do ii = 1 + s0 to &num_levels_r - 1;
                  do jj = ii + 1 to &num_levels_r;
                     C_ij = C_ij + ABS(Bxx{ii}*Gxx{jj} - Gxx{ii}*Bxx{jj});
                     end;
                  end;
              %END;
 
            %IF (%UPCASE(&METHOD) = LL)
            %THEN
            %DO;
               L_i = Gx{i}*log(Gx{i}/(Gx{i}+Bx{i})) + Bx{i}*log(Bx{i}/(Gx{i}+Bx{i}));
               L_j = Gx{j}*log(Gx{j}/(Gx{j}+Bx{j})) + Bx{j}*log(Bx{j}/(Gx{j}+Bx{j}));
               C_ij = L_i + L_j - 
                  ( (Gx{i}+Gx{j})*log((Gx{i}+Gx{j})/(Gx{i}+Gx{j}+Bx{i}+Bx{j})) + 
                  (Bx{i}+Bx{j})*log((Bx{i}+Bx{j})/(Gx{i}+Gx{j}+Bx{i}+Bx{j})) );
               %END;

            %IF (%UPCASE(&METHOD) = IV)
            %THEN
            %DO;
               L_i = ( Gx{i}/G_total - Bx{i}/B_total ) * 
                     log( (Gx{i}/G_total) / (Bx{i}/B_total) );
               L_j = ( Gx{j}/G_total - Bx{j}/B_total ) * 
                     log( (Gx{j}/G_total) / (Bx{j}/B_total) );  
               C_ij = L_i + L_j -
                     ( (Gx{i} + Gx{j})/G_total - (Bx{i} + Bx{j})/B_total ) * 
                     log( ((Gx{i} + Gx{j})/G_total) / ((Bx{i} + Bx{j})/B_total) );
               %END;

            %IF ((%UPCASE(&METHOD) = IV) OR (%UPCASE(&METHOD) = LL))
            %THEN
            %DO; 
               if C_ij <= min_C_force AND
                  (
                  ((Gx{i}+Bx{i}) < (&MIN_PCT/100) * (G_total + B_total))
                  OR
                  ((Gx{i}+Bx{i}) < &MIN_NUM )
                  OR
                  ((Gx{j}+Bx{j}) < (&MIN_PCT/100) * (G_total + B_total))
                  OR
                  ((Gx{j}+Bx{j}) < &MIN_NUM ) 
                  )                  
               then
               do;
                  i_index_f = i;
                  j_index_f = j;
                  min_C_force = C_ij;
                  
                  FORCED = "YES";
                  call symput('FORCED',"YES"); 
                  
                  *PUT FORCED = ;
                  
                  end;                  
               else if C_ij <= min_C
               then
               do; 
                  i_index = i;
                  j_index = j;
                  min_C = C_ij;
                  
                  end;
                  
               if min_C_force < 99999999
               then
               do;
                  i_index = i_index_f;
                  j_index = j_index_f;
                  end;
 
               %END;
               
            END; /* END OF J loop */

         do j = i + 1 to &num_levels_r;
            C_STAT = C_STAT  + Bx{i}*Gx{j}; /* concordances only */
            X_STAT = X_STAT  + ABS(Bx{i}*Gx{j} - Gx{i}*Bx{j});
            end; /* END OF: J loop */
         end; /* END OF: I loop */

         if &num_levels_r >= 3 
         then
         do;
            LO = log((Gx{i_index}*Bx{j_index})/(Gx{j_index}*Bx{i_index}));
            LO_SD = 
               sqrt(1/Gx{i_index} + 1/Gx{j_index} + 1/Bx{i_index} + 1/Bx{j_index});
            LOplus2SD = LO + 2*LO_SD;
            LOminus2SD = LO - 2*LO_SD;
            end;
/* END: Calculations for LOR Report */
                  
      /* if &MODE = J, then c-stat and x-stat are computed only for non missing values */
      do i = 1 + s0 to &num_levels_r;
         C_STAT  = C_STAT + .5*Bx{i}*Gx{i}; /* add the Ties */
         END;

      if s0 = 1 then C_PAIR  = (B_TOTAL - Bx{1}) * (G_TOTAL - Gx{1});
         else C_PAIR  = B_TOTAL * G_TOTAL;
      C_STAT  = MAX( C_STAT  / C_PAIR,  1 - C_STAT  / C_PAIR );
      X_STAT  = .5 * (X_STAT  / C_PAIR  + 1);

      IF C_STAT - 0.000001 <= X_STAT <= C_STAT + 0.000001 THEN MONOTONIC = "YES"; ELSE MONOTONIC = "";

      OUTPUT denorm&num_levels_r;

      do i = 1 to &num_levels_r;
         if i = i_index or i = j_index 
            then ___x_char = compress(LEVELx{i_index}||"+"||LEVELx{j_index});
          else ___x_char = LEVELx{i};
         G = Gx{i};
         B = Bx{i};
         OUTPUT mean_in;
         end;

      end; /* END OF: if eof then do */
run;
PROC APPEND base = denorm data = denorm&num_levels_r force nowarn;
run;
%MEND;

%MACRO INTER;

%IF %sysfunc(EXIST(denorm)) = 1 %THEN %DO;
   PROC DELETE DATA = denorm;
   run;
   %END;

%do k = &num_levels %to 2 %by - 1;
   %BEST_COLLAPSE_LEVELS(&k);
   %end;
/* SUMMARY REPORT */
DATA denorm; Set denorm end=eof;
   length prior_Forced $3;
   retain prior_Minus2_LL prior_Forced;

   IF _N_ > 1 THEN DO;
      Nested_ChiSq = Minus2_LL - prior_Minus2_LL;
      Alpha_Nested_ChiSq = 1 - PROBCHI(Nested_ChiSq,1);
      If Forced = "YES" or prior_Forced = "YES" then Forced_Lag = "YES";
       Else Forced_Lag = "NO ";
      END;
   prior_Minus2_LL = Minus2_LL;
   prior_Forced = Forced;
   
   %DO i = 1 %TO &num_levels;
      Lx&i = compress(translate(L&i,'','#'));
      LABEL Lx&i = "L&i";
      %END;
   
   %IF %UPCASE(&MODE)=J & %UPCASE(&MISS)=MISS & &MISS_EXISTS=Y
   %THEN
   %DO;
      if eof 
      then
      do;
         X_STAT = .; C_STAT = .; MONOTONIC = "N/M";
         end;
      %END;
   LABEL x_stat = "X_STAT \ model c";
   LABEL LO = "LO Ratio \ after collapse";
   LABEL LO_SD = "LO Ratio \ Std Dev";
   LABEL Alpha_Nested_ChiSq = "Pr > ChiSq";
   LABEL Nested_ChiSq = "Nested \ ChiSq";
   LABEL Forced_Lag = "Collapse via \ Min Pct | Num";
run;
proc format;
   value missfmt .='N/M' other=[12.9];
run;  
PROC PRINT data = denorm noobs LABEL split = '\';
var K forced_lag IV Minus2_LL X_STAT
%IF (%UPCASE(&LL_STAT) = YES) %THEN 
   Entropy_base_e /*LRCS LR_ChiSq_Prob*/ Nested_ChiSq Alpha_Nested_ChiSq;
%IF (%UPCASE(&MODE) = J)
%THEN %DO;
   C_STAT MONOTONIC
   %END; 
%IF &VERBOSE = YES %THEN Lx1 - Lx&num_levels; ;
format IV X_STAT C_STAT missfmt.;
title3 "Min_Pct = &MIN_PCT, Min_Num = &MIN_NUM, WOEADJ = &WOEADJ";
title4 " ";
title5 "Summary Report";
%IF (%UPCASE(&LL_STAT) = YES & &num_levels > 2) %THEN %DO;
title6 "Consider stopping at k+1 if (Pr > ChiSq) < 0.05, or other alpha, at k";
%END;
run;

PROC PRINT data = denorm noobs LABEL SPLIT = '\';
var K /* IV X_STAT */ collapsing_to LO LO_SD LOminus2SD LOplus2SD;
format IV X_STAT LO LO_SD LOminus2SD LOplus2SD 8.5;
title3 "Min_Pct = &MIN_PCT, Min_Num = &MIN_NUM, WOEADJ = &WOEADJ";
title4 " ";
title5 "Log-odds Ratio with 95% CI";
title6 "Consider stopping at k if +/- 2SD interval after collapse omits zero";
WHERE K > 2;
run;

%IF (%UPCASE(&WOE) = WOE)
%THEN %DO;
   %do k = &num_levels %to 2 %by - 1;
      proc print data = &woe_file.&k noobs; var all_code;
      title4 " ";
      title5 "SAS code for woe transform for levels = &k, WOEADJ = &WOEADJ";
      run;
      %end;
   %END;

%MEND;

   %INTER;
   
title;
run;

EXIT: Data _NULL_;
run;
%EXIT0: data __x_exit_;
length error_msg $80;
error_msg = "&ERROR_MSG1"; output;
error_msg = "&ERROR_MSG2"; output;
error_msg = "&ERROR_MSG3"; output;

%IF &STOP = YES 
%THEN
%DO;
PROC PRINT data = __x_exit_;
title1 "NOD_BIN Version &version, RUN ON &SYSDATE &SYSTIME";
title2 
"Dataset= &DATASET, Predictor= &X, Target= &Y, Freq = &W, Method= &METHOD, Mode= &MODE, Miss= &MISS, Order= &ORDER";
title3 "Min_Pct = &MIN_PCT, Min_Num = &MIN_NUM, WOEADJ = &WOEADJ";
title4 " ";
%END;
run;
title;

%MEND;

