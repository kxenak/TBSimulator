"""
    run_calibration(config::Config, tag::String="") -> Float64

Run the calibration process to find the optimal beta value.
"""
function run_calibration(config::Config, tag::String="")
    println("Starting calibration process...")
    
    # Load reference incidence data
    reference_data = load_calibration_data(config.calibration_incidence_data_path)
    
    # Set up beta range
    min_beta, max_beta, step_beta = config.beta_calibration_range
    beta_values = min_beta:step_beta:max_beta
    
    # Track results for each beta
    results = Dict{Float64, SimulationResult}()
    rmse_values = Dict{Float64, Float64}()
    
    # Run simulations for each beta value
    for beta in beta_values
        println("\nCalibrating with beta = $beta")
        
        # Run simulation with this beta
        result = run_simulation(config, beta, "$(tag)_beta$(beta)")
        
        # Calculate RMSE against reference data
        rmse = calculate_rmse(result.weekly_incidence, reference_data)
        
        # Store results
        results[beta] = result
        rmse_values[beta] = rmse
        
        println("Beta: $beta, RMSE: $rmse")
    end
    
    # Find best beta (minimum RMSE)
    best_beta = beta_values[argmin([rmse_values[beta] for beta in beta_values])]
    best_rmse = rmse_values[best_beta]
    
    println("\nCalibration completed.")
    println("Best beta value: $best_beta (RMSE: $best_rmse)")
    
    # Save calibration results
    output_dir = "results"
    isdir(output_dir) || mkdir(output_dir)
    
    # Create calibration summary
    calibration_summary = DataFrame(
        Beta = collect(beta_values),
        RMSE = [rmse_values[beta] for beta in beta_values]
    )
    
    # Save calibration summary
    result_tag = isempty(tag) ? "" : "_$(tag)"
    output_file = joinpath(output_dir, "calibration_summary$(result_tag).csv")
    CSV.write(output_file, calibration_summary)
    println("Calibration summary saved to: $output_file")
    
    # Save best beta value to file for easy reference
    open(joinpath(output_dir, "best_beta$(result_tag).txt"), "w") do io
        println(io, "Best beta: $best_beta")
        println(io, "RMSE: $best_rmse")
    end
    
    return best_beta
end

"""
    load_calibration_data(filepath::String) -> DataFrame

Load the reference incidence data for calibration.
"""
function load_calibration_data(filepath::String)
    # Load data
    data = CSV.read(filepath, DataFrame)
    
    # Ensure data has expected columns
    if !all(name -> name in names(data), ["year", "week", "incidence"])
        error("Calibration data must have 'year', 'week', and 'incidence' columns")
    end
    
    # Rename columns to match simulation output
    return rename(data, :year => :Year, :week => :Week, :incidence => :Reference)
end

"""
    calculate_rmse(simulated::DataFrame, reference::DataFrame) -> Float64

Calculate the root mean squared error between simulated and reference data.
"""
function calculate_rmse(simulated::DataFrame, reference::DataFrame)
    # Create merged dataframe with both simulated and reference values
    merged = innerjoin(simulated, reference, on=[:Year, :Week])
    
    # Calculate squared errors
    squared_errors = (merged.Incidence .- merged.Reference).^2
    
    # Calculate RMSE
    rmse = sqrt(mean(squared_errors))
    
    return rmse
end