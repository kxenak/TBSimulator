"""
    Population represents the collection of all agents and locations in the simulation
"""
mutable struct Population
    agents::Dict{Int64, Agent}                # Map of agent ID to agent
    households::Dict{Int64, Vector{Int64}}    # Map of household ID to agent IDs
    workplaces::Dict{Int64, Vector{Int64}}    # Map of workplace ID to agent IDs
    schools::Dict{Int64, Vector{Int64}}       # Map of school ID to agent IDs
    
    # Demographic data
    all_workplace_ids::Vector{Int64}          # All workplace IDs
    all_school_ids::Vector{Int64}             # All school IDs
    asfr_data::DataFrame                      # Age-specific fertility rates
    asmr_data::DataFrame                      # Age-specific mortality rates
    sex_ratio_data::DataFrame                 # Sex ratio at birth
    
    # Disease state counters
    susceptible_count::Int64
    tbi_count::Int64
    active_count::Int64
    treatment_count::Int64
    
    # Constructor
    function Population()
        return new(
            Dict{Int64, Agent}(),
            Dict{Int64, Vector{Int64}}(),
            Dict{Int64, Vector{Int64}}(),
            Dict{Int64, Vector{Int64}}(),
            Int64[],
            Int64[],
            DataFrame(),
            DataFrame(),
            DataFrame(),
            0, 0, 0, 0
        )
    end
end

"""
    load_population!(population::Population, synthetic_path::String, config::Dict, rng::AbstractRNG)

Load synthetic population data and initialize agents.
"""
function load_population!(population::Population, synthetic_path::String, config::Dict, rng::AbstractRNG)
    # Load the synthetic population data
    println("Loading synthetic population from: $synthetic_path")
    
    # Use CSV with specific column types for efficiency
    df = CSV.read(
        synthetic_path, 
        DataFrame,
        types=Dict(
            :AgentID => Int64,
            :Age => Float64,
            :HHID => Int64,
            :WorkPlaceID => Int64,
            :SchoolID => Int64
        )
    )
    
    # Extract and store all unique workplace and school IDs
    population.all_workplace_ids = filter(x -> x > 0, unique(df.WorkPlaceID))
    population.all_school_ids = filter(x -> x > 0, unique(df.SchoolID))
    
    # Initialize disease state counters
    population.susceptible_count = 0
    population.tbi_count = 0
    population.active_count = 0
    population.treatment_count = 0
    
    # Count total population for disease initialization
    total_population = nrow(df)
    
    # Calculate number of agents in each disease state
    num_tbi = round(Int, total_population * config["initial_tbi_percentage"] / 100.0)
    num_active = round(Int, total_population * config["initial_active_tbi_percentage"] / 100.0)
    
    # Create array for random assignment of disease states
    disease_states = fill(Susceptible, total_population)
    disease_states[1:num_tbi] .= TBI
    disease_states[1:num_active] .= ActiveTB
    shuffle!(rng, disease_states)
    
    # Initialize progress bar
    p = Progress(nrow(df), 1, "Initializing agents...")
    
    # Create agents from the dataframe
    for (i, row) in enumerate(eachrow(df))
        # Parse gender
        gender = row.SexLabel == "Male" ? Male : Female
        
        # Parse agent ID and location IDs
        agent_id = row.AgentID
        household_id = row.HHID
        workplace_id = isnothing(row.WorkPlaceID) ? 0 : row.WorkPlaceID
        school_id = isnothing(row.SchoolID) ? 0 : row.SchoolID
        
        # Apply working population ratio adjustment
        if gender == Male && workplace_id != 0 && row.Age >= 18 && row.Age < 65
            if rand(rng) > config["men_working_percentage"] / 100.0
                workplace_id = 0
            end
        elseif gender == Female && workplace_id != 0 && row.Age >= 18 && row.Age < 65
            if rand(rng) > config["women_working_percentage"] / 100.0
                workplace_id = 0
            end
        end
        
        # Assign disease state
        disease_state = disease_states[i]
        
        # Create the agent
        agent = Agent(agent_id, gender, row.Age, household_id, workplace_id, school_id, disease_state)
        
        # Initialize disease-specific attributes
        if disease_state == TBI
            # Random time since TBI infection (0 to 12 years)
            agent.tbi_time = rand(rng) * 12.0 * 365.0
            population.tbi_count += 1
        elseif disease_state == ActiveTB
            # Random time since active TB (0 to 78 days - before notification)
            agent.active_time = rand(rng) * 78.0
            agent.infectious = true
            population.active_count += 1
        else
            population.susceptible_count += 1
        end
        
        # Add agent to the population
        population.agents[agent_id] = agent
        
        # Update location mappings
        if !haskey(population.households, household_id)
            population.households[household_id] = Int64[]
        end
        push!(population.households[household_id], agent_id)
        
        if workplace_id != 0
            if !haskey(population.workplaces, workplace_id)
                population.workplaces[workplace_id] = Int64[]
            end
            push!(population.workplaces[workplace_id], agent_id)
        end
        
        if school_id != 0
            if !haskey(population.schools, school_id)
                population.schools[school_id] = Int64[]
            end
            push!(population.schools[school_id], agent_id)
        end
        
        # Update progress
        next!(p)
    end
    
    println("Initialized $(length(population.agents)) agents in total")
    println("Initial disease states: $(population.susceptible_count) susceptible, $(population.tbi_count) TBI, $(population.active_count) active TB")
end

"""
    load_demographic_data!(population::Population, asfr_path::String, asmr_path::String, sex_ratio_path::String)

Load demographic data for population dynamics.
"""
function load_demographic_data!(population::Population, asfr_path::String, asmr_path::String, sex_ratio_path::String)
    # Load age-specific fertility rates
    population.asfr_data = CSV.read(asfr_path, DataFrame)
    
    # Load age-specific mortality rates
    population.asmr_data = CSV.read(asmr_path, DataFrame)
    
    # Load sex ratio at birth
    population.sex_ratio_data = CSV.read(sex_ratio_path, DataFrame)
    
    println("Demographic data loaded successfully")
end

"""
    update_population!(population::Population, current_date::Date, timestep::Float64, config::Dict, rng::AbstractRNG)

Update the population by aging, births, and deaths.
"""
function update_population!(population::Population, current_date::Date, timestep::Float64, config::Dict, rng::AbstractRNG)
    # Age all agents
    for agent in values(population.agents)
        age_agent!(agent, timestep)
    end
    
    # Process deaths (weekly check)
    if mod(Dates.value(current_date), 7) == 0
        process_deaths!(population, current_date, rng)
    end
    
    # Process births (weekly check)
    if mod(Dates.value(current_date), 7) == 0
        process_births!(population, current_date, config, rng)
    end
    
    # Update disease state counters
    update_disease_counters!(population)
end

"""
    process_deaths!(population::Population, current_date::Date, rng::AbstractRNG)

Process deaths based on age-specific mortality rates.
"""
function process_deaths!(population::Population, current_date::Date, rng::AbstractRNG)
    year = year(current_date)
    
    # Get ASMR data for the current year (or nearest year)
    year_index = findmin(abs.(population.asmr_data.Year .- year))[2]
    current_asmr = population.asmr_data[year_index, :]
    
    # Agents to remove
    agents_to_remove = Int64[]
    
    # Check each agent for mortality
    for (agent_id, agent) in population.agents
        # Get mortality rate for the agent's age group
        age_group_index = nothing
        
        if agent.age < 5
            age_group_index = findfirst(x -> x == "0-4", current_asmr[!, "Age group"])
        elseif 5 <= agent.age < 10
            age_group_index = findfirst(x -> x == "5-9", current_asmr[!, "Age group"])
        elseif 10 <= agent.age < 15
            age_group_index = findfirst(x -> x == "10-14", current_asmr[!, "Age group"])
        elseif 15 <= agent.age < 20
            age_group_index = findfirst(x -> x == "15-19", current_asmr[!, "Age group"])
        elseif 20 <= agent.age < 25
            age_group_index = findfirst(x -> x == "20-24", current_asmr[!, "Age group"])
        elseif 25 <= agent.age < 30
            age_group_index = findfirst(x -> x == "25-29", current_asmr[!, "Age group"])
        elseif 30 <= agent.age < 35
            age_group_index = findfirst(x -> x == "30-34", current_asmr[!, "Age group"])
        elseif 35 <= agent.age < 40
            age_group_index = findfirst(x -> x == "35-39", current_asmr[!, "Age group"])
        elseif 40 <= agent.age < 45
            age_group_index = findfirst(x -> x == "40-44", current_asmr[!, "Age group"])
        elseif 45 <= agent.age < 50
            age_group_index = findfirst(x -> x == "45-49", current_asmr[!, "Age group"])
        elseif 50 <= agent.age < 55
            age_group_index = findfirst(x -> x == "50-54", current_asmr[!, "Age group"])
        elseif 55 <= agent.age < 60
            age_group_index = findfirst(x -> x == "55-59", current_asmr[!, "Age group"])
        elseif 60 <= agent.age < 65
            age_group_index = findfirst(x -> x == "60-64", current_asmr[!, "Age group"])
        elseif 65 <= agent.age < 70
            age_group_index = findfirst(x -> x == "65-69", current_asmr[!, "Age group"])
        elseif 70 <= agent.age < 75
            age_group_index = findfirst(x -> x == "70-74", current_asmr[!, "Age group"])
        elseif 75 <= agent.age < 80
            age_group_index = findfirst(x -> x == "75-79", current_asmr[!, "Age group"])
        elseif 80 <= agent.age < 85
            age_group_index = findfirst(x -> x == "80-84", current_asmr[!, "Age group"])
        else
            age_group_index = findfirst(x -> x == "85 +", current_asmr[!, "Age group"])
        end
        
        if isnothing(age_group_index)
            continue
        end
        
        # Get mortality rate based on gender
        mortality_rate = agent.gender == Male ? 
            current_asmr[age_group_index, :Male] : 
            current_asmr[age_group_index, :Female]
        
        # Convert annual rate to weekly rate
        weekly_rate = 1 - (1 - mortality_rate / 1000)^(1/52)
        
        # Check if agent dies
        if rand(rng) < weekly_rate
            push!(agents_to_remove, agent_id)
        end
    end
    
    # Remove dead agents
    for agent_id in agents_to_remove
        remove_agent!(population, agent_id)
    end
    
    if !isempty(agents_to_remove)
        println("$(length(agents_to_remove)) deaths processed")
    end
end

"""
    process_births!(population::Population, current_date::Date, config::Dict, rng::AbstractRNG)

Process births based on age-specific fertility rates.
"""
function process_births!(population::Population, current_date::Date, config::Dict, rng::AbstractRNG)
    year = year(current_date)
    
    # Get ASFR data for the current year (or nearest year)
    year_index = findmin(abs.(population.asfr_data.Year .- year))[2]
    current_asfr = population.asfr_data[year_index, :]
    
    # Get sex ratio for the current year (or nearest year)
    sex_ratio_index = findmin(abs.(population.sex_ratio_data.Year .- year))[2]
    sex_ratio = population.sex_ratio_data.Ratio[sex_ratio_index] / 1000.0
    
    # Count newborns
    newborns = 0
    
    # Check each female agent for fertility
    for (agent_id, agent) in population.agents
        # Only females of reproductive age (18-49)
        if agent.gender != Female || agent.age < 18 || agent.age >= 50
            continue
        end
        
        # Get fertility rate for the agent's age group
        age_group_index = nothing
        
        if 15 <= agent.age < 20
            age_group_index = findfirst(x -> x == "15-19", current_asfr[!, "Age group"])
        elseif 20 <= agent.age < 25
            age_group_index = findfirst(x -> x == "20-24", current_asfr[!, "Age group"])
        elseif 25 <= agent.age < 30
            age_group_index = findfirst(x -> x == "25-29", current_asfr[!, "Age group"])
        elseif 30 <= agent.age < 35
            age_group_index = findfirst(x -> x == "30-34", current_asfr[!, "Age group"])
        elseif 35 <= agent.age < 40
            age_group_index = findfirst(x -> x == "35-39", current_asfr[!, "Age group"])
        elseif 40 <= agent.age < 45
            age_group_index = findfirst(x -> x == "40-44", current_asfr[!, "Age group"])
        elseif 45 <= agent.age < 50
            age_group_index = findfirst(x -> x == "45-49", current_asfr[!, "Age group"])
        end
        
        if isnothing(age_group_index)
            continue
        end
        
        # Get fertility rate
        fertility_rate = current_asfr[age_group_index, "Fertility Rate"]
        
        # Convert annual rate to weekly probability
        weekly_probability = 1 - (1 - fertility_rate / 1000)^(1/52)
        
        # Check if agent gives birth
        if rand(rng) < weekly_probability
            # Create new agent (newborn)
            new_agent_id = maximum(keys(population.agents)) + 1
            newborn_gender = rand(rng) < sex_ratio ? Male : Female
            
            # Create newborn agent
            newborn = Agent(
                new_agent_id,
                newborn_gender,
                0.0,  # Age 0
                agent.household_id,  # Same household as mother
                0,    # No workplace
                0     # No school
            )
            
            # Add newborn to population
            population.agents[new_agent_id] = newborn
            
            # Update location mappings
            if !haskey(population.households, agent.household_id)
                population.households[agent.household_id] = Int64[]
            end
            push!(population.households[agent.household_id], new_agent_id)
            
            # Update disease state counters
            population.susceptible_count += 1
            
            newborns += 1
        end
    end
    
    if newborns > 0
        println("$newborns births processed")
    end
end

"""
    update_disease_counters!(population::Population)

Update the disease state counters based on the current agent states.
"""
function update_disease_counters!(population::Population)
    # Reset counters
    population.susceptible_count = 0
    population.tbi_count = 0
    population.active_count = 0
    population.treatment_count = 0
    
    # Count each state
    for agent in values(population.agents)
        if agent.disease_state == Susceptible
            population.susceptible_count += 1
        elseif agent.disease_state == TBI
            population.tbi_count += 1
        elseif agent.disease_state == ActiveTB
            population.active_count += 1
        elseif agent.disease_state == Treatment
            population.treatment_count += 1
        end
    end
end

"""
    remove_agent!(population::Population, agent_id::Int64)

Remove an agent from the population.
"""
function remove_agent!(population::Population, agent_id::Int64)
    if !haskey(population.agents, agent_id)
        return
    end
    
    agent = population.agents[agent_id]
    
    # Remove from household
    if haskey(population.households, agent.household_id)
        filter!(id -> id != agent_id, population.households[agent.household_id])
    end
    
    # Remove from workplace
    if agent.workplace_id != 0 && haskey(population.workplaces, agent.workplace_id)
        filter!(id -> id != agent_id, population.workplaces[agent.workplace_id])
    end
    
    # Remove from school
    if agent.school_id != 0 && haskey(population.schools, agent.school_id)
        filter!(id -> id != agent_id, population.schools[agent.school_id])
    end
    
    # Remove from agents dictionary
    delete!(population.agents, agent_id)
end

"""
    assign_random_workplace!(agent::Agent, population::Population, rng::AbstractRNG)

Assign a random workplace to an agent.
"""
function assign_random_workplace!(agent::Agent, population::Population, rng::AbstractRNG)
    if isempty(population.all_workplace_ids)
        return
    end
    
    # Remove from current workplace if any
    if agent.workplace_id != 0 && haskey(population.workplaces, agent.workplace_id)
        filter!(id -> id != agent.id, population.workplaces[agent.workplace_id])
    end
    
    # Assign random workplace
    agent.workplace_id = rand(rng, population.all_workplace_ids)
    
    # Add to new workplace
    if !haskey(population.workplaces, agent.workplace_id)
        population.workplaces[agent.workplace_id] = Int64[]
    end
    push!(population.workplaces[agent.workplace_id], agent.id)
end

"""
    assign_random_school!(agent::Agent, population::Population, rng::AbstractRNG)

Assign a random school to an agent.
"""
function assign_random_school!(agent::Agent, population::Population, rng::AbstractRNG)
    if isempty(population.all_school_ids)
        return
    end
    
    # Remove from current school if any
    if agent.school_id != 0 && haskey(population.schools, agent.school_id)
        filter!(id -> id != agent.id, population.schools[agent.school_id])
    end
    
    # Assign random school
    agent.school_id = rand(rng, population.all_school_ids)
    
    # Add to new school
    if !haskey(population.schools, agent.school_id)
        population.schools[agent.school_id] = Int64[]
    end
    push!(population.schools[agent.school_id], agent.id)
end

"""
    check_contacts!(population::Population, location_type::Location, location_id::Int64, 
                   timestep::Float64, beta::Float64, infection_factor::Float64, rng::AbstractRNG)

Check for TB transmission at a specific location.
"""
function check_contacts!(population::Population, location_type::Location, location_id::Int64, 
                        timestep::Float64, beta::Float64, infection_factor::Float64, rng::AbstractRNG)
    # Get agents at this location
    agent_ids = if location_type == Home
        get(population.households, location_id, Int64[])
    elseif location_type == Work
        get(population.workplaces, location_id, Int64[])
    elseif location_type == School
        get(population.schools, location_id, Int64[])
    else
        Int64[]
    end
    
    # Skip if empty
    if isempty(agent_ids)
        return 0
    end
    
    # Count infectious agents at this location
    infectious_count = 0
    for id in agent_ids
        if !haskey(population.agents, id)
            continue
        end
        agent = population.agents[id]
        if (agent.disease_state == ActiveTB || 
            (agent.disease_state == Treatment && agent.treatment_time < 14.0)) && 
            agent.infectious
            infectious_count += 1
        end
    end
    
    # Skip if no infectious agents
    if infectious_count == 0
        return 0
    end
    
    # Calculate infection probability based on location type
    if location_type == Home
        # For home, no infection factor is applied
        infection_prob = min(1.0, (infectious_count / length(agent_ids)) * beta * timestep)
    else
        # For work/school, apply the infection factor
        infection_prob = min(1.0, (infectious_count / length(agent_ids)) * beta * infection_factor * timestep)
    end
    
    # Count new infections
    new_infections = 0
    
    # Check for new infections
    for id in agent_ids
        if !haskey(population.agents, id)
            continue
        end
        agent = population.agents[id]
        if agent.disease_state == Susceptible && rand(rng) < infection_prob
            # New infection
            agent.disease_state = TBI
            agent.tbi_time = 0.0
            new_infections += 1
        end
    end
    
    return new_infections
end

"""
    screen_household_contacts!(population::Population, config::Dict, rng::AbstractRNG)

Screen household contacts of active TB cases.
"""
function screen_household_contacts!(population::Population, config::Dict, rng::AbstractRNG)
    # Get households with active TB cases
    households_with_active_tb = Set{Int64}()
    
    for agent in values(population.agents)
        if agent.disease_state == ActiveTB && agent.treatment_notification_time > 0.0
            push!(households_with_active_tb, agent.household_id)
        end
    end
    
    # Screen contacts in these households
    for household_id in households_with_active_tb
        if !haskey(population.households, household_id)
            continue
        end
        
        for agent_id in population.households[household_id]
            if haskey(population.agents, agent_id)
                agent = population.agents[agent_id]
                if agent.disease_state != ActiveTB  # Don't screen active TB cases
                    screen_agent!(agent, config, rng)
                end
            end
        end
    end
end