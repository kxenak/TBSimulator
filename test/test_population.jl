# Tests for the Population module

using Test
using TBSimulator
using Random
using Dates
using TBSimulator: Male, Female, Susceptible, TBI, ActiveTB, Treatment, Home, Work, School
using TBSimulator: setup_test_environment

@testset "Population" begin
    @testset "Constructor" begin
        population = Population()
        
        @test isempty(population.agents)
        @test isempty(population.households)
        @test isempty(population.workplaces)
        @test isempty(population.schools)
        @test isempty(population.all_workplace_ids)
        @test isempty(population.all_school_ids)
        @test isempty(population.asfr_data)
        @test isempty(population.asmr_data)
        @test isempty(population.sex_ratio_data)
        @test population.susceptible_count == 0
        @test population.tbi_count == 0
        @test population.active_count == 0
        @test population.treatment_count == 0
    end
    
    @testset "Test Environment" begin
        # Create test environment
        data_paths = setup_test_environment()
        
        # Check that all files were created
        @test isfile(data_paths["synthetic_path"])
        @test isfile(data_paths["asfr_path"])
        @test isfile(data_paths["asmr_path"])
        @test isfile(data_paths["sex_ratio_path"])
        @test isfile(data_paths["incidence_path"])
    end
    
    @testset "Load Population" begin
        # Create a small test population
        data_paths = setup_test_environment()
        
        # Create population
        population = Population()
        
        # Create config
        config = Dict{String, Any}(
            "initial_tbi_percentage" => 31.3,
            "initial_active_tbi_percentage" => 0.115,
            "men_working_percentage" => 76.1,
            "women_working_percentage" => 39.6
        )
        
        # Load population
        rng = MersenneTwister(12345)
        @test_nowarn load_population!(population, data_paths["synthetic_path"], config, rng)
        
        # Check that population was loaded
        @test !isempty(population.agents)
        @test !isempty(population.households)
        
        # Check that some agents were assigned to disease states
        @test population.susceptible_count > 0
        @test population.tbi_count > 0
        @test population.active_count > 0
    end
    
    @testset "Load Demographic Data" begin
        # Create a small test population
        data_paths = setup_test_environment()
        
        # Create population
        population = Population()
        
        # Load demographic data
        @test_nowarn load_demographic_data!(population, data_paths["asfr_path"], data_paths["asmr_path"], data_paths["sex_ratio_path"])
        
        # Check that demographic data was loaded
        @test !isempty(population.asfr_data)
        @test !isempty(population.asmr_data)
        @test !isempty(population.sex_ratio_data)
    end
    
    @testset "Update Population" begin
        # Create a small test population
        data_paths = setup_test_environment()
        
        # Create population
        population = Population()
        
        # Create config
        config = Dict{String, Any}(
            "initial_tbi_percentage" => 31.3,
            "initial_active_tbi_percentage" => 0.115,
            "men_working_percentage" => 76.1,
            "women_working_percentage" => 39.6
        )
        
        # Load population and demographic data
        rng = MersenneTwister(12345)
        load_population!(population, data_paths["synthetic_path"], config, rng)
        load_demographic_data!(population, data_paths["asfr_path"], data_paths["asmr_path"], data_paths["sex_ratio_path"])
        
        # Update population
        current_date = Date(2021, 1, 1)
        timestep = 0.5  # half day
        
        # Should not error
        @test_nowarn begin
            # Patch in our update_disease_counters! function
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
    end
    
    @testset "Contact Tracing" begin
        # Create a small test population
        population = Population()
        
        # Create two households
        household1 = 1001
        household2 = 1002
        
        # Create agents in household 1 (with active TB)
        agent1 = Agent(1, Male, 30.0, household1)
        agent1.disease_state = ActiveTB
        agent1.infectious = true
        agent1.treatment_notification_time = 100.0  # Notified
        
        agent2 = Agent(2, Female, 28.0, household1)
        agent2.disease_state = Susceptible
        
        # Create agents in household 2 (no TB)
        agent3 = Agent(3, Male, 35.0, household2)
        agent3.disease_state = Susceptible
        
        agent4 = Agent(4, Female, 33.0, household2)
        agent4.disease_state = Susceptible
        
        # Add agents to population
        population.agents[1] = agent1
        population.agents[2] = agent2
        population.agents[3] = agent3
        population.agents[4] = agent4
        
        # Add households
        population.households[household1] = [1, 2]
        population.households[household2] = [3, 4]
        
        # Set up config
        config = Dict{String, Any}(
            "screening_test_sensitivity" => 0.81,
            "tpt_completion_rate" => 0.81
        )
        
        # Screen household contacts
        rng = MersenneTwister(12345)
        @test_nowarn screen_household_contacts!(population, config, rng)
        
        # Check that household 1 contacts were screened but not household 2
        @test population.agents[2].screened == true
        @test population.agents[3].screened == false
        @test population.agents[4].screened == false
    end
end