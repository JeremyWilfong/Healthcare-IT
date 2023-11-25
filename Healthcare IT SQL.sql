--Creating indexes for each table to improve processing.
create index patient_name on patient(name)
create index insurance_policy_number on insurance(policy_number)
create index patient_id on patient(patient_id)
create index insurance_id on insurance(insurance_id)
create index claim_id on claims(claim_id)
create index claim_details_id on details(claim_detail_id)
create index physician_id on physician(physician_id)

--LOCATION and PHYSICIAN DATA
--which insurance provider is used most at each location? (COMPLETE)
select location, count(provider) #_claims_insured, provider
into #provider_count
from insurance i
join claims c
on i.insurance_id = c.insurance_id
join details d	
on c.claim_id = d.claim_id
join physician p
on d.physician_id = p.physician_id
group by location, provider
order by location

select location, provider, #_claims_insured, 
	row_number() over(partition by location order by #_claims_insured desc) as rank
into #most_popular_provider
from #provider_count

select location, provider
into #pop_provider
from #most_popular_provider
where rank = 1
order by provider

--which location has the most procedures and what were the most popular procedures at that location? (COMPLETE)
select location, count(procedure_code) procedure_amount, procedure_code
into #procedure_count
from physician phy
join details d
on phy.physician_id = d.physician_id
group by procedure_code, location
order by procedure_amount desc

select location, procedure_amount, procedure_code,
	row_number() over (partition by location order by procedure_amount desc) as rank 
into #most_used_procedure
from #procedure_count

select location, procedure_code as most_popular_procedure
into #pop_proc
from #most_used_procedure
where rank = 1
order by location

select phy.location, 
	count(d.claim_detail_id) as #_of_procedures, 
	most_popular_procedure
into #proc_popularity
from physician phy
join details d
on phy.physician_id = d.physician_id
join #pop_proc pp on phy.location=pp.location
group by phy.location, most_popular_procedure
order by #_of_procedures desc

--which physician collected the most money and which location? what are the outstanding debts to each location? (COMPLETE)
select d.physician_id, sum(cost) rev_collected
from details d
join claims c
on d.claim_id = c.claim_id
where claim_status like 'Paid'
group by d.physician_id
order by rev_collected desc

select location, sum(cost) revenue_collected 
from physician p
join details d
on p.physician_id = d.physician_id
join claims c
on d.claim_id = c.claim_id
where c.claim_status like 'Paid'
group by location
order by revenue_collected desc

select location, sum(cost) accounts_payable
from physician p
join details d
on p.physician_id = d.physician_id
join claims c
on d.claim_id = c.claim_id
where c.claim_status like 'Pending'
group by location
order by accounts_payable desc

--which specialization received the most revenue?(COMPLETE)
select specialization, sum(cost) total_rev
from physician p
join details d
on p.physician_id = d.physician_id
group by specialization
order by total_rev desc

--which specialization has the most procedures with a pending claim? (COMPLETE)
select specialization, count(*) total_procedures
from claims c
join details d
on c.claim_id = d.claim_id
join physician p
on d.physician_id = p.physician_id
where claim_status like 'Pending'
group by specialization
order by total_procedures desc


--PROCEDURE DATA
--which procedures bring the most revenue? (COMPLETE)
select procedure_code, sum(cost) as total_revenue
from details
group by procedure_code
order by total_revenue desc

--most popular procedures for each age (COMPLETE)
select age, procedure_code, count(*) as procedure_count
into #procedurecount
from patient p
join details d
on p.patient_id = d.patient_id
group by p.age, d.procedure_code

select age, procedure_code, procedure_count, 
	row_number() over (partition by age order by procedure_count DESC) as rank
into #most_popular_proc
from #procedurecount

select pop.age, pop.procedure_code
from #most_popular_proc pop
where rank = 1
order by age

--top 5 most popular procedures for each gender (COMPLETE)
select gender, procedure_code, count(d.procedure_code) as procedure_count
into #gender_procedure_count
from patient p
join details d
on p.patient_id = d.patient_id
group by gender, procedure_code

select gender, procedure_code, procedure_count,
	row_number() over (partition by gender order by procedure_count DESC) as rank
into #pop_procedure_age
from #gender_procedure_count

select gender, procedure_code, rank
from #pop_procedure_age
where rank > 0 AND rank < 6
order by gender

--most popular procedure by city
select city, procedure_code, count(procedure_code) as procedure_count
into #city_procedure_count
from patient p
join details d
on p.patient_id = d.patient_id
group by city, procedure_code

select city, procedure_code, procedure_count,
	row_number() over (partition by city order by procedure_count DESC) as rank
into #pop_procedure_city
from #city_procedure_count

select city, procedure_code
from #pop_procedure_city
where rank = 1
order by city


--CLAIM DATA
--average time between claim date and paid off date (COMPLETE)
select avg(datediff(day, claim_date, paid_off_date))
from claims c
where claim_status like 'Paid'


--INSURANCE DATA
--which insurance providers still needs to pay up? Also show list of unpaid claims for a particular provider, along with amount owed and sort by oldest unpaid. (COMPLETE by original claim date and not last procedure date)
select provider, count(c.claim_id) #_of_unpaid_claims, sum(cost) amount_outstanding
from insurance i
join claims c
on i.insurance_id = c.insurance_id
join details d
on c.claim_id = d.claim_id
where claim_status not like 'Paid'
group by provider
order by #_of_unpaid_claims desc

select c.claim_id, c.patient_id, i.insurance_id, i.provider, datediff(day, GETDATE(), claim_date) #_of_days
from claims c
join insurance i
on c.insurance_id = i.insurance_id
join details d
on c.claim_id = d.claim_id
where claim_status not like 'Paid' AND
	datediff(day, GETDATE(), claim_date) > 0
order by #_of_days desc

--most popular insurance provider by city
select provider, city, count(claim_id) as provider_count
into #count_provider_city
from insurance i
join patient p
on p.patient_id = i.patient_id
join claims c
on p.patient_id = c.patient_id
group by provider, city

select provider, city, provider_count,
	row_number() over (partition by city order by provider_count DESC) as rank
into #pop_provider_city
from #count_provider_city

select provider, city
from #pop_provider_city
where rank = 1


--Creating Provider table for Tableau.
select sum(cost) as total_cost, claim_id into #total_cost_per_claim from details group by claim_id
select distinct provider, policy_number, coverage_details, i.insurance_id, c.claim_id, pa.name, pa.age, pa.gender, claim_date, claim_status, paid_off_date, total_cost, location, pa.city, specialization
from claims c
join insurance i on c.insurance_id = i.insurance_id
join details d on c.claim_id = d.claim_id
join #total_cost_per_claim t on c.claim_id=t.claim_id
join physician p on d.physician_id = p.physician_id
join patient pa on c.patient_id = pa.patient_id
order by provider

--Creating Facility table for Tableau
select distinct ph.location, c.claim_id, ph.name, ph.physician_id, p.patient_id, p.name, age, gender, claim_date, claim_status, paid_off_date, total_cost, specialization, c.insurance_id,policy_number, i.provider, 
max(procedure_date) over(partition by c.claim_id) most_recent_procedure_date, 
datediff(day,claim_date, paid_off_date) days_to_paid,
prp.#_of_procedures as total_procedures_at_facility, prp.most_popular_procedure as most_popular_procedure_at_facility,
ppr.provider as most_popular_provider_at_facility
from physician ph
join details d on ph.physician_id = d.physician_id
join claims c on d.claim_id = c.claim_id
join insurance i on c.patient_id=i.patient_id
join patient p on c.patient_id = p.patient_id
join #total_cost_per_claim t on c.claim_id=t.claim_id
join #proc_popularity prp on ph.location=prp.location
join #pop_provider ppr on ph.location=ppr.location

--Creating Details Table for Tableau
select distinct claim_detail_id, c.claim_id, claim_date, procedure_code, procedure_date, p.patient_id, p.name as patient_name, ph.name as physician_name, ph.physician_id, specialization, location, age, gender, cost
from physician ph
join details d on ph.physician_id = d.physician_id
join claims c on d.claim_id = c.claim_id
join insurance i on c.patient_id=i.patient_id
join patient p on c.patient_id = p.patient_id
join #total_cost_per_claim t on c.claim_id=t.claim_id
