"""
    create_test_population(num_agents::Int=1000, output_path::String="test_synthetic.csv") -> String

Create a small synthetic population for testing.
"""
function create_test_population(num_agents::Int=1000, output_path::String="test_synthetic.csv")
    # Create random synthetic population for testing
    rng = MersenneTwister(1234)
    
    # Initialize data structures
    sex_labels = ["Male", "Female"]
    age_groups = [
        (0, 4), (5, 17), (18, 24), (25, 34), 
        (35, 44), (45, 54), (55, 64), (65, 74), (75, 90)
    ]
    religions = ["Hindu", "Muslim", "Christian", "Other"]
    castes = ["General", "OBC", "SC", "ST", "Other"]
    districts = ["thiruvananthapuram", "kollam", "pathanamthitta", "alappuzha", "kottayam"]
    job_labels = ["Teacher", "Accountants", "Doctor", "Engineer", "Farmer", "Unemployed", "Student"]
    
    # Generate random data
    data = []
    
    # Generate households first
    num_households = round(Int, num_agents / 4)  # Average 4 people per household
    households = []
    for h in 1:num_households
        household_id = 600000 + h
        h_lat = 8.4 + rand(rng) * 0.5
        h_lon = 77.0 + rand(rng) * 0.5
        admin_unit = rand(rng, districts)
        admin_lat = h_lat + rand(rng) * 0.1
        admin_lon = h_lon + rand(rng) * 0.1
        
        push!(households, (household_id, h_lat, h_lon, admin_unit, admin_lat, admin_lon))
    end
    
    # Generate workplaces
    num_workplaces = round(Int, num_agents / 20)  # Average 20 people per workplace
    workplaces = []
    for w in 1:num_workplaces
        workplace_id = 2001000000000 + w
        w_lat = 8.3 + rand(rng) * 0.6
        w_lon = 77.0 + rand(rng) * 0.6
        admin_unit = rand(rng, districts)
        
        push!(workplaces, (workplace_id, w_lat, w_lon, admin_unit))
    end
    
    # Generate schools
    num_schools = round(Int, num_agents / 50)  # Average 50 students per school
    schools = []
    for s in 1:num_schools
        school_id = 1001000000000 + s
        s_lat = 8.3 + rand(rng) * 0.6
        s_lon = 77.0 + rand(rng) * 0.6
        admin_unit = rand(rng, districts)
        
        push!(schools, (school_id, s_lat, s_lon, admin_unit))
    end
    
    # Generate public places
    num_public_places = round(Int, num_agents / 100)  # Average 100 people per public place
    public_places = []
    for p in 1:num_public_places
        public_place_id = 3001000000000 + p
        p_lat = 8.3 + rand(rng) * 0.6
        p_lon = 77.0 + rand(rng) * 0.6
        
        push!(public_places, (public_place_id, p_lat, p_lon))
    end
    
    # Generate agents
    for i in 1:num_agents
        agent_id = 521000000000 + i
        
        # Basic demographics
        sex_label = rand(rng, sex_labels)
        age_group = rand(rng, age_groups)
        age = age_group[1] + rand(rng) * (age_group[2] - age_group[1])
        religion = rand(rng, religions)
        caste = rand(rng, castes)
        
        # Assign household
        household = rand(rng, households)
        household_id = household[1]
        h_lat = household[2]
        h_lon = household[3]
        admin_unit = household[4]
        admin_lat = household[5]
        admin_lon = household[6]
        
        # Assign workplace based on age
        workplace_id = 0
        w_lat = ""
        w_lon = ""
        workplace_admin_unit = ""
        job_label = "Unemployed"
        
        if 18 <= age < 65
            job_label = rand(rng, job_labels[1:6])  # Exclude "Student"
            if job_label != "Unemployed"
                workplace = rand(rng, workplaces)
                workplace_id = workplace[1]
                w_lat = workplace[2]
                w_lon = workplace[3]
                workplace_admin_unit = workplace[4]
            end
        end
        
        # Assign school for children
        school_id = 0
        school_lat = ""
        school_lon = ""
        school_admin_unit = ""
        
        if 4 <= age < 18
            job_label = "Student"
            school = rand(rng, schools)
            school_id = school[1]
            school_lat = school[2]
            school_lon = school[3]
            school_admin_unit = school[4]
        end
        
        # Assign public place
        public_place = rand(rng, public_places)
        public_place_id = public_place[1]
        public_place_lat = public_place[2]
        public_place_lon = public_place[3]
        
        # Other attributes
        district = admin_unit
        state_label = "kerala"
        adherence = rand(rng)
        essential_worker = rand(rng) < 0.1
        uses_public_transport = rand(rng) < 0.5
        
        # Create entry
        push!(data, (
            sex_label, age, religion, caste, household_id, h_lat, h_lon,
            admin_unit, admin_lat, admin_lon, job_label, workplace_id, w_lat, w_lon,
            school_id, school_lat, school_lon, public_place_id, public_place_lat, public_place_lon,
            district, state_label, agent_id, adherence, essential_worker, uses_public_transport,
            workplace_admin_unit, school_admin_unit
        ))
    end
    
    # Create dataframe
    df = DataFrame(
        SexLabel = [d[1] for d in data],
        Age = [d[2] for d in data],
        Religion = [d[3] for d in data],
        Caste = [d[4] for d in data],
        HHID = [d[5] for d in data],
        H_Lat = [d[6] for d in data],
        H_Lon = [d[7] for d in data],
        AdminUnit_Name = [d[8] for d in data],
        AdminUnit_Lat = [d[9] for d in data],
        AdminUnit_Lon = [d[10] for d in data],
        JobLabel = [d[11] for d in data],
        WorkPlaceID = [d[12] for d in data],
        W_Lat = [d[13] for d in data],
        W_Lon = [d[14] for d in data],
        SchoolID = [d[15] for d in data],
        School_Lat = [d[16] for d in data],
        School_Lon = [d[17] for d in data],
        PublicPlaceID = [d[18] for d in data],
        PublicPlace_Lat = [d[19] for d in data],
        PublicPlace_Lon = [d[20] for d in data],
        District = [d[21] for d in data],
        StateLabel = [d[22] for d in data],
        AgentID = [d[23] for d in data],
        AdherenceToIntervention = [d[24] for d in data],
        EssentialWorker = [d[25] for d in data],
        UsesPublicTransport = [d[26] for d in data],
        WorkPlace_AdminUnit = [d[27] for d in data],
        School_AdminUnit = [d[28] for d in data]
    )
    
    # Save to CSV
    CSV.write(output_path, df)
    
    return output_path
end

"""
    create_test_asfr_data(output_path::String="test_asfr.csv") -> String

Create test age-specific fertility rate data.
"""
function create_test_asfr_data(output_path::String="test_asfr.csv")
    # Create range of years
    years = 2011:2029
    age_groups = ["15-19", "20-24", "25-29", "30-34", "35-39", "40-44", "45-49"]
    
    # Base fertility rates
    base_rates = [10.5, 95.3, 125.7, 80.2, 32.1, 8.4, 1.2]
    
    # Generate data
    data = []
    for year in years
        for (i, age_group) in enumerate(age_groups)
            # Slight variation by year
            rate = base_rates[i] * (1.0 + (year - 2020) * 0.01)
            push!(data, (year, age_group, rate))
        end
    end
    
    # Create dataframe
    df = DataFrame(
        Year = [d[1] for d in data],
        Age_group = [d[2] for d in data],
        Fertility_Rate = [d[3] for d in data]
    )
    
    # Rename columns to match expected format
    rename!(df, :Age_group => "Age group", :Fertility_Rate => "Fertility Rate")
    
    # Save to CSV
    CSV.write(output_path, df)
    
    return output_path
end

"""
    create_test_asmr_data(output_path::String="test_asmr.csv") -> String

Create test age-specific mortality rate data.
"""
function create_test_asmr_data(output_path::String="test_asmr.csv")
    # Create range of years
    years = 2011:2029
    age_groups = [
        "0-4", "5-9", "10-14", "15-19", "20-24", "25-29", "30-34", "35-39",
        "40-44", "45-49", "50-54", "55-59", "60-64", "65-69", "70-74", "75-79",
        "80-84", "85 +"
    ]
    
    # Base mortality rates
    base_total_rates = [
        1.8, 0.5, 0.5, 0.7, 1.1, 1.3, 1.5, 2.0,
        3.0, 4.5, 7.2, 11.0, 16.5, 26.3, 41.1, 64.2,
        97.6, 202.7
    ]
    
    base_male_rates = [
        2.6, 0.6, 0.5, 0.9, 1.5, 1.7, 1.9, 2.5,
        3.8, 5.9, 9.4, 14.3, 21.5, 34.2, 53.4, 83.4,
        116.9, 226.2
    ]
    
    base_female_rates = [
        0.9, 0.4, 0.4, 0.5, 0.7, 0.9, 1.1, 1.5,
        2.2, 3.1, 5.0, 7.7, 11.5, 18.4, 28.8, 45.0,
        85.0, 189.3
    ]
    
    # Generate data
    data = []
    for year in years
        for (i, age_group) in enumerate(age_groups)
            # Slight variation by year
            total_rate = base_total_rates[i] * (1.0 - (year - 2020) * 0.002)
            male_rate = base_male_rates[i] * (1.0 - (year - 2020) * 0.002)
            female_rate = base_female_rates[i] * (1.0 - (year - 2020) * 0.002)
            
            push!(data, (year, age_group, total_rate, male_rate, female_rate))
        end
        
        # Add "All ages" row
        push!(data, (year, "All ages", 7.0, 8.3, 5.8))
        
        # Add extra rows for "Below 1" and "1-4"
        push!(data, (year, "Below 1", 7.8, 12.8, 3.0))
        push!(data, (year, "1-4", 0.5, 0.6, 0.4))
    end
    
    # Create dataframe
    df = DataFrame(
        Year = [d[1] for d in data],
        Age_group = [d[2] for d in data],
        Total = [d[3] for d in data],
        Male = [d[4] for d in data],
        Female = [d[5] for d in data]
    )
    
    # Rename columns to match expected format
    rename!(df, :Age_group => "Age group")
    
    # Save to CSV
    CSV.write(output_path, df)
    
    return output_path
end

"""
    create_test_sex_ratio_data(output_path::String="test_sex_ratio_at_birth.csv") -> String

Create test sex ratio at birth data.
"""
function create_test_sex_ratio_data(output_path::String="test_sex_ratio_at_birth.csv")
    # Create range of years
    years = 2011:2029
    
    # Base sex ratio (females per 1000 males)
    base_ratio = 950
    
    # Generate data
    data = []
    for year in years
        # Slight increase over time
        ratio = base_ratio + (year - 2011) * 1.0
        push!(data, (year, ratio))
    end
    
    # Create dataframe
    df = DataFrame(
        Year = [d[1] for d in data],
        Ratio = [d[2] for d in data]
    )
    
    # Save to CSV
    CSV.write(output_path, df)
    
    return output_path
end

"""
    create_test_incidence_data(output_path::String="test_weekly_incidence.csv") -> String

Create test weekly incidence data for calibration.
"""
function create_test_incidence_data(output_path::String="test_weekly_incidence.csv")
    # Generate weekly data for 2021-2024
    data = []
    
    # Base weekly incidence
    base_incidence = 20
    
    # Generate data with seasonality and random variation
    for year in 2021:2024
        for week in 1:53
            # Add seasonal variation
            seasonal = 5 * sin(2π * week / 52)
            
            # Add random variation
            random = rand(MersenneTwister(year * 100 + week)) * 10 - 5
            
            # Calculate incidence
            incidence = max(0, round(Int, base_incidence + seasonal + random))
            
            push!(data, (year, week, incidence))
        end
    end
    
    # Create dataframe
    df = DataFrame(
        year = [d[1] for d in data],
        week = [d[2] for d in data],
        incidence = [d[3] for d in data]
    )
    
    # Save to CSV
    CSV.write(output_path, df)
    
    return output_path
end

"""
    setup_test_environment() -> Dict{String, String}

Create a test environment with all necessary files.
"""
function setup_test_environment()
    # Create test data directory
    test_dir = "test_data"
    isdir(test_dir) || mkdir(test_dir)
    
    # Create test data files
    synthetic_path = joinpath(test_dir, "test_synthetic.csv")
    create_test_population(1000, synthetic_path)
    
    asfr_path = joinpath(test_dir, "test_asfr.csv")
    create_test_asfr_data(asfr_path)
    
    asmr_path = joinpath(test_dir, "test_asmr.csv")
    create_test_asmr_data(asmr_path)
    
    sex_ratio_path = joinpath(test_dir, "test_sex_ratio_at_birth.csv")
    create_test_sex_ratio_data(sex_ratio_path)
    
    incidence_path = joinpath(test_dir, "test_weekly_incidence.csv")
    create_test_incidence_data(incidence_path)
    
    # Return paths
    return Dict(
        "synthetic_path" => synthetic_path,
        "asfr_path" => asfr_path,
        "asmr_path" => asmr_path,
        "sex_ratio_path" => sex_ratio_path,
        "incidence_path" => incidence_path
    )
end