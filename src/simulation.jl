"""
    Config structure to store simulation configuration
"""
struct Config
    mode::String                     # "calibration" or "simulation"
    beta_calibration_range::Vector{Float64}  # [min, max, step]
    beta::Float64                    # Infection rate parameter
    num_simulations::Int64           # Number of simulation runs
    timestep::Float64                # Timestep in days
    calibration_start_date::Date     # Start date for calibration
    calibration_end_date::Date       # End date for calibration
    simulation_start_date::Date      # Start date for simulation
    simulation_end_date::Date        # End date for simulation
    infection_factor::Float64        # Factor to multiply infection rate
    initial_tbi_percentage::Float64  # Initial TBI percentage
    initial_active_tbi_percentage::Float64  # Initial active TB percentage
    men_working_percentage::Float64  # Percentage of men working
    women_working_percentage::Float64  # Percentage of women working
    screening_test_sensitivity::Float64  # Sensitivity of screening test
    tpt_efficacy::Float64            # TPT efficacy
    treatment_success_rate::Float64  # Treatment success rate
    mortality_rate::Float64          # Mortality rate
    treatment_failure_rate::Float64  # Treatment failure rate
    tpt_completion_rate::Float64     # TPT completion rate
    synthetic_population_path::String  # Path to synthetic population file
    asfr_path::String                # Path to ASFR file
    asmr_path::String                # Path to ASMR file
    calibration_incidence_data_path::String  # Path to calibration data
    sex_ratio_path::String           # Path to sex ratio file
end

"""
    load_config(config_path::String) -> Config

Load configuration from a JSON file.
"""
function load_config(config_path::String)
    config_dict = JSON.parsefile(config_path)
    
    # Convert dates from strings
    calibration_start_date = Date(config_dict["calibration_start_date"])
    calibration_end_date = Date(config_dict["calibration_end_date"])
    simulation_start_date = Date(config_dict["simulation_start_date"])
    simulation_end_date = Date(config_dict["simulation_end_date"])
    
    # Set default paths for sex ratio
    sex_ratio_path = get(config_dict, "sex_ratio_path", "data/sex_ratio_at_birth.csv")
    
    # Parse beta calibration range
    beta_range = get(config_dict, "beta_calibration_range", [0.01, 0.5, 0.01])
    
    return Config(
        config_dict["mode"],
        beta_range,
        config_dict["beta"],
        config_dict["num_simulations"],
        config_dict["timestep"],
        calibration_start_date,
        calibration_end_date,
        simulation_start_date,
        simulation_end_date,
        config_dict["infection_factor"],
        config_dict["initial_tbi_percentage"],
        config_dict["initial_active_tbi_percentage"],
        config_dict["men_working_percentage"],
        config_dict["women_working_percentage"],
        config_dict["screening_test_sensitivity"],
        config_dict["tpt_efficacy"],
        config_dict["treatment_success_rate"],
        config_dict["mortality_rate"],
        config_dict["treatment_failure_rate"],
        config_dict["tpt_completion_rate"],
        config_dict["synthetic_population_path"],
        config_dict["asfr_path"],
        config_dict["asmr_path"],
        config_dict["calibration_incidence_data_path"],
        sex_ratio_path
    )
end

"""
    convert_config_to_dict(config::Config) -> Dict

Convert Config struct to dictionary for easier use in functions.
"""
function convert_config_to_dict(config::Config)
    return Dict{String, Any}(
        "mode" => config.mode,
        "beta_calibration_range" => config.beta_calibration_range,
        "beta" => config.beta,
        "num_simulations" => config.num_simulations,
        "timestep" => config.timestep,
        "calibration_start_date" => config.calibration_start_date,
        "calibration_end_date" => config.calibration_end_date,
        "simulation_start_date" => config.simulation_start_date,
        "simulation_end_date" => config.simulation_end_date,
        "infection_factor" => config.infection_factor,
        "initial_tbi_percentage" => config.initial_tbi_percentage,
        "initial_active_tbi_percentage" => config.initial_active_tbi_percentage,
        "men_working_percentage" => config.men_working_percentage,
        "women_working_percentage" => config.women_working_percentage,
        "screening_test_sensitivity" => config.screening_test_sensitivity,
        "tpt_efficacy" => config.tpt_efficacy,
        "treatment_success_rate" => config.treatment_success_rate,
        "mortality_rate" => config.mortality_rate,
        "treatment_failure_rate" => config.treatment_failure_rate,
        "tpt_completion_rate" => config.tpt_completion_rate,
        "synthetic_population_path" => config.synthetic_population_path,
        "asfr_path" => config.asfr_path,
        "asmr_path" => config.asmr_path,
        "calibration_incidence_data_path" => config.calibration_incidence_data_path,
        "sex_ratio_path" => config.sex_ratio_path
    )
end

"""
    SimulationResult holds the results of a simulation run
"""
struct SimulationResult
    dates::Vector{Date}
    disease_states::DataFrame
    weekly_incidence::DataFrame
    total_infections::Int64
    new_tbi_cases::Int64
    new_active_cases::Int64
    beta::Float64
end

"""
    initialize_simulation(config::Config) -> Population

Initialize a simulation with the given configuration.
"""
function initialize_simulation(config::Config, rng::AbstractRNG)
    # Create population
    population = Population()
    
    # Load synthetic population
    load_population!(population, config.synthetic_population_path, convert_config_to_dict(config), rng)
    
    # Load demographic data
    load_demographic_data!(population, config.asfr_path, config.asmr_path, config.sex_ratio_path)
    
    return population
end

"""
    run_simulation(config::Config, beta::Union{Float64, Nothing}=nothing, tag::String="") -> SimulationResult

Run a simulation with the given configuration.
"""
function run_simulation(config::Config, beta::Union{Float64, Nothing}=nothing, tag::String="")
    # Set random seed for reproducibility
    rng = MersenneTwister(1234)
    
    # Use provided beta or config beta
    actual_beta = isnothing(beta) ? config.beta : beta
    
    # Initialize state tracking
    start_date = config.mode == "calibration" ? config.calibration_start_date : config.simulation_start_date
    end_date = config.mode == "calibration" ? config.calibration_end_date : config.simulation_end_date
    
    # Convert timestep to days and ensure it's at least 1 day for date range
    timestep_days = max(1, round(Int, config.timestep))
    dates = collect(start_date:Day(timestep_days):end_date)
    
    # Initialize disease state tracking
    disease_states = DataFrame(
        Date = dates,
        Susceptible = zeros(Int, length(dates)),
        TBI = zeros(Int, length(dates)),
        ActiveTB = zeros(Int, length(dates)),
        Treatment = zeros(Int, length(dates)),
        NewTBI = zeros(Int, length(dates)),
        NewActiveTB = zeros(Int, length(dates))
    )
    
    # Initialize weekly incidence tracking
    weeks = unique([(year(d), week(d)) for d in dates])
    weekly_incidence = DataFrame(
        Year = [w[1] for w in weeks],
        Week = [w[2] for w in weeks],
        Incidence = zeros(Int, length(weeks))
    )
    
    # Initialize counter for new cases
    total_infections = 0
    new_tbi_cases = 0
    new_active_cases = 0
    
    # Initialize population
    population = initialize_simulation(config, rng)
    
    # Record initial state
    disease_states[1, :Susceptible] = population.susceptible_count
    disease_states[1, :TBI] = population.tbi_count
    disease_states[1, :ActiveTB] = population.active_count
    disease_states[1, :Treatment] = population.treatment_count
    
    # Main simulation loop
    println("Starting simulation from $(dates[1]) to $(dates[end])")
    p = Progress(length(dates) - 1, 1, "Simulating...")
    
    for i in 2:length(dates)
        current_date = dates[i]
        
        # Track new cases for this step
        step_new_tbi = 0
        step_new_active = 0
        
        # Morning: People at work/school
        for (location_id, agent_ids) in population.workplaces
            new_infections = check_contacts!(
                population, Work, location_id, 
                config.timestep / 2, actual_beta, 
                config.infection_factor, rng
            )
            step_new_tbi += new_infections
        end
        
        for (location_id, agent_ids) in population.schools
            new_infections = check_contacts!(
                population, School, location_id, 
                config.timestep / 2, actual_beta, 
                config.infection_factor, rng
            )
            step_new_tbi += new_infections
        end
        
        # Afternoon: People at home
        for (location_id, agent_ids) in population.households
            new_infections = check_contacts!(
                population, Home, location_id, 
                config.timestep / 2, actual_beta, 
                config.infection_factor, rng
            )
            step_new_tbi += new_infections
        end
        
        # Screen household contacts of active TB cases
        if mod(i, round(Int, 7 / config.timestep)) == 0  # Weekly screening
            screen_household_contacts!(population, convert_config_to_dict(config), rng)
        end
        
        # Update disease states for all agents
        active_tb_before = population.active_count
        for agent in values(population.agents)
            update_disease_state!(agent, config.timestep, convert_config_to_dict(config), rng)
        end
        active_tb_after = population.active_count
        step_new_active = max(0, active_tb_after - active_tb_before)
        
        # Update population (aging, births, deaths)
        update_population!(population, current_date, config.timestep, convert_config_to_dict(config), rng)
        
        # Update disease state counts
        update_disease_counters!(population)
        
        # Record disease states
        disease_states[i, :Susceptible] = population.susceptible_count
        disease_states[i, :TBI] = population.tbi_count
        disease_states[i, :ActiveTB] = population.active_count
        disease_states[i, :Treatment] = population.treatment_count
        disease_states[i, :NewTBI] = step_new_tbi
        disease_states[i, :NewActiveTB] = step_new_active
        
        # Update weekly incidence
        yr = year(current_date)
        wk = week(current_date)
        idx = findfirst(row -> row.Year == yr && row.Week == wk, eachrow(weekly_incidence))
        if !isnothing(idx)
            weekly_incidence[idx, :Incidence] += step_new_active
        end
        
        # Update total counters
        total_infections += step_new_tbi
        new_tbi_cases += step_new_tbi
        new_active_cases += step_new_active
        
        next!(p)
    end
    
    # Save results
    output_dir = "results"
    isdir(output_dir) || mkdir(output_dir)
    
    result_tag = isempty(tag) ? "" : "_$(tag)"
    mode_tag = config.mode == "calibration" ? "calib" : "sim"
    beta_tag = @sprintf("beta%.3f", actual_beta)
    
    # Save disease states
    output_file = joinpath(output_dir, "disease_states_$(mode_tag)_$(beta_tag)$(result_tag).csv")
    CSV.write(output_file, disease_states)
    println("Disease states saved to: $output_file")
    
    # Save weekly incidence
    output_file = joinpath(output_dir, "weekly_incidence_$(mode_tag)_$(beta_tag)$(result_tag).csv")
    CSV.write(output_file, weekly_incidence)
    println("Weekly incidence saved to: $output_file")
    
    println("Simulation completed.")
    println("Total new infections: $total_infections")
    println("New TBI cases: $new_tbi_cases")
    println("New active TB cases: $new_active_cases")
    
    return SimulationResult(
        dates,
        disease_states,
        weekly_incidence,
        total_infections,
        new_tbi_cases,
        new_active_cases,
        actual_beta
    )
end