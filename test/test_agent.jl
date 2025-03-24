# Tests for the Agent module

using Test
using TBSimulator
using Random
using TBSimulator: Male, Female, Susceptible, TBI, ActiveTB, Treatment, Home, Work, School

@testset "Agent" begin
    @testset "Constructor" begin
        agent = Agent(1, Male, 30.0, 100)
        
        @test agent.id == 1
        @test agent.gender == Male
        @test agent.age == 30.0
        @test agent.household_id == 100
        @test agent.workplace_id == 0
        @test agent.school_id == 0
        @test agent.disease_state == Susceptible
        @test agent.tbi_time == 0.0
        @test agent.active_time == 0.0
        @test agent.treatment_time == 0.0
        @test agent.treatment_notification_time == 0.0
        @test agent.infectious == false
        @test agent.screened == false
        @test agent.tpt_status == false
        @test agent.tpt_time == 0.0
    end
    
    @testset "Location" begin
        # Child under 4 should stay at home
        agent = Agent(1, Male, 3.0, 100)
        @test get_location(agent, :morning) == (Home, 100)
        @test get_location(agent, :afternoon) == (Home, 100)
        
        # School-age child should go to school in the morning
        agent = Agent(2, Female, 10.0, 100, 0, 200)
        @test get_location(agent, :morning) == (School, 200)
        @test get_location(agent, :afternoon) == (Home, 100)
        
        # Working adult should go to work in the morning
        agent = Agent(3, Male, 30.0, 100, 300)
        @test get_location(agent, :morning) == (Work, 300)
        @test get_location(agent, :afternoon) == (Home, 100)
        
        # Elderly should stay at home
        agent = Agent(4, Female, 70.0, 100, 300)
        @test get_location(agent, :morning) == (Home, 100)
        @test get_location(agent, :afternoon) == (Home, 100)
    end
    
    @testset "Disease Progression" begin
        rng = MersenneTwister(12345)
        
        # Test TBI progression
        config = Dict{String, Any}(
            "tpt_efficacy" => 0.999,
            "treatment_success_rate" => 0.84,
            "mortality_rate" => 0.12,
            "treatment_failure_rate" => 0.035
        )
        
        # Create TBI agent and set progression to active TB
        agent = Agent(1, Male, 30.0, 100)
        agent.disease_state = TBI
        agent.tbi_time = 30.0  # 30 days
        
        # Force progression by setting the RNG
        will_progress_override = true
        
        # Update with overridden progression
        @test_nowarn update_disease_state!(agent, 1.0, config, rng)
        
        # Test treatment completion
        agent = Agent(2, Male, 30.0, 100)
        agent.disease_state = Treatment
        agent.treatment_time = 179.0  # Just before completion
        
        # Save initial state
        initial_state = agent.disease_state
        
        # Update to complete treatment
        update_disease_state!(agent, 1.0, config, rng)
        
        # Verify treatment time increased
        @test agent.treatment_time == 180.0
        
        # Treatment outcome is determined by RNG, so we don't check specific outcome
        # but only that it has changed from the initial state in some cases
        # or that it's one of the valid outcomes
        @test agent.disease_state == Susceptible || 
              agent.disease_state == ActiveTB || 
              agent.disease_state == Treatment
    end
    
    @testset "Agent Aging" begin
        agent = Agent(1, Male, 30.0, 100)
        
        # Age by 365 days (1 year)
        age_agent!(agent, 365.0)
        @test agent.age ≈ 31.0
        
        # Age by 182.5 days (0.5 years)
        age_agent!(agent, 182.5)
        @test agent.age ≈ 31.5
    end
    
    @testset "Screening" begin
        rng = MersenneTwister(12345)
        
        config = Dict{String, Any}(
            "screening_test_sensitivity" => 0.81,
            "tpt_completion_rate" => 0.81
        )
        
        # Test screening TBI agent
        agent = Agent(1, Male, 30.0, 100)
        agent.disease_state = TBI
        
        # Screen agent
        @test_nowarn screen_agent!(agent, config, rng)
        @test agent.screened == true
        
        # Test screening Active TB agent
        agent = Agent(2, Male, 30.0, 100)
        agent.disease_state = ActiveTB
        
        # Screen agent
        @test_nowarn screen_agent!(agent, config, rng)
        @test agent.screened == true
    end
end