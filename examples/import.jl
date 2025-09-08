# read a netCDF file and convert to a DataFrame
using DataFrames
using NCDatasets
using ControlPlots
using Dates
using JLD2
using AnalyzeWind

# Function to print all variables in a NetCDF dataset
function print_variables(ds; filter="")
    for key in keys(ds)
        if filter == "" || occursin(filter, key)
            println(key)
        end
    end
end

# Example: Process a single file
path = joinpath(@__DIR__, "..", "data", "WindData", "10min_dataset")
filename="NSO-met-mast-data-10min_2021-08-09-16-40-00_2021-08-10-00-00-00.nc"

ds = Dataset(joinpath(path, filename))

# Print all variables in the dataset
println("All variables in the dataset:")
print_variables(ds)
println()

# The dataset contains wind data measured at 32m and 92m height
# You can access the variables in the dataset using ds["variable_name"]
# For example, to access the wind speed at 32m height:
wind_speed_32m = ds["USA3D_32m_S_Spd_8Hz_Calc_Avg"][:]
# And wind speed at 92m height:
wind_speed_92m = ds["USA3D_92m_S_Spd_8Hz_Calc_Avg"][:]
# And wind direction at 32m height:
wind_direction_32m = ds["USA3D_32m_S_Dir_8Hz_Calc_Avg"][:]
# And wind direction at 92m height:
wind_direction_92m = ds["USA3D_92m_S_Dir_8Hz_Calc_Avg"][:]
time_stamp = ds["TIMESTAMP"][:]
# Calculate relative time in seconds from the first timestamp
rel_time = [(t - time_stamp[1]).value / 1000.0 for t in time_stamp]
# Convert missing values to NaN and create Vector{Float64}
wind_speed_32m_clean = replace(wind_speed_32m, missing => NaN)
wind_speed_92m_clean = replace(wind_speed_92m, missing => NaN)
wind_direction_32m_clean = replace(wind_direction_32m, missing => NaN)
wind_direction_92m_clean = replace(wind_direction_92m, missing => NaN)
# Convert the data to a DataFrame
df = DataFrame(timestamp = time_stamp, rel_time = rel_time, 
               wind_speed_32m = wind_speed_32m_clean, wind_speed_92m = wind_speed_92m_clean,
               wind_direction_32m = wind_direction_32m_clean, wind_direction_92m = wind_direction_92m_clean)
# Plot both wind speeds using ControlPlots syntax
p=plot(df.rel_time, [df.wind_speed_32m, df.wind_speed_92m], xlabel="Time (s)", ylabel="Wind Speed (m/s)",
     labels=["Wind Speed 32m", "Wind Speed 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
     fig="$(time_stamp[1])")
display(p)

# Plot wind directions
plot(df.rel_time, [df.wind_direction_32m, df.wind_direction_92m], xlabel="Time (s)", ylabel="Wind Direction (°)",
     labels=["Wind Direction 32m", "Wind Direction 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
     fig="Wind_Direction_$(time_stamp[1])")

# close(ds)

# calculate the position of the meteorological mast
# using Proj

# proj_string = "+proj=utm +zone=32 +datum=WGS84"
# transformer = Proj.Transformation(proj_string, "+proj=longlat +datum=WGS84")
# lon, lat = transformer(411734.4371, 6028967.271)


