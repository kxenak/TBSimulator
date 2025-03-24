# Helper functions for tests

"""
    update_disease_counters!(population::Population)

Test version of update_disease_counters! for use in tests.
"""
function update_disease_counters!(population)
    # Reset counters
    population.susceptible_count = 0
    population.tbi_count = 0
    population.active_count = 0
    population.treatment_count = 0
    
    # Count each state
    for agent in values(population.agents)
        if agent.disease_state == TBSimulator.Susceptible
            population.susceptible_count += 1
        elseif agent.disease_state == TBSimulator.TBI
            population.tbi_count += 1
        elseif agent.disease_state == TBSimulator.ActiveTB
            population.active_count += 1
        elseif agent.disease_state == TBSimulator.Treatment
            population.treatment_count += 1
        end
    end
end

"""
    check_contacts!(population, location_type, location_id, timestep, beta, infection_factor, rng)

Test version of check_contacts! for use in tests.
"""
function check_contacts!(population, location_type, location_id, timestep, beta, infection_factor, rng)
    # Get agents at this location
    agent_ids = if location_type == TBSimulator.Home
        get(population.households, location_id, Int64[])
    elseif location_type == TBSimulator.Work
        get(population.workplaces, location_id, Int64[])
    elseif location_type == TBSimulator.School
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
        if (agent.disease_state == TBSimulator.ActiveTB || 
            (agent.disease_state == TBSimulator.Treatment && agent.treatment_time < 14.0)) && 
            agent.infectious
            infectious_count += 1
        end
    end
    
    # Skip if no infectious agents
    if infectious_count == 0
        return 0
    end
    
    # Calculate infection probability
    infection_prob = min(1.0, (infectious_count / length(agent_ids)) * beta * infection_factor * timestep)
    
    # Count new infections
    new_infections = 0
    
    # Check for new infections
    for id in agent_ids
        if !haskey(population.agents, id)
            continue
        end
        agent = population.agents[id]
        if agent.disease_state == TBSimulator.Susceptible && rand(rng) < infection_prob
            # New infection
            agent.disease_state = TBSimulator.TBI
            agent.tbi_time = 0.0
            new_infections += 1
        end
    end
    
    return new_infections
end

"""
    screen_household_contacts!(population, config, rng)

Test version of screen_household_contacts! for use in tests.
"""
function screen_household_contacts!(population, config, rng)
    # Get households with active TB cases
    households_with_active_tb = Set{Int64}()
    
    for agent in values(population.agents)
        if agent.disease_state == TBSimulator.ActiveTB && agent.treatment_notification_time > 0.0
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
                if agent.disease_state != TBSimulator.ActiveTB  # Don't screen active TB cases
                    TBSimulator.screen_agent!(agent, config, rng)
                end
            end
        end
    end
end