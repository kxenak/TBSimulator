#!/usr/bin/env julia

# Add the project to the load path
push!(LOAD_PATH, joinpath(dirname(@__FILE__), ".."))

using Test
using TBSimulator

# Make sure we export the enums in the global scope for tests
using TBSimulator: Male, Female, Susceptible, TBI, ActiveTB, Treatment, Home, Work, School
using TBSimulator: setup_test_environment

# Include test helper functions
include("test_helpers.jl")

# Run all tests
@testset "TBSimulator Tests" begin
    include("test_agent.jl")
    include("test_population.jl")
    include("test_simulation.jl")
    include("test_calibration.jl")
end

println("\nAll tests completed.")