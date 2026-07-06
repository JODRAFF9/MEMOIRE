*Mini Thesis TRAORE SIE RACHID, ENGINEER STUDENT IN STATISTICS AND ECONOMICS
******************************PARAMETERIZATION*********************************
clear all

cap mkdir img
cap mkdir dat

global dirimg "img"
global dirdat "dat"


use"https://raw.githubusercontent.com/JODRAFF9/base_ehcvm18/663df0e559ab12bdd4e634d53754b5193fbed135/ehcvm_individu_sen2018.dta", clear

save "$dirdat\ehcvm_individu_sen2018.dta",replace

use "https://raw.githubusercontent.com/JODRAFF9/base_ehcvm18/663df0e559ab12bdd4e634d53754b5193fbed135/ehcvm_welfare_sen2018.dta", clear

save "$dirdat\ehcvm_welfare_SEN2018.dta",replace

merge 1:m hhid using "$dirdat\ehcvm_individu_sen2018.dta",nogen

* Preliminary calculations: Construction of scenario variables

gen under2=(age<=2)
gen under5=(age<=5)
gen under18=(age<=18)
gen old=(age>=65)
gen handicap=(handig==1)

keep hhid under2 under5 under18 old handicap

collapse (sum) under2 under5 under18 old handicap, by(hhid)

merge 1:1 hhid using "$dirdat\ehcvm_welfare_SEN2018.dta",nogen

save "$dirdat\welfare_TP_ISEE2025",replace

* Individual household weight calculation

gen poid=hhweight*hhsize
egen strate = group(region milieu)
svyset grappe [pweight=poid], strata(strate) || menage

*** SPECIFIC GUIDANCE
* *********************************************
*1)

/*
Data Aging : Since the dataset originates from a 2018 survey, adjustments must be made to simulate the conditions of 2025. This process, referred to as data aging, will align the dataset with the economic and demographic context of 2025. The following variables should be used to age the data appropriately: 
*/

*a. Population: Update population figures to reflect projected growth. 

scalar tcam18_24=0.029

gen hhweight24=hhweight*(1+tcam18_24)^6

*b. GDP and GDP per Capita: Adjust for anticipated changes in overall economic output and income per individual. 

** BCEAO

total hhweight
total poid

scalar pop18= r(table)[1,1]
scalar pop24=  18593261

scalar gdpc18=12840100000000/pop18
scalar gdpc24=20365600000000/pop24

scalar tcgdp18_24=(gdpc24-gdpc18)/gdpc18

gen dtot24=dtot*(1+tcgdp18_24)

**calcul du pcexp actualisé (2024)
gen pcexp24=dtot24/(hhsize*def_spa*def_temp)

*c. Price Indexes: Incorporate inflationary effects to reflect changes in purchasing power and cost of living over time. 

scalar ipc18=103.7
scalar ipc24=128.56

scalar tc_ipc18_24=(ipc24-ipc18)/ipc18
gen zref24=zref*(1+tc_ipc18_24)

putexcel set "$dirdat\results.xlsx", replace sheet("data aging")

putexcel A1 = ("DATA AGING - Key results")
putexcel A2 = ("Indicator") B2 = ("Value")

putexcel A3 = ("Population 2018") B3 = (pop18)
putexcel A4 = ("Population 2024") B4 = (pop24)
putexcel A5 = ("Average annual population growth (%)") B5 = (tcam18_24*100)

putexcel A6 = ("GDP per capita 2018") B6 = (gdpc18)
putexcel A7 = ("GDP per capita 2024" ) B7 = (gdpc24)
putexcel A8 = ("Average annual GDP per capita growth (%)") B8 = (tcgdp18_24*100)

putexcel A9 = ("Cumulative inflation (factor)") B9 = (tc_ipc18_24)

summarize zref
scalar z18 = r(mean)
putexcel A10 = ("Updated poverty threshold 2018") B10 = (z18)

summarize zref24
scalar z24 = r(mean)
putexcel A11 = ("Updated poverty threshold 2024") B11 = (z24)


* *********************************************
*2)

**Scenario Analysis:   Provide a comprehensive list of policy scenarios under consideration. For each scenario, include the cost of implementing the policy, presented in absolute monetary terms and the policy's cost share of GDP, indicating its proportional economic cost.

gen stipend=100000

*Scenario 1: Universal cash transfer
*All households receive an annual allowance of 100,000.

gen scen1=1
gen dtot24_1=dtot24+scen1*stipend

**Calculation of updated per capita expenditure (2024) with scen1
gen pcexp24_1=dtot24_1/(hhsize*def_spa*def_temp)

*Scenario 2: Universal cash transfer in rural areas
*All rural households receive the allowance.

gen scen2=(milieu==2)
gen dtot24_2=dtot24+scen2*stipend

**Calculation of updated per capita expenditure (2024) with scen2
gen pcexp24_2=dtot24_2/(hhsize*def_spa*def_temp)

*Scenario 3: Households with children under 2 years
*Only households with children under 2 years receive the allowance.

gen scen3=(under2>=1)
gen dtot24_3=dtot24+scen3*stipend

**Calculation of updated per capita expenditure (2024) with scen3
gen pcexp24_3=dtot24_3/(hhsize*def_spa*def_temp)

*Scenario 4: Households with children under 2 years in rural areas
*Only rural households with a child under 2 years receive the allowance.

gen scen4=(milieu==2 & under2>=1)
gen dtot24_4=dtot24+scen4*stipend

**Calculation of updated per capita expenditure (2024) with scen4
gen pcexp24_4=dtot24_4/(hhsize*def_spa*def_temp)

*Scenario 5: Households with children under 5 years
*Only households with children under 5 years receive the allowance.

gen scen5=(under5>=1)
gen dtot24_5=dtot24+scen5*stipend

**Calculation of updated per capita expenditure (2024) with scen5
gen pcexp24_5=dtot24_5/(hhsize*def_spa*def_temp)

*Scenario 6: Households with children under 18 years
*Only households with children under 18 years receive the allowance.

gen scen6=(under18>=1)
gen dtot24_6=dtot24+scen6*stipend

**Calculation of updated per capita expenditure (2024) with scen6
gen pcexp24_6=dtot24_6/(hhsize*def_spa*def_temp)

*Scenario 7: Households with elderly members
*Only households with at least one member over 65 years receive the allowance.

gen scen7=(old>=1)
gen dtot24_7=dtot24+scen7*stipend

**Calculation of updated per capita expenditure (2024) with scen7
gen pcexp24_7=dtot24_7/(hhsize*def_spa*def_temp)

*Scenario 8: Households with at least one disabled member
*Only households with at least one disabled member receive the allowance.
gen scen8=(handicap>=1)
gen dtot24_8=dtot24+scen8*stipend

**Calculation of updated per capita expenditure (2024) with scen8
gen pcexp24_8=dtot24_8/(hhsize*def_spa*def_temp)

*Additionally, classify these scenarios visually by presenting a graph that ranks the policies from the most expensive to the least expensive. The graph should clearly illustrate the costs of each scenario to facilitate comparison and analysis.

preserve

* Calculate the total cost of each scenario

svy: total pcexp24
estimates store scen0

forvalues s=1/8 {
	svy: total pcexp24_`s'
	estimates store scen`s'
}

* Create a matrix to store the results
matrix costs = J(8, 2, .)
matrix colnames costs = "Scenario" "Cost"

* The total of pcexp without policies, which must be subtracted

estimates restore scen0
scalar cost0=e(b)[1,1]

* Store the results in the matrix

forvalues i = 1/8 {
    estimates restore scen`i'
    matrix costs[`i', 1] = `i' 
    matrix costs[`i', 2] = e(b)[1,1] - cost0
}

* Display the matrix
matrix list costs

* Convert the matrix into a dataset
clear
svmat costs, names(col)

label define scen_lbl 1 "UCT" 2 "Children under 18" 3 "Children under 5" 4 "People with Disability" 5 "Children under 2" 6 "Rural UCT" 7 "Children under 2 rural" 8 "Households with elder"
label values Scenario scen_lbl

gen scen_label = ""
replace scen_label = "UCT" if Scenario == 1
replace scen_label = "Children under 18" if Scenario == 2
replace scen_label = "Children under 5" if Scenario == 3
replace scen_label = "People with Disability" if Scenario == 4
replace scen_label = "Children under 2" if Scenario == 5
replace scen_label = "Rural UCT" if Scenario == 6
replace scen_label = "Children under 2 rural" if Scenario == 7
replace scen_label = "Households with elder" if Scenario == 8

putexcel set "$dirdat\results.xlsx", modify sheet("scenario cost analysis")

* Write headers
putexcel A1 = ("Scenario") B1 = ("Cost (billions CFA)") C1 = ("Label")

* Write data row by row (example for 8 rows)
forvalues i = 1/8 {
    putexcel A`=`i'+1' = costs[`i',1] ///
             B`=`i'+1' = costs[`i',2] ///
             C`=`i'+1' = scen_label[`i']
}


* Sort scenarios from most expensive to least expensive
gsort -Cost


* First graph: cost in billion CFA
gen cost_billion=Cost/1000000000

set scheme s2mono

graph bar (mean) cost_billion, name(g1, replace) ///
    over(scen_label, sort(1) descending label(angle(0))) ///
    bar(1, fcolor(navy) lcolor(navy) lwidth(0.1))  ///
    plotregion(margin(zero)) ///
    graphregion(color(white) margin(l=8 r=8)) ///
    ytitle("") ///
    ylabel(, nogrid) ///
    blabel(bar, format(%9.1f)) ///
    title("") ///
    legend(off) ///
    horizontal

* Second graph: cost as % of GDP
* Definition of GDP in 2024

scalar gdp24 = 20365600000000

* Calculate cost as % of GDP

gen Cost_GDP = 100 * Cost / gdp24

* Round to two decimal places for numerical display
replace Cost_GDP = round(Cost_GDP, 0.01)
format Cost_GDP %9.2f

* Create a string variable with rounded value and % sign
gen str10 Cost_GDP_label = string(Cost_GDP, "%9.2f") + "%"

* Horizontal bar graph, with rounded numerical labels, no title
graph bar (mean) Cost_GDP, name(g2, replace) ///
    over(scen_label, sort(1) descending label(angle(0))) ///
    bar(1, fcolor(navy) lcolor(navy) lwidth(0.1)) ///
    plotregion(margin(zero)) ///
    graphregion(color(white) margin(l=8 r=8)) ///
    ytitle("") ///
    ylabel(, nogrid) ///
    blabel(bar, format(%9.2f)) ///
    title("") /// 
    legend(off) ///
    horizontal

graph export "$dirimg\g1.png", name(g1) replace
graph export "$dirimg\g2.png", name(g2) replace

putexcel set "$dirdat\results.xlsx", modify sheet("scenario cost analysis")
putexcel F2 = picture("$dirimg\g1.png")
putexcel P2 = picture("$dirimg\g2.png")

clear
input str30 category cost_billion cost_gdp
"UCT" 177.0 0.87
"Rural UCT" 159.3 0.78
"Children under 2" 123.6 0.61
"Children under 5" 90.0 0.44
"Children under 18" 89.3 0.44
"Children under 2 rural" 58.4 0.29
"People with Disability" 54.6 0.27
"Households with elder" 42.6 0.21
end

// Reverse the order to have "UCT" at the top
gen id = _n
gsort -id
replace id = _n

// Graph 1 - Cost in billions
twoway (bar cost_billion id, horizontal barwidth(0.6) color(navy) ///
        mlabel(cost_billion) mlabposition(0) mlabcolor(black) mlabsize(medium)), ///
       ylabel(1(1)8, valuelabel angle(0) nogrid noticks) ///
       ytitle("") xtitle("Billions of USD") ///
       xlabel(0(50)200, nogrid) ///
       ymlabel(1 "UCT   " 2 "Rural UCT   " 3 "Children under 2   " ///
               4 "Children under 5   " 5 "Children under 18   " ///
               6 "Children under 2 rural   " 7 "People with Disability   " ///
               8 "Households with elder   ", angle(0) labsize(small)) ///
       title("Cost in Billions USD") ///
       xsize(10) ysize(8) graphregion(margin(l=5 r=5)) ///
       name(g1, replace) nodraw

//  Graph 2 - Cost as percentage of GDP
twoway (bar cost_gdp id, horizontal barwidth(0.6) color(navy) ///
        mlabel(cost_gdp) mlabposition(0) mlabcolor(black) mlabsize(medium) ///
        mlabformat(%4.2f)), ///
       ylabel(1(1)8, nogrid noticks) ///
       ytitle("") xtitle("% of GDP") ///
       xlabel(0(0.2)1, nogrid) ///
       title("Cost as % of GDP") ///
       xsize(10) ysize(8) graphregion(margin(l=5 r=5)) ///
       name(g2, replace) nodraw

// Combine both graphs side by side
graph combine g1 g2, cols(2) imargin(0 0 0 0) graphregion(color(white))
restore
* *********************************************
*3

**After aging the data to simulate the 2024 economic and demographic context, recalculate  the FGT and Gini indicators for 2024. 

**Compare the 2018 and 2024 indicators to analyze  how poverty and inequality measures evolve over time, providing insights into the potential impacts of cash transfer policies.

**************************************************
***********************          BASELINE 2018
**************************************************
*** Poverty measurement
*** Poverty threshold

sum zref

*** Average consumption expenditures and poverty threshold
*National
svy: mean pcexp

*Dakar urban 
svy: mean pcexp if milieu==1 & region==1

*Autres urbans
svy: mean pcexp if milieu==1 & region!=1

*Rural  
svy: mean pcexp if milieu!=1


*** variable poor

gen poor=(zref>pcexp)

label variable poor "poverty status according to EHCVM"
label define poor_label 0 "no poor" 1 "poor"
label values poor poor_label
svy: tab poor , percent

* FGT0 : Poverty rate
summarize poor
svy: mean poor
scalar fgt0=r(table)[1,1]*100
display "FGT0 (Incidence) = "  %9.2f fgt0

* FGT1 (α = 1)
gen gap = ((zref - pcexp)/zref) * poor
summarize gap
svy: mean gap
scalar fgt1=r(table)[1,1]
display "FGT1 (Poverty depth) = " %9.4f fgt1

* FGT2 (α = 2)
gen gap2 = ((zref - pcexp)/zref)^2 * poor
svy: mean gap2
scalar fgt2=r(table)[1,1]
display "FGT2 (Poverty severity) = "  %9.4f fgt2

* Geographic disaggregation

* urban
summarize poor if milieu==1
svy: mean poor if milieu==1
scalar fgt0_urb = r(table)[1,1]*100
display "FGT0 urban = "  %9.2f fgt0_urb "%"

summarize gap if milieu==1
svy: mean gap if milieu==1
scalar fgt1_urb = r(table)[1,1]
display "FGT1 urban  = " %9.4f fgt1_urb

svy: mean gap2 if milieu==1
scalar fgt2_urb = r(table)[1,1]
display "FGT2 urban = " %9.4f fgt2_urb

* Rural
summarize poor if milieu==2
svy: mean poor if milieu==2
scalar fgt0_rur = r(table)[1,1]*100
display "FGT0 rural= "  %9.2f fgt0_rur "%"

summarize gap if milieu==2
svy: mean gap if milieu==2
scalar fgt1_rur = r(table)[1,1]
display "FGT1 rural = " %9.4f fgt1_rur

svy: mean gap2 if milieu==2
scalar fgt2_rur = r(table)[1,1]
display "FGT2 rural = " %9.4f fgt2_rur


* Gini calculation on pcexp variable

preserve

* Sort by ascending pcexp

gsort pcexp

* Number of observations

count
local n = r(N)

* Total income calculation

summarize pcexp
local total = r(sum)

* Calculate cumulative income sum

gen rank = _n
gen cum_pop = rank / `n'

* Calculate cumulative income shares

gen cum_income = sum(pcexp)

* Calculate cumulative income shares

gen cum_income_prop = cum_income / `total'

* Add point (0,0) for Lorenz curve

gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])

* Calculate area under Lorenz curve (trapezoid method)

gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2

* Sum of areas

summarize trapeze_area, meanonly
local B = r(sum)

* Calculate Gini index

display "Gini index = " 1 - 2 * `B'

scalar gini_2018=1 - 2 * `B'
restore

* Urban Gini

preserve
keep if milieu==1
gsort pcexp

count
local n = r(N)

summarize pcexp
local total = r(sum)

gen rank = _n
gen cum_pop = rank / `n'
gen cum_income = sum(pcexp)
gen cum_income_prop = cum_income / `total'
gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])
gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2
summarize trapeze_area, meanonly
local B_urban = r(sum)
display "Urban Gini  = " 1 - 2 * `B_urban'
scalar gini_18_urban = 1 - 2 * `B_urban'
restore

* Rural Gini

preserve
keep if milieu==2
gsort pcexp

count
local n = r(N)

summarize pcexp
local total = r(sum)

gen rank = _n
gen cum_pop = rank / `n'
gen cum_income = sum(pcexp)
gen cum_income_prop = cum_income / `total'
gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])
gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2
summarize trapeze_area, meanonly
local B_rural = r(sum)
display "Gini rural = " 1 - 2 * `B_rural'
scalar gini_18_rural = 1 - 2 * `B_rural'
restore


**************************************************
***********************          BASELINE 2024
**************************************************

gen poid24=hhweight24*hhsize
svyset grappe [pweight=poid24], strata(strate) || menage


***  Poverty measurement

*** Poverty threshold

sum zref24

***  Average consumption expenditures and poverty threshold
*National
svy: mean pcexp24

* Urban Dakar 
svy: mean pcexp24 if milieu==1 & region==1

* Other urban areas
svy: mean pcexp24 if milieu==1 & region!=1

* Rural  
svy: mean pcexp24 if milieu!=1


*** Poor variable

gen poor24=(zref24>pcexp24)

label variable poor24 "poverty status according to EHCVM"
label values poor24 poor_label

svy: tab poor24 , percent

* FGT0: Poverty rate
summarize poor24
svy: mean poor24
scalar fgt0_24= r(table)[1,1]*100
display "FGT0 (Incidence) = "  %9.2f fgt0_24

* FGT1 (α = 1)
gen gap_24 = ((zref24 - pcexp24)/zref24) * poor24
summarize gap_24
svy: mean gap_24
scalar fgt1_24= r(table)[1,1]

display "FGT1 (Poverty depth) = " %9.4f fgt1_24

* FGT2 (α = 2)
gen gap2_24 = ((zref24 - poor24)/zref24)^2 * poor24
svy: mean gap2_24
scalar fgt2_24=r(table)[1,1]
display "FGT2 (Poverty severity) = " %9.4f fgt2_24


* Geographic disaggregation
* Urban
summarize poor24 if milieu==1
svy: mean poor24 if milieu==1
scalar fgt0_24_urb = r(table)[1,1]*100
display "FGT0 urban= "  %9.2f fgt0_24_urb "%"

summarize gap_24 if milieu==1
svy: mean gap_24 if milieu==1
scalar fgt1_24_urb = r(table)[1,1]
display "FGT1 urban = " %9.4f fgt1_24_urb

svy: mean gap2_24 if milieu==1
scalar fgt2_24_urb = r(table)[1,1]
display "FGT2 urban = " %9.4f fgt2_24_urb

* Rural
summarize poor24 if milieu==2
svy: mean poor24 if milieu==2
scalar fgt0_24_rur = r(table)[1,1]*100
display "FGT0 rural= "  %9.2f fgt0_24_rur "%"

summarize gap_24 if milieu==2
svy: mean gap_24 if milieu==2
scalar fgt1_24_rur = r(table)[1,1]
display "FGT1 rural = " %9.4f fgt1_24_rur

svy: mean gap2_24 if milieu==2
scalar fgt2_24_rur = r(table)[1,1]
display "FGT2 rural = " %9.4f fgt2_24_rur

* Gini calculation on pcexp variable
preserve
* Sort by ascending pcexp
gsort pcexp24

* Number of observations
count
local n = r(N)

* Total income calculation
summarize pcexp24
local total = r(sum)

* Generate rank and cumulative population shares
gen rank = _n
gen cum_pop = rank / `n'

* Calculate cumulative income sum
gen cum_income = sum(pcexp24)

* Calculate cumulative income shares
gen cum_income_prop = cum_income / `total'

* Add point (0,0) for Lorenz curve
gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])

* Calculate area under Lorenz curve (trapezoid method)
gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2

* Sum of areas
summarize trapeze_area, meanonly
local B = r(sum)

* Calculate Gini index

display "Gini index = " 1 - 2 * `B'
scalar gini_2024=1 - 2 * `B'
restore

* Urban Gini
preserve
keep if milieu==1
gsort pcexp24

count
local n = r(N)

summarize pcexp24
local total = r(sum)

gen rank = _n
gen cum_pop = rank / `n'
gen cum_income = sum(pcexp24)
gen cum_income_prop = cum_income / `total'
gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])
gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2
summarize trapeze_area, meanonly
local B_urban = r(sum)
display "Urban Gini  = " 1 - 2 * `B_urban'
scalar gini_24_urban = 1 - 2 * `B_urban'
restore

* Rural Gini
preserve
keep if milieu==2
gsort pcexp24

count
local n = r(N)

summarize pcexp24
local total = r(sum)

gen rank = _n
gen cum_pop = rank / `n'
gen cum_income = sum(pcexp24)
gen cum_income_prop = cum_income / `total'
gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])
gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2
summarize trapeze_area, meanonly
local B_rural = r(sum)
display "Gini rural = " 1 - 2 * `B_rural'
scalar gini_24_rural = 1 - 2 * `B_rural'
restore

putexcel set "$dirdat\results.xlsx", modify sheet("baselines analysis")

matrix baselinepov = J(2,3,.)

matrix baselinepov[1,1] = fgt0
matrix baselinepov[1,2] = fgt1
matrix baselinepov[1,3] = fgt2


matrix baselinepov[2,1] = fgt0_24
matrix baselinepov[2,2] = fgt1_24
matrix baselinepov[2,3] = fgt2_24


matrix colnames baselinepov =  FGT0 FGT1 FGT2
matrix rownames baselinepov =  2018 2024
matrix list baselinepov

putexcel A1 = matrix(baselinepov), names

putexcel A5=2018

matrix baselinepov1 = J(2,3,.)

matrix baselinepov1[1,1] = fgt0_urb
matrix baselinepov1[1,2] = fgt1_urb
matrix baselinepov1[1,3] = fgt2_urb

matrix baselinepov1[2,1] = fgt0_rur
matrix baselinepov1[2,2] = fgt1_rur
matrix baselinepov1[2,3] = fgt2_rur

matrix colnames baselinepov1= FGT0 FGT1 FGT2
matrix rownames baselinepov1 = urban Rural
matrix list baselinepov1
putexcel A6 = matrix(baselinepov1), names

putexcel A10=2024
matrix baselinepov2 = J(2,3,.)

matrix baselinepov2[1,1] = fgt0_24_urb
matrix baselinepov2[1,2] = fgt1_24_urb
matrix baselinepov2[1,3] = fgt2_24_urb

matrix baselinepov2[2,1] = fgt0_24_rur
matrix baselinepov2[2,2] = fgt1_24_rur
matrix baselinepov2[2,3] = fgt2_24_rur

matrix colnames baselinepov2 = FGT0 FGT1 FGT2
matrix rownames baselinepov2 = urban Rural
matrix list baselinepov2

putexcel A11 = matrix(baselinepov2), names

matrix baselineinequ = J(2,1,.)

matrix baselineinequ[1,1] = gini_2018
matrix baselineinequ[2,1] = gini_2024

matrix colnames baselineinequ =  "Gini index" 
matrix rownames baselineinequ =  2018 2024
matrix list baselineinequ

putexcel A15 = matrix(baselineinequ), names

putexcel A20=2018

matrix baselineinequ1 = J(2,1,.)

matrix baselineinequ1[1,1] = gini_18_urban
matrix baselineinequ1[2,1] = gini_18_rural

matrix colnames baselineinequ1=  "Gini index" 
matrix rownames baselineinequ1 = urban Rural
matrix list baselineinequ1
putexcel A21 = matrix(baselineinequ1), names

putexcel A25=2024
matrix baselineinequ2 = J(2,1,.)

matrix baselineinequ2[1,1] = gini_24_urban
matrix baselineinequ2[2,1] = gini_24_rural

matrix colnames baselineinequ2 = "Gini index" 
matrix rownames baselineinequ2 = urban Rural
matrix list baselineinequ2

putexcel A26 = matrix(baselineinequ2), names

putexcel set "$dirdat\results.xlsx", modify sheet("baselines analysis")

**************************************************
***********************                   ENDLINE
**************************************************

forvalues s = 1/8 {
	di "**************************************************"
	di "********** scenario `s' **********"
	di "**************************************************"
    * Calculate average consumption expenditures svy: mean pcexp24_s
    svy: mean pcexp24_`s'

    * Generate poor variable
    gen poor24_`s' = (zref24 > pcexp24_`s')
    label variable poor24_`s' "statut de pauvreté selon l'EHCVM"
    label values poor24_`s' poor_label

    svy: tab poor24_`s', percent

    * FGT0: Poverty rate
	
    summarize poor24_`s'
    svy: mean poor24_`s'
    scalar fgt0_24_`s' = r(table)[1,1]*100
    display "FGT0 (Incidence) scenario `s' = "  %9.2f fgt0_24_`s' "%"

    * FGT1 (α = 1)
	
    gen gap_24_`s' = ((zref24 - pcexp24_`s') / zref24) * poor24_`s'
    summarize gap_24_`s'
    svy: mean gap_24_`s'
    scalar fgt1_24_`s' = r(table)[1,1]
    display "FGT1 (Poverty depth) scenario `s' = " %9.4f fgt1_24_`s'

    * FGT2 (α = 2)
	
    gen gap2_24_`s' = ((zref24 - pcexp24_`s') / zref24)^2 * poor24_`s'
    svy: mean gap2_24_`s'
    scalar fgt2_24_`s' = r(table)[1,1]
    display "FGT2 (Poverty severity) scenario `s' = " %9.4f fgt2_24_`s'

    * Calculate scenario efficiency
	
    estimates restore scen0
    scalar cost0 = e(b)[1,1]

    estimates restore scen`s'
    scalar cost_s = e(b)[1,1]

    scalar efficiency_`s' = (fgt1_24 - fgt1_24_`s') * 1000000000 / (cost_s - cost0)
    display "Efficiency scenario `s' = "  %9.8f efficiency_`s' " per billion CFA mobilized"

    * Contribution to FGT indicators reduction
	
    display "FGT0 reduction scenario  `s' = " fgt0_24 - fgt0_24_`s'
    display "FGT1 reduction scenario `s' = " fgt1_24 - fgt1_24_`s'
    display "FGT2 reduction scenario `s' = " fgt2_24 - fgt2_24_`s'

    * Geographic disaggregation

    * Urban
	
    summarize poor24_`s' if milieu==1
    svy: mean poor24_`s' if milieu==1
    scalar fgt0_24_`s'_urb = r(table)[1,1]*100
    display "FGT0 urban scenario `s' = "  %9.2f fgt0_24_`s'_urb "%"

    summarize gap_24_`s' if milieu==1
    svy: mean gap_24_`s' if milieu==1
    scalar fgt1_24_`s'_urb = r(table)[1,1]
    display "FGT1 urban scenario`s' = " %9.4f fgt1_24_`s'_urb

    svy: mean gap2_24_`s' if milieu==1
    scalar fgt2_24_`s'_urb = r(table)[1,1]
    display "FGT2 urban scenario `s' = " %9.4f fgt2_24_`s'_urb

    * Rural
    summarize poor24_`s' if milieu==2
    svy: mean poor24_`s' if milieu==2
    scalar fgt0_24_`s'_rur = r(table)[1,1]*100
    display "FGT0 rural scenario `s' = "  %9.2f fgt0_24_`s'_rur "%"

    summarize gap_24_`s' if milieu==2
    svy: mean gap_24_`s' if milieu==2
    scalar fgt1_24_`s'_rur = r(table)[1,1]
    display "FGT1 rural scenario `s' = " %9.4f fgt1_24_`s'_rur

    svy: mean gap2_24_`s' if milieu==2
    scalar fgt2_24_`s'_rur = r(table)[1,1]
    display "FGT2 rural scenario `s' = " %9.4f fgt2_24_`s'_rur

    * Calculate Gini index
	
    preserve
    gsort pcexp24_`s'
    count
    local n = r(N)
    summarize pcexp24_`s'
    local total = r(sum)
    gen rank = _n
    gen cum_pop = rank / `n'
    gen cum_income = sum(pcexp24_`s')
    gen cum_income_prop = cum_income / `total'
    gen cum_pop0 = cond(_n==1, 0, cum_pop[_n-1])
    gen cum_income_prop0 = cond(_n==1, 0, cum_income_prop[_n-1])
    gen trapeze_area = (cum_pop - cum_pop0) * (cum_income_prop + cum_income_prop0) / 2
    summarize trapeze_area, meanonly
    local B = r(sum)
    display "Gini index scenario `s' = " 1 - 2 * `B'
	scalar gini_`s' = 1 - 2 * `B'
    restore

    di "********** End scenario `s' **********"
}


display "Scenario    Gini Index"
forvalues s = 1/8 {
    display "`s'           " %9.6f gini_`s'
}

matrix GiniIndex = J(10,1,.)
matrix GiniIndex[1,1] = gini_2018
matrix GiniIndex[2,1] = gini_2024

forvalues t = 3/10 {
    local s = `t' - 2
    matrix GiniIndex[`t',1] = gini_`s'
}

matrix colnames GiniIndex = "Gini index"
matrix rownames GiniIndex = "2018" "2024" "UCT" "Children under 18" "Children under 5" "People with Disability" "Children under 2" "Rural UCT" "Children under 2 rural" "Households with elder"

putexcel set "$dirdat\results.xlsx", modify sheet("Gini Analysis")
putexcel A1 = matrix(GiniIndex), names

*******************************************************
***********************     GLOBAL SCENARIO ANALYSIS
*******************************************************

matrix results = J(10,11,.)

matrix results[1,1] = 2018
matrix results[1,2] = fgt0
matrix results[1,3] = fgt1
matrix results[1,4] = fgt2
matrix results[1,5] = .
matrix results[1,6] = fgt0_rur
matrix results[1,7] = fgt0_urb
matrix results[1,8] = fgt1_rur
matrix results[1,9] = fgt1_urb
matrix results[1,10] = fgt1_rur
matrix results[1,11] = fgt1_urb

matrix results[2,1] = 2024
matrix results[2,2] = fgt0_24
matrix results[2,3] = fgt1_24
matrix results[2,4] = fgt2_24
matrix results[2,5] = .
matrix results[2,6] = fgt0_24_rur
matrix results[2,7] = fgt0_24_urb
matrix results[2,8] = fgt1_24_rur
matrix results[2,9] = fgt1_24_urb
matrix results[2,10] = fgt1_24_rur
matrix results[2,11] = fgt1_24_urb
local i = 3
forvalues s = 1/8 {
    matrix results[`i',1] = `s'
    matrix results[`i',2] = fgt0_24_`s'
    matrix results[`i',3] = fgt1_24_`s'
    matrix results[`i',4] = fgt2_24_`s'
    matrix results[`i',5] = efficiency_`s'
    matrix results[`i',6] = fgt0_24_`s'_rur
    matrix results[`i',7] = fgt0_24_`s'_urb
	matrix results[`i',8] = fgt1_24_`s'_rur
    matrix results[`i',9] = fgt1_24_`s'_urb
	matrix results[`i',10] = fgt2_24_`s'_rur
    matrix results[`i',11] = fgt2_24_`s'_urb
    local ++i
}

matrix colnames results = scenario FGT0 FGT1 FGT2 Efficacité FGT0_Rural FGT0_urban FGT1_Rural FGT1_urban FGT2_Rural FGT2_urban
matrix rownames results = "Year" "Year" "UCT" "Children under 18" "Children under 5" "People with Disability" "Children under 2" "Rural UCT" "Children under 2 rural" "Households with elder"
matrix list results

putexcel set "$dirdat\results.xlsx", modify sheet("summary")
putexcel A1 = matrix(results), names

clear
svmat results, names(col)

gen label = ""
replace label = "2018" if scenario == 2018
replace label = "2024" if scenario == 2024
replace label = "UCT" if scenario == 1
replace label = "Children under 18" if scenario == 2
replace label = "Children under 5" if scenario == 3
replace label = "People with Disability" if scenario == 4
replace label = "Children under 2" if scenario == 5
replace label = "Rural UCT" if scenario == 6
replace label = "Children under 2 rural" if scenario == 7
replace label = "Households with elder" if scenario == 8

gen id = _n

twoway ///
(line FGT0 id, lcolor(gs12)) /// 
(scatter FGT0 id, msymbol(circle) mcolor(blue)) /// 
, ///
xlabel(1 "2018" 2 "2024" 3 "UCT" 4 "Children <18" 5 "Children <5" ///
        6 "Disability" 7 "Children <2" 8 "Rural UCT" 9 "Children <2 rural" 10 "Elder HH", angle(45)) ///
title("FGT0 by Scenario - Lollipop Chart") ///
ylabel(, angle(horizontal)) ///
legend(off)


sum FGT0 if scenario == 2024
gen FGT0_2024 = r(mean)



twoway ///
    (rspike FGT0_2024 FGT0 id if id > 2, horizontal lcolor(gs12) lwidth(0.8)) /// Spikes from 2024
    (scatter id FGT0 if id > 2, msymbol(O) mcolor("30 56 99") msize(medlarge) mlcolor(black) mlwidth(0.2)) /// Midnight blue points
    (scatter id FGT0 if id <= 2, msymbol(D) mcolor(red) msize(medlarge) mlcolor(black) mlwidth(0.2)), /// Red baseline points
    ylabel(1 "2018" 2 "2024" 3 "UCT" 4 "Children <18" 5 "Children <5" ///
           6 "Disability" 7 "Children <2" 8 "Rural UCT" 9 "Children <2 rural" 10 "Elder HH", ///
           angle(0) labsize(small) noticks) ///
    ytitle("", size(0)) /// 
    xlabel(, grid gmin gmax format(%9.1f) glcolor(gs14) glwidth(0.2)) ///
    xtitle("FGT0 (Headcount Poverty Ratio)", size(small)) ///
    title("", size(medium)) ///
    note("Note: Bars show change from 2024 projection value", size(vsmall)) ///
    legend(order(2 "Policy Scenarios" 3 "Baseline Years") pos(6) rows(1)) ///
    graphregion(color(white) margin(l=15 r=5)) ///
    plotregion(color(white) margin(b=5))
	
* 3. Export graph : Export to vector PDF for LaTeX

graph export "$dirimg\FGT0_Scenarios.pdf", replace

