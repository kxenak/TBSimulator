"""
    Agent represents an individual in the TB simulation
"""
mutable struct Agent
    id::Int64                     # Unique identifier
    gender::Gender                # Male or Female
    age::Float64                  # Age in years (using Float64 for fractional years)
    household_id::Int64           # Household ID
    workplace_id::Int64           # Workplace ID (0 if not working)
    school_id::Int64              # School ID (0 if not in school)
    disease_state::DiseaseState   # Current disease state
    
    # Disease-specific attributes
    tbi_time::Float64             # Time since TBI infection (in days)
    active_time::Float64          # Time since active TB (in days)
    treatment_time::Float64       # Time in treatment (in days)
    treatment_notification_time::Float64  # Time when treatment is notified (in days)
    infectious::Bool              # Whether agent is infectious
    screened::Bool                # Whether agent has been screened
    tpt_status::Bool              # Whether agent is on TPT
    tpt_time::Float64             # Time on TPT (in days)
    
    # Constructor with default values
    function Agent(
        id::Int64, 
        gender::Gender, 
        age::Float64, 
        household_id::Int64, 
        workplace_id::Int64 = 0, 
        school_id::Int64 = 0, 
        disease_state::DiseaseState = Susceptible
    )
        return new(
            id, gender, age, household_id, workplace_id, school_id, disease_state,
            0.0, 0.0, 0.0, 0.0, false, false, false, 0.0
        )
    end
end

"""
    get_location(agent::Agent, time_period::Symbol)

Get the current location of the agent based on the time period (e.g., :morning, :afternoon).
"""
function get_location(agent::Agent, time_period::Symbol)
    # Children under 4 and elderly over 65 stay at home
    if agent.age < 4.0 || agent.age >= 65.0
        return (Home, agent.household_id)
    end
    
    # School-age children (4-18)
    if 4.0 <= agent.age < 18.0 && agent.school_id != 0
        return time_period == :morning ? (School, agent.school_id) : (Home, agent.household_id)
    end
    
    # Working adults
    if agent.workplace_id != 0
        return time_period == :morning ? (Work, agent.workplace_id) : (Home, agent.household_id)
    end
    
    # Default: stay at home
    return (Home, agent.household_id)
end

"""
    will_progress_to_active(agent::Agent, rng::AbstractRNG)

Determine whether a TBI agent will progress to active TB, based on the natural history of TB.
"""
function will_progress_to_active(agent::Agent, rng::AbstractRNG)
    # Only 10% of TBI cases progress to active TB
    if rand(rng) > 0.10
        return false
    end
    
    # For the 10% that progress, determine when they will progress
    progression_time = agent.tbi_time / 365.0  # Convert days to years
    
    # Progression probabilities based on years since infection
    if progression_time <= 1.0
        return rand(rng) <= 0.45  # 45% within 1st year
    elseif progression_time <= 2.0
        return rand(rng) <= (0.62 - 0.45) / (1.0 - 0.45)  # Additional 17% in 2nd year
    elseif progression_time <= 5.0
        return rand(rng) <= (0.83 - 0.62) / (1.0 - 0.62)  # Additional 21% in years 3-5
    elseif progression_time <= 12.0
        return rand(rng) <= (0.99 - 0.83) / (1.0 - 0.83)  # Additional 16% in years 6-12
    else
        return rand(rng) <= (1.0 - 0.99) / (1.0 - 0.99)   # Final 1% thereafter
    end
end

"""
    update_disease_state!(agent::Agent, timestep::Float64, config::Dict, rng::AbstractRNG)

Update the disease state of an agent based on natural history and treatment.
"""
function update_disease_state!(agent::Agent, timestep::Float64, config::Dict, rng::AbstractRNG)
    # Update time counters
    if agent.disease_state == TBI
        agent.tbi_time += timestep
    elseif agent.disease_state == ActiveTB
        agent.active_time += timestep
    elseif agent.disease_state == Treatment
        agent.treatment_time += timestep
    end
    
    if agent.tpt_status
        agent.tpt_time += timestep
    end
    
    # Update disease state based on current state
    if agent.disease_state == Susceptible
        # No state change for susceptible (infections happen in the simulation loop)
        return
    elseif agent.disease_state == TBI
        # Check if on TPT and completed
        if agent.tpt_status && agent.tpt_time >= 180.0  # 6 months of TPT
            # TPT completed
            agent.tpt_status = false
            
            # TPT efficacy check
            if rand(rng) <= config["tpt_efficacy"]
                agent.disease_state = Susceptible
                agent.tbi_time = 0.0
                return
            end
        end
        
        # Check for progression to active TB
        if will_progress_to_active(agent, rng)
            agent.disease_state = ActiveTB
            agent.infectious = true
            agent.active_time = 0.0
            return
        end
    elseif agent.disease_state == ActiveTB
        # Check if case is notified (mean delay 78 days)
        if !agent.treatment_notification_time > 0.0 && agent.active_time >= 78.0 && rand(rng) <= 0.5
            agent.treatment_notification_time = agent.active_time
            agent.disease_state = Treatment
            agent.treatment_time = 0.0
            return
        end
    elseif agent.disease_state == Treatment
        # Check if treatment is complete (6 months)
        if agent.treatment_time >= 180.0  # 6 months
            # Determine treatment outcome
            outcome_rand = rand(rng)
            if outcome_rand <= config["treatment_success_rate"]
                # Treatment success
                agent.disease_state = Susceptible
                agent.infectious = false
                agent.active_time = 0.0
                agent.treatment_time = 0.0
                agent.treatment_notification_time = 0.0
            elseif outcome_rand <= config["treatment_success_rate"] + config["mortality_rate"]
                # Death due to TB - will be handled by simulation
                return
            else
                # Treatment failure
                agent.disease_state = ActiveTB
                agent.active_time = 0.0
                agent.treatment_time = 0.0
                agent.treatment_notification_time = 0.0
            end
        elseif agent.treatment_time >= 14.0
            # After 2 weeks of treatment, no longer infectious
            agent.infectious = false
        end
    end
end

"""
    screen_agent!(agent::Agent, config::Dict, rng::AbstractRNG)

Screen an agent for TB infection.
"""
function screen_agent!(agent::Agent, config::Dict, rng::AbstractRNG)
    # Skip if already screened
    if agent.screened
        return
    end
    
    agent.screened = true
    
    # Screen based on sensitivity
    if agent.disease_state == TBI && rand(rng) <= config["screening_test_sensitivity"]
        # TBI detected, start TPT
        start_tpt!(agent, config, rng)
    elseif agent.disease_state == ActiveTB && rand(rng) <= config["screening_test_sensitivity"]
        # Active TB detected, start treatment immediately
        agent.disease_state = Treatment
        agent.treatment_time = 0.0
        agent.treatment_notification_time = 0.0
    end
end

"""
    start_tpt!(agent::Agent, config::Dict, rng::AbstractRNG)

Start TB preventive therapy for an agent with latent TB.
"""
function start_tpt!(agent::Agent, config::Dict, rng::AbstractRNG)
    # Only start TPT for TBI
    if agent.disease_state != TBI
        return
    end
    
    # Check if agent will complete TPT
    if rand(rng) <= config["tpt_completion_rate"]
        agent.tpt_status = true
        agent.tpt_time = 0.0
    end
end

"""
    age_agent!(agent::Agent, days::Float64)

Age an agent by the specified number of days.
"""
function age_agent!(agent::Agent, days::Float64)
    agent.age += days / 365.0  # Convert days to years
end