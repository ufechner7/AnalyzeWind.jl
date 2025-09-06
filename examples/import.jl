# read a netCDF file and convert to a DataFrame
using DataFrames
using NCDatasets
using ControlPlots
using Dates
using JLD2

"""
    process_all_nc_files(folder_path::String)

Read all *.nc files in the specified folder, convert them to a single DataFrame,
and save the result as "10_min_data.jld2" in the same folder.

Returns the combined DataFrame.
"""
function process_all_nc_files(folder_path::String)
    # Find all .nc files in the folder
    nc_files = filter(x -> endswith(x, ".nc"), readdir(folder_path))
    
    if isempty(nc_files)
        error("No .nc files found in $folder_path")
    end
    
    println("Found $(length(nc_files)) .nc files to process...")
    
    # Initialize empty DataFrame
    combined_df = DataFrame()
    
    for (i, filename) in enumerate(nc_files)
        println("Processing file $i/$(length(nc_files)): $filename")
        
        try
            # Open dataset
            ds = Dataset(joinpath(folder_path, filename))
            
            # Extract data
            wind_speed_32m = ds["USA3D_32m_S_Spd_8Hz_Calc_Avg"][:]
            wind_speed_92m = ds["USA3D_92m_S_Spd_8Hz_Calc_Avg"][:]
            time_stamp = ds["TIMESTAMP"][:]
            
            # Clean missing values
            wind_speed_32m_clean = replace(wind_speed_32m, missing => NaN)
            wind_speed_92m_clean = replace(wind_speed_92m, missing => NaN)
            
            # Create DataFrame for this file
            file_df = DataFrame(
                timestamp = time_stamp,
                wind_speed_32m = wind_speed_32m_clean,
                wind_speed_92m = wind_speed_92m_clean
            )
            
            # Append to combined DataFrame
            if isempty(combined_df)
                combined_df = file_df
            else
                combined_df = vcat(combined_df, file_df)
            end
            
            close(ds)
            
        catch e
            println("Warning: Error processing $filename: $e")
            continue
        end
    end
    
    # Sort by timestamp
    sort!(combined_df, :timestamp)
    
    # Calculate relative time from the first timestamp
    if !isempty(combined_df)
        first_timestamp = combined_df.timestamp[1]
        combined_df.rel_time = [(t - first_timestamp).value / 1000.0 for t in combined_df.timestamp]
    end
    
    # Save to JLD2 file
    output_file = joinpath(folder_path, "10_min_data.jld2")
    jldsave(output_file; data=combined_df)
    
    println("Successfully processed $(length(nc_files)) files")
    println("Combined DataFrame has $(nrow(combined_df)) rows")
    println("Data saved to: $output_file")
    
    return combined_df
end

function plot_all()
    df = JLD2.load(joinpath(path, "10_min_data.jld2"), "data")
    plot(df.rel_time, [df.wind_speed_32m, df.wind_speed_92m], xlabel="Time (s)", ylabel="Wind Speed (m/s)",
        labels=["Wind Speed 32m", "Wind Speed 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
        fig="$(df.timestamp[1])")
end

# Example: Process a single file
path = joinpath(@__DIR__, "..", "data", "WindData", "10min_dataset")
filename="NSO-met-mast-data-10min_2021-08-09-16-40-00_2021-08-10-00-00-00.nc"

ds = Dataset(joinpath(path, filename))
# The dataset contains wind data measured at 32m and 92m height
# You can access the variables in the dataset using ds["variable_name"]
# For example, to access the wind speed at 32m height:
wind_speed_32m = ds["USA3D_32m_S_Spd_8Hz_Calc_Avg"][:]
# And wind speed at 92m height:
wind_speed_92m = ds["USA3D_92m_S_Spd_8Hz_Calc_Avg"][:]
time_stamp = ds["TIMESTAMP"][:]
# Calculate relative time in seconds from the first timestamp
rel_time = [(t - time_stamp[1]).value / 1000.0 for t in time_stamp]
# Convert missing values to NaN and create Vector{Float64}
wind_speed_32m_clean = replace(wind_speed_32m, missing => NaN)
wind_speed_92m_clean = replace(wind_speed_92m, missing => NaN)
# Convert the data to a DataFrame
df = DataFrame(timestamp = time_stamp, rel_time = rel_time, 
               wind_speed_32m = wind_speed_32m_clean, wind_speed_92m = wind_speed_92m_clean)
# Plot both wind speeds using ControlPlots syntax
plot(df.rel_time, [df.wind_speed_32m, df.wind_speed_92m], xlabel="Time (s)", ylabel="Wind Speed (m/s)",
     labels=["Wind Speed 32m", "Wind Speed 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
     fig="$(time_stamp[1])")

# close(ds)


