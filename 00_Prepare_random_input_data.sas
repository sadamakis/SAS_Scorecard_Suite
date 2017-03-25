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
/* Program Name:             ---  00_Prepare_input_data.sas                                              */
/* Description:              ---  User-amendable code that should create a table that has exactly the 
following variables: 
 - target variable
 - weight 
 - ID (key) variable - unique identifier for every row in the dataset
 - predictors (both numerical and categorical)                                                          */
/*                                                                                                      */
/* Date Originally Created:  ---                                                                        */
/* Date Updated:             ---                                                                        */
/* Code Version:             ---  v1.0                                                                  */
/*------------------------------------------------------------------------------------------------------*/

/*********************************************************************************/
/***********   Start parameters configuration    ***************/
/*********************************************************************************/
/*Set path that will have the output and log files that are produced from this code*/
%let output_files = X:\Decision_Science\01_Model_Development\21_VBL_Cards\02_Acquisitions\VB_UKCC_AF001\Code\Productionise macros\Scorecard_suite\Logs;
/*Set the path that contains the table with:
 - target variable
 - weight 
 - ID variable
 - predictors (both numerical and categorical)*/
/*Set the path that contains the output tables from this code*/
%let outpath = X:\Data_Mart\Analysis\Decision_Science\01_UK\Vanquis\Cards\02_Acquisitions\01_Model_Development\VB_UKCC_AF01\01_Database_Design\Productionise macros;
/*********************************************************************************/
/***********   End parameters configuration     ***************/
/*********************************************************************************/

options compress=yes;

libname outdata "&outpath.";

/*********************************************************************************/
/*********************************************************************************/
%let datetime_var = %sysfunc(compress(%sysfunc(datetime(),datetime20.0),':'));
filename output0 "&output_files.\00_Prepare_input_data_output_&datetime_var..log";
filename logout0 "&output_files.\00_Prepare_input_data_log_&datetime_var..log";
proc printto print=output0 log=logout0 new;
run;
/*********************************************************************************/
/*********************************************************************************/

proc datasets lib=work kill nolist memtype=data;
quit;

data outdata.original_table (drop= i u1);
do i=1 to 10000;
/***********************************************************************************************/
/*Target variable*/
	bad_flag = RAND('BERNOULLI', 0.5);
/*ID variable*/
	transact_id = i;
/*Sampling weight*/
	weight = RAND('GAMMA', 1) + 0.5;
/***********************************************************************************************/
	u1 = uniform(123);
	if u1<0.1 then do;
		numeric1 = RAND('NORMAL', 100, 20);
		numeric2 = RAND('POISSON', 50);
		numeric3 = 10*RAND('LOGNORMAL');
		numeric4 = 10*RAND('BETA', 1, 3);
		numeric5 = 5;
		character1 = strip(put(RAND('POISSON', 1), 6.));
		character2 = strip(put(RAND('POISSON', 4), 6.));
		character3 = strip(put(RAND('POISSON', 50), 6.));
		character4 = 'test';
		character5 = 'Y';
	end;
	else if u1<0.5 then do;
		numeric1 = RAND('NORMAL', 150, 40);
		numeric2 = RAND('POISSON', 10);
		numeric3 = 20*RAND('LOGNORMAL');
		numeric4 = 20*RAND('BETA', 10, 30);
		numeric5 = 5;
		character1 = strip(put(RAND('POISSON', 2), 6.));
		character2 = strip(put(RAND('POISSON', 3), 6.));
		character3 = strip(put(RAND('POISSON', 100), 6.));
		character4 = 'test';
		character5 = 'Y';
	end;
	else if u1<0.9 then do;
		numeric1 = RAND('NORMAL', 200, 50);
		numeric2 = RAND('POISSON', 80);
		numeric3 = 15*RAND('LOGNORMAL');
		numeric4 = 30*RAND('BETA', 5, 40);
		numeric5 = 5;
		character1 = strip(put(RAND('POISSON', 3), 6.));
		character2 = strip(put(RAND('POISSON', 2), 6.));
		character3 = strip(put(RAND('POISSON', 80), 6.));
		character4 = 'test';
		character5 = 'Y';
	end;
	else do;
		numeric1 = RAND('NORMAL', 50, 5);
		numeric2 = RAND('POISSON', 120);
		numeric3 = 50*RAND('LOGNORMAL');
		numeric4 = 5*RAND('BETA', 100, 250);
		numeric5 = 5;
		character1 = strip(put(RAND('POISSON', 4), 6.));
		character2 = strip(put(RAND('POISSON', 1), 6.));
		character3 = strip(put(RAND('POISSON', 10), 6.));
		character4 = 'test';
		character5 = 'Y';
	end;

	if bad_flag=1 then do;
		numeric6 = RAND('NORMAL', 1000, 70);
		numeric7 = RAND('POISSON', 500);
		character6 = strip(put(RAND('POISSON', 10), 6.));
		character7 = strip(put(RAND('POISSON', 50), 6.));
	end;
	else do;
		numeric6 = RAND('NORMAL', 800, 200);
		numeric7 = RAND('POISSON', 600);
		character6 = strip(put(RAND('POISSON', 8), 6.));
		character7 = strip(put(RAND('POISSON', 70), 6.));
	end;

	numeric8 = numeric6 + 20*RAND('UNIFORM');
	character8 = strip(put(character7*1 + RAND('POISSON', 2), 6.));

	if RAND('UNIFORM')<0.01 then numeric1 = .;
	if RAND('UNIFORM')<0.02 then numeric2 = .;
	if RAND('UNIFORM')<0.99 then numeric3 = .;
	if RAND('UNIFORM')<0 then numeric4 = .;
	if RAND('UNIFORM')<0.01 then numeric5 = .;
	if RAND('UNIFORM')<0 then character1 = '';
	if RAND('UNIFORM')<0.01 then character2 = '';
	if RAND('UNIFORM')<0.05 then character3 = '';
	if RAND('UNIFORM')<0.99 then character4 = '';

output;
end;
run;

data outdata.original_table_dev_val_split;
	set outdata.original_table (keep= transact_id);
/*Set the flag that identifies development dataset (development_flag=1) and validation dataset (development_flag=0)*/
	development_flag = RAND('BERNOULLI', 0.7);;
run;

/*********************************************************************************/
/*********************************************************************************/

proc printto;
run;
