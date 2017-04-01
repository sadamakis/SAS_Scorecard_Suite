/*Macro that stores the name and the path of the current program into macro variables*/
%macro program
(
/*********************************************************************************/
/*Output*/
progName, /*Macro variable the contains the SAS file name*/
progPath /*Macro variable that contains the path where the SAS file is stored*/
);
%global &progName. &progPath.;

    %let progPathName = %sysfunc(GetOption(SysIn));
    %* if running in interactive mode, the above line will not work, and the next line should;
    %if  %length(&progPathName) = 0 %then %let progPathName = %sysget(SAS_ExecFilePath);

	%let &progName. = %scan(&progPathName., -1, '\');
	%let progColumn = %eval(%index(&progPathName., &&&progName..)-2);
	%let &progPath. = %substr(&progPathName., 1, &progColumn.);

%mend program;
%program
(
/*********************************************************************************/
/*Output*/
progName = programName, /*Macro variable the contains the SAS file name*/
progPath = programPath /*Macro variable that contains the path where the SAS file is stored*/
);

%include "&programPath.\00_Prepare_random_input_data.sas";
%include "&programPath.\01_Character_variables_recoding.sas";
%include "&programPath.\02_Numeric_variables_recoding.sas";
%include "&programPath.\03a_Variable_reduction_and_recoding.sas";
/*%include "&programPath.\03b_Convert_numeric_to_character.sas";*/
%include "&programPath.\04a_Model_building_one_sample.sas";
%include "&programPath.\05a_Bootstrapping_model_selection.sas";




