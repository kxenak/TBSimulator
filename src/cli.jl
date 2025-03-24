#!/usr/bin/env julia

"""
    parse_cli_args() -> Dict{String, Any}

Parse command-line arguments for the TB simulator.
"""
function parse_cli_args()
    # Define command-line arguments
    args = Dict{String, Any}()
    
    # Check for mode flag
    mode_index = findfirst(arg -> arg == "--mode", ARGS)
    if !isnothing(mode_index) && mode_index < length(ARGS)
        args["mode"] = ARGS[mode_index + 1]
    else
        args["mode"] = "simulation"  # Default mode
    end
    
    # Check for config flag
    config_index = findfirst(arg -> arg == "--config", ARGS)
    if !isnothing(config_index) && config_index < length(ARGS)
        args["config"] = ARGS[config_index + 1]
    else
        args["config"] = "config/config.json"  # Default config path
    end
    
    # Check for tag flag
    tag_index = findfirst(arg -> arg == "--tag", ARGS)
    if !isnothing(tag_index) && tag_index < length(ARGS)
        args["tag"] = ARGS[tag_index + 1]
    else
        args["tag"] = ""  # Default tag
    end
    
    # Check for help flag
    if "--help" in ARGS || "-h" in ARGS
        println("""
        TBSimulator - Agent-based TB transmission dynamics simulator
        
        Usage:
          julia --project src/cli.jl [options]
        
        Options:
          --mode MODE       Simulation mode: "calibration" or "simulation" (default: simulation)
          --config PATH     Path to config file (default: config/config.json)
          --tag TAG         Tag to append to output file names (optional)
          --help, -h        Show this help message
        
        Examples:
          julia --project src/cli.jl --mode calibration --config config/custom_config.json
          julia --project src/cli.jl --mode simulation --config config/config.json --tag run1
        """)
        exit(0)
    end
    
    return args
end

# Main entry point when run as a script
if abspath(PROGRAM_FILE) == @__FILE__
    # Make sure we're running in the correct directory
    if !isdir("src")
        cd(dirname(dirname(@__FILE__)))
    end
    
    # Add the current directory to the load path
    if "." ∉ LOAD_PATH
        push!(LOAD_PATH, ".")
    end
    
    # Parse command-line arguments
    args = parse_cli_args()
    
    # Import the TBSimulator module
    using TBSimulator
    
    # Load configuration
    config = load_config(args["config"])
    
    # Override mode if specified
    if args["mode"] != config.mode
        println("Overriding mode from $(config.mode) to $(args["mode"])")
        config = Config(
            args["mode"],
            config.beta_calibration_range,
            config.beta,
            config.num_simulations,
            config.timestep,
            config.calibration_start_date,
            config.calibration_end_date,
            config.simulation_start_date,
            config.simulation_end_date,
            config.infection_factor,
            config.initial_tbi_percentage,
            config.initial_active_tbi_percentage,
            config.men_working_percentage,
            config.women_working_percentage,
            config.screening_test_sensitivity,
            config.tpt_efficacy,
            config.treatment_success_rate,
            config.mortality_rate,
            config.treatment_failure_rate,
            config.tpt_completion_rate,
            config.synthetic_population_path,
            config.asfr_path,
            config.asmr_path,
            config.calibration_incidence_data_path,
            config.sex_ratio_path
        )
    end
    
    # Run in appropriate mode
    if config.mode == "calibration"
        println("Running in calibration mode")
        best_beta = run_calibration(config, args["tag"])
        println("Calibration complete. Best beta: $best_beta")
    else
        println("Running in simulation mode")
        result = run_simulation(config, nothing, args["tag"])
        println("Simulation complete.")
    end
end