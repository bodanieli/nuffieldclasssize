/********************************************************************************
Title: Class Size and Human Capital Accumulation
Date: 13 Maz 2020
Programmer(s): Daniel Borbely & Markus Gehrsitz

This should be equivalent to the 006a-file.

********************************************************************************/ 
clear all
set more off 

forvalues year=2007(1)2018 { 

cd "$rawdata04/planner_instrument_imp"
use stagelevel_imputed_`year', clear 

/*Start with taking out the cohorts that the class planner would not compute with*/ 

/*This flags up a stage with less than 9 pupils, and then goes on the flag up the entire school*/
gen lowclasscount = 1 if stagecount<9 
replace lowclasscount = 0 if missing(lowclasscount) 
egen max_lowclass = max(lowclasscount) , by(seedcode wave) 

/*We basically have the same issue if a school is missing a stage. This is the same as having 
zero pupils in a stage which is less than 9, so the class planner will fail.
Let's flag those up as well: */
egen count_stage = count(studentstage) , by(seedcode wave)



/*We save the schools that can't be fed into the planner separately:*/
preserve 
keep if max_lowclass==1 | count_stage<7 
cd "$rawdata04/planner_instrument_imp"
save lowclass_stagelevel_`year', replace 
restore 


/*Now drop those non-feedable schools:*/
drop if max_lowclass==1 
drop if count_stage<7 


/*These are the stagelevel counts, i.e. the things that we want to feed into the class planner later on.*/
cd "$rawdata04/planner_instrument_imp"
save stagelevel_`year', replace 
/*now collapse by school to get each individual seedcode*/ 



/*Another piece is the list of seecodes, that is something that we will have to 
either loop over or create lines of code in R:*/


collapse (rawsum) stagecount, by(seedcode wave)
codebook seedcode /*checks out, 1,331 seeds, each unique*/ 
cd "$rawdata04/planner_instrument_imp"
save schoollevel_`year', replace 




/*Let's create the R-commands by hand, so we can then just copy paste them into R:*/
gen hyphen = `"""'
/*Break down to one line per seed: 
gen numclasses = 1
collapse (rawsum) numclasses (firstnm) Hyphen1, by(seed year) */ 

tostring seedcode, replace
tostring wave, replace

/*Saving-Command and opening command, for closing we just need a single line:*/
gen savecommand = "xl.workbook.save(" + hyphen + "instrumentconstructor" + wave + "_" + seedcode  + ".xlsx" + hyphen + ")"

gen opencommand = "shell.exec(" + hyphen + "instrumentconstructor" + wave + "_" + seedcode  + ".xlsx" + hyphen + ")"





/*This will do for our Part1-R-File:*/
preserve
keep savecommand
cd "$rawdata04/planner_instrument_imp" 
export excel using "commands_part1_`year'.xlsx", replace
restore




/***************************************************************************************************
PREPARATION FOR PART 3:
For Part 3, we need three commands in a row: Open, save, and close (not sure if we need save):
****************************************************************************************************/

clear all

cd "$rawdata04/planner_instrument_imp"
use schoollevel_`year', clear 

gen hyphen = `"""'
/*Break down to one line per seed: 
gen numclasses = 1
collapse (rawsum) numclasses (firstnm) Hyphen1, by(seed year) */ 

tostring seedcode, replace
tostring wave, replace


/*OK, for this to run, we need first the commands underneath one another.
In other words, one row with the open command, then one with the save, then one with close:
*/

/*three copies per row:*/
expand 3
sort seedcode
gen rownumber = _n

gen opencommand = "shell.exec(" + hyphen + "instrumentconstructor" + wave + "_" + seedcode  + ".xlsx" + hyphen + ")"
gen savecommand = "xl.workbook.save(" + hyphen + "instrumentconstructor" + wave + "_" + seedcode  + ".xlsx" + hyphen + ")"
gen closecommand = "xl.workbook.close()"

/*global rows _N
display $rows */ 

summarize stagecount
forvalues i = 1(3)`r(N)'  {
replace savecommand=""  if rownumber==`i'
replace closecommand="" if rownumber==`i'
}

summarize stagecount
forvalues i = 2(3)`r(N)' {
replace opencommand=""  if rownumber==`i'
replace closecommand="" if rownumber==`i'
}

summarize stagecount
forvalues i = 3(3)`r(N)'{
replace opencommand=""  if rownumber==`i'
replace savecommand=""  if rownumber==`i'
}


keep opencommand savecommand closecommand
cd "$rawdata04/planner_instrument_imp"
export excel using "commands_part3_`year'.xlsx", replace
}
