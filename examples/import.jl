# read a netCDF file and convert to a DataFrame
using DataFrames
using NCDatasets
using ControlPlots
using Dates

path = joinpath(@__DIR__, "..", "data", "WindData", "10min_dataset")
filename="NSO-met-mast-data-10min_2021-08-09-16-40-00_2021-08-10-00-00-00.nc"

ds = Dataset(joinpath(path, filename))
# The dataset contains wind data measured at 32m and 92m height
# You can access the variables in the dataset using ds["variable_name"]
# For example, to access the wind speed at 32m height:
wind_speed_32m = ds["USA3D_32m_S_Spd_8Hz_Calc_Avg"][:]
time_stamp = ds["TIMESTAMP"][:]
# Calculate relative time in seconds from the first timestamp
rel_time = [(t - time_stamp[1]).value / 1000.0 for t in time_stamp]
# Convert missing values to NaN and create Vector{Float64}
wind_speed_clean = replace(wind_speed_32m, missing => NaN)
# Convert the data to a DataFrame
df = DataFrame(timestamp = time_stamp, rel_time = rel_time, wind_speed_32m = wind_speed_clean)
plot(df.rel_time, df.wind_speed_32m)
