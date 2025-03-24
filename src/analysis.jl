"""
    summarize_results(result_path::String)

Summarize the results of a simulation or calibration run.
"""
function summarize_results(result_path::String)
    println("Summarizing results from: $result_path")
    
    # Check if path exists
    if !isfile(result_path)
        error("Result file not found: $result_path")
    end
    
    # Load results
    results = CSV.read(result_path, DataFrame)
    
    # Check if disease states file
    if "Susceptible" in names(results)
        summarize_disease_states(results)
    elseif "Incidence" in names(results)
        summarize_incidence(results)
    else
        println("Unknown result format")
    end
end

"""
    summarize_disease_states(disease_states::DataFrame)

Summarize disease state data.
"""
function summarize_disease_states(disease_states::DataFrame)
    # Print summary statistics
    println("\nDisease State Summary:")
    println("-----------------------")
    
    # Calculate mean counts
    mean_susceptible = mean(disease_states.Susceptible)
    mean_tbi = mean(disease_states.TBI)
    mean_active = mean(disease_states.ActiveTB)
    mean_treatment = mean(disease_states.Treatment)
    
    # Calculate maximum counts
    max_susceptible = maximum(disease_states.Susceptible)
    max_tbi = maximum(disease_states.TBI)
    max_active = maximum(disease_states.ActiveTB)
    max_treatment = maximum(disease_states.Treatment)
    
    # Calculate minimum counts
    min_susceptible = minimum(disease_states.Susceptible)
    min_tbi = minimum(disease_states.TBI)
    min_active = minimum(disease_states.ActiveTB)
    min_treatment = minimum(disease_states.Treatment)
    
    # Print summary
    println("Susceptible: Mean=$(round(Int, mean_susceptible)), Min=$min_susceptible, Max=$max_susceptible")
    println("TBI: Mean=$(round(Int, mean_tbi)), Min=$min_tbi, Max=$max_tbi")
    println("Active TB: Mean=$(round(Int, mean_active)), Min=$min_active, Max=$max_active")
    println("Treatment: Mean=$(round(Int, mean_treatment)), Min=$min_treatment, Max=$max_treatment")
    
    # Calculate total population
    total_population = disease_states.Susceptible + disease_states.TBI + disease_states.ActiveTB + disease_states.Treatment
    mean_population = mean(total_population)
    
    println("\nTotal Population: Mean=$(round(Int, mean_population)), Min=$(minimum(total_population)), Max=$(maximum(total_population))")
    
    # Calculate TB prevalence
    tb_prevalence = (disease_states.ActiveTB ./ total_population) .* 100000
    mean_prevalence = mean(tb_prevalence)
    
    println("\nTB Prevalence (per 100,000): Mean=$(round(mean_prevalence, digits=1)), Min=$(round(minimum(tb_prevalence), digits=1)), Max=$(round(maximum(tb_prevalence), digits=1))")
    
    # Calculate new cases
    if "NewTBI" in names(disease_states) && "NewActiveTB" in names(disease_states)
        total_new_tbi = sum(disease_states.NewTBI)
        total_new_active = sum(disease_states.NewActiveTB)
        
        println("\nTotal New TBI Cases: $total_new_tbi")
        println("Total New Active TB Cases: $total_new_active")
    end
end

"""
    summarize_incidence(incidence::DataFrame)

Summarize incidence data.
"""
function summarize_incidence(incidence::DataFrame)
    # Print summary statistics
    println("\nIncidence Summary:")
    println("------------------")
    
    # Calculate total incidence
    total_incidence = sum(incidence.Incidence)
    
    # Calculate mean weekly incidence
    mean_incidence = mean(incidence.Incidence)
    
    # Calculate maximum and minimum incidence
    max_incidence = maximum(incidence.Incidence)
    min_incidence = minimum(incidence.Incidence)
    
    # Print summary
    println("Total Incidence: $total_incidence")
    println("Mean Weekly Incidence: $(round(mean_incidence, digits=1))")
    println("Maximum Weekly Incidence: $max_incidence")
    println("Minimum Weekly Incidence: $min_incidence")
    
    # Calculate yearly incidence if possible
    if "Year" in names(incidence)
        years = sort(unique(incidence.Year))
        
        println("\nYearly Incidence:")
        for year in years
            year_data = filter(row -> row.Year == year, incidence)
            year_total = sum(year_data.Incidence)
            println("$year: $year_total")
        end
    end
    
    # If reference data is available, calculate RMSE
    if "Reference" in names(incidence)
        rmse = sqrt(mean((incidence.Incidence .- incidence.Reference).^2))
        println("\nRMSE: $(round(rmse, digits=2))")
    end
end

"""
    plot_results(result_path::String, output_path::String="")

Plot the results of a simulation or calibration run.
Note: This requires the Plots package to be installed.
"""
function plot_results(result_path::String, output_path::String="")
    # Check if Plots package is available
    if !isdefined(Main, :Plots) && !haskey(Pkg.installed(), "Plots")
        println("Plots package not installed. Please install it to use this function.")
        println("You can install it with: using Pkg; Pkg.add(\"Plots\")")
        return
    end
    
    # Import Plots
    @eval using Plots
    
    # Check if path exists
    if !isfile(result_path)
        error("Result file not found: $result_path")
    end
    
    # Load results
    results = CSV.read(result_path, DataFrame)
    
    # Check file type and create appropriate plot
    if "Susceptible" in names(results)
        plot_disease_states(results, output_path)
    elseif "Incidence" in names(results)
        plot_incidence(results, output_path)
    else
        println("Unknown result format")
    end
end

"""
    plot_disease_states(disease_states::DataFrame, output_path::String="")

Plot disease state data.
"""
function plot_disease_states(disease_states::DataFrame, output_path::String="")
    @eval using Plots
    
    # Convert Date column if string
    if typeof(disease_states.Date) <: AbstractVector{<:AbstractString}
        disease_states.Date = Date.(disease_states.Date)
    end
    
    # Create plot
    p = plot(
        disease_states.Date, 
        [disease_states.Susceptible disease_states.TBI disease_states.ActiveTB disease_states.Treatment],
        labels=["Susceptible" "TBI" "Active TB" "Treatment"],
        xlabel="Date",
        ylabel="Number of Agents",
        title="TB Disease States",
        linewidth=2
    )
    
    # Save plot if output path provided
    if !isempty(output_path)
        savefig(p, output_path)
        println("Plot saved to: $output_path")
    end
    
    # Return plot object
    return p
end

"""
    plot_incidence(incidence::DataFrame, output_path::String="")

Plot incidence data.
"""
function plot_incidence(incidence::DataFrame, output_path::String="")
    @eval using Plots
    
    # Create date vector
    dates = Date[]
    for row in eachrow(incidence)
        push!(dates, Date(row.Year) + Week(row.Week))
    end
    
    # Create plot
    p = plot(
        dates, 
        incidence.Incidence,
        xlabel="Date",
        ylabel="Weekly Incidence",
        title="TB Weekly Incidence",
        linewidth=2,
        legend=false
    )
    
    # Add reference data if available
    if "Reference" in names(incidence)
        plot!(
            p,
            dates,
            incidence.Reference,
            linestyle=:dash,
            linewidth=2,
            label="Reference"
        )
    end
    
    # Save plot if output path provided
    if !isempty(output_path)
        savefig(p, output_path)
        println("Plot saved to: $output_path")
    end
    
    # Return plot object
    return p
end