module TBSimulator

using CSV
using DataFrames
using Dates
using Distributions
using JSON
using ProgressMeter
using StatsBase
using Random
using Printf

# Export core types and functions
export Agent, Population, Simulation, Config, SimulationResult
export load_config, run_simulation, run_calibration, parse_cli_args
export DiseaseState, Location, Gender, Male, Female, Susceptible, TBI, ActiveTB, Treatment, Home, Work, School

# Export agent functions
export get_location, will_progress_to_active, update_disease_state!, screen_agent!, start_tpt!, age_agent!

# Export population functions
export load_population!, load_demographic_data!, update_population!, process_deaths!, process_births!
export update_disease_counters!, remove_agent!, assign_random_workplace!, assign_random_school!
export check_contacts!, screen_household_contacts!

# Export simulation functions
export convert_config_to_dict, initialize_simulation

# Export calibration functions
export load_calibration_data, calculate_rmse

# Export utility functions
export setup_test_environment, create_test_population, create_test_asfr_data, create_test_asmr_data
export create_test_sex_ratio_data, create_test_incidence_data

# Define enums for disease states and location types
@enum DiseaseState Susceptible TBI ActiveTB Treatment
@enum Location Home Work School
@enum Gender Male Female

# Include all component files
include("agent.jl")
include("population.jl")
include("simulation.jl")
include("calibration.jl")
include("utils.jl")
include("analysis.jl")
include("cli.jl")

end # module