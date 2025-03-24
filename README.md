# TBSimulator

An agent-based model for tuberculosis (TB) transmission dynamics simulation based on contact patterns, demographic data, and disease progression.

## Overview

The TBSimulator is a sophisticated model that simulates TB transmission within a population by tracking:

- Individual disease states (Susceptible, TB Infection, Active TB, Treatment)
- Contact patterns between individuals at home, school, and work
- Population dynamics including births, deaths, and aging
- TB progression, screening, treatment, and prevention

The model is designed to help understand TB transmission dynamics and evaluate the effectiveness of different intervention strategies.

## Features

- **Agent-Based Modeling**: Each individual in the synthetic population is modeled as an agent with their own characteristics and disease state.
- **Contact Patterns**: Simulates TB transmission through different contact locations (homes, workplaces, schools).
- **Population Dynamics**: Models births and deaths based on age-specific rates and sex ratios.
- **Disease Progression**: Implements realistic TB pathways for infection, progression to active disease, and treatment outcomes.
- **Calibration**: Includes tools for calibrating the model against real-world TB incidence data.
- **Intervention Modeling**: Simulates TB screening and preventive therapy for contacts of TB cases.

## Installation

Install Julia dependencies:
   ```
   julia --project -e 'using Pkg; Pkg.instantiate()'
   ```

## Data Requirements

The simulator requires the following data files:

1. **Synthetic Population** (CSV format) with the following columns:
   - SexLabel: Gender of the agent
   - Age: Age in years
   - HHID: Household ID
   - WorkPlaceID: Workplace ID (0 if not working)
   - SchoolID: School ID (0 if not in school)
   - AgentID: Unique identifier for the agent
   - And other demographic columns

2. **Age-Specific Fertility Rate** (CSV format) with columns:
   - Year: Calendar year
   - Age group: Age group of women (e.g., "15-19", "20-24", etc.)
   - Fertility Rate: Number of live births per 1000 women

3. **Age-Specific Mortality Rate** (CSV format) with columns:
   - Year: Calendar year
   - Age group: Age group
   - Total: Overall mortality rate
   - Male: Male-specific mortality rate
   - Female: Female-specific mortality rate

4. **Sex Ratio at Birth Data** (CSV format) with columns:
   - Year: Calendar year
   - Ratio: Number of females per 1000 males

5. **Weekly Incidence Data** (for calibration, CSV format) with columns:
   - year: Calendar year
   - week: Week number
   - incidence: Number of new TB cases

## Configuration Parameters

The simulator is controlled through a config file in JSON format with the following parameters:

### General Settings

- **mode**: Either "calibration" or "simulation". In calibration mode, the simulator tries different beta values to find the best match with historical data. In simulation mode, it runs with a fixed beta value.
- **beta_calibration_range**: Array of [min, max, step] values for beta calibration.
- **beta**: Transmission rate parameter (used in simulation mode).
- **num_simulations**: Number of simulation runs to perform.
- **timestep**: Time increment in days (e.g., 0.5 for half-day steps).

### Time Periods

- **calibration_start_date**: Starting date for calibration period (format: "YYYY-MM-DD").
- **calibration_end_date**: Ending date for calibration period.
- **simulation_start_date**: Starting date for simulation period.
- **simulation_end_date**: Ending date for simulation period.

### Disease Parameters

- **infection_factor**: Multiplier for the infection rate.
- **initial_tbi_percentage**: Initial percentage of population with TB infection.
- **initial_active_tbi_percentage**: Initial percentage of population with active TB.

### Population Parameters

- **men_working_percentage**: Percentage of adult men who work.
- **women_working_percentage**: Percentage of adult women who work.

### Intervention Parameters

- **screening_test_sensitivity**: Sensitivity of TB screening tests (0-1).
- **tpt_efficacy**: Efficacy of TB preventive therapy (0-1).
- **treatment_success_rate**: Probability of successful TB treatment (0-1).
- **mortality_rate**: Probability of death during TB treatment (0-1).
- **treatment_failure_rate**: Probability of treatment failure (0-1).
- **tpt_completion_rate**: Probability of completing TB preventive therapy (0-1).

### File Paths

- **synthetic_population_path**: Path to synthetic population CSV file.
- **asfr_path**: Path to age-specific fertility rate CSV file.
- **asmr_path**: Path to age-specific mortality rate CSV file.
- **calibration_incidence_data_path**: Path to weekly incidence data CSV file.
- **sex_ratio_path**: Path to sex ratio at birth CSV file.

### Example Configuration

```json
{
  "mode": "simulation",
  "beta_calibration_range": [0.01, 0.5, 0.01],
  "beta": 0.2,
  "num_simulations": 10,
  "timestep": 0.5,
  "calibration_start_date": "2021-01-01",
  "calibration_end_date": "2023-12-31",
  "simulation_start_date": "2025-01-01",
  "simulation_end_date": "2030-12-31",
  "infection_factor": 1.0,
  "initial_tbi_percentage": 31.3,
  "initial_active_tbi_percentage": 0.115,
  "men_working_percentage": 76.1,
  "women_working_percentage": 39.6,
  "screening_test_sensitivity": 0.81,
  "tpt_efficacy": 0.999,
  "treatment_success_rate": 0.84,
  "mortality_rate": 0.12,
  "treatment_failure_rate": 0.035,
  "tpt_completion_rate": 0.81,
  "synthetic_population_path": "data/synthetic.csv",
  "asfr_path": "data/asfr.csv",
  "asmr_path": "data/asmr.csv",
  "calibration_incidence_data_path": "data/weekly_incidence.csv",
  "sex_ratio_path": "data/sex_ratio_at_birth.csv"
}
```

## Running the Simulator

### Calibration Mode

In calibration mode, the simulator finds the optimal beta value by comparing simulation results to historical incidence data:

```bash
julia --project src/cli.jl --mode calibration --config config/your_config.json
```

The calibration process will:
1. Try different beta values within the specified range
2. Run simulations for each beta value
3. Compare results to the historical data
4. Identify the best beta value based on root mean squared error (RMSE)

The results will be saved to the `results` directory, including a `best_beta.txt` file containing the optimal beta value.

### Simulation Mode

Once you have calibrated the model, run simulations with the optimal beta value:

```bash
julia --project src/cli.jl --mode simulation --config config/your_config.json --tag scenario1
```

The `--tag` parameter is optional and will be appended to output filenames to identify different simulation runs.

### Command-Line Arguments

- `--mode`: Specifies whether to run in "calibration" or "simulation" mode
- `--config`: Path to the configuration file
- `--tag`: (Optional) Tag to append to output filenames
- `--help`: Display help information

## Outputs

The simulator generates the following outputs in the `results` directory:

1. **Disease State Counts**: CSV file with the number of individuals in each disease state at each timestep.
2. **Weekly Incidence**: CSV file with the number of new TB cases per week.
3. **Calibration Results**: (In calibration mode) CSV file with RMSE values for different beta values.

## Testing

The test suite verifies all components of the simulator:

```bash
julia --project test/runtests.jl
```

## Implementation Details

The model handles TB transmission as follows:

- Individuals spend half the day at home and half at work/school (or home for non-working adults and young children).
- TB transmission occurs based on contact patterns and the infectiousness of TB cases.
- Newly infected individuals move to the TBI (TB Infection) state.
- About 10% of TBI cases progress to active TB, with most progressing within 5 years of infection.
- Active TB cases become non-infectious 2 weeks after starting treatment.
- Treatment outcomes include success, failure, or mortality.
- Household contacts of TB cases are screened and offered preventive therapy if infected.