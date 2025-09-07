module AnalyzeWind

using DataFrames
using NCDatasets
using ControlPlots
using Dates
using JLD2

export process_all_nc_files
export plot_all, plot_direction, plot_combined

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
            wind_direction_32m = ds["USA3D_32m_S_Dir_8Hz_Calc_Avg"][:]
            wind_direction_92m = ds["USA3D_92m_S_Dir_8Hz_Calc_Avg"][:]
            time_stamp = ds["TIMESTAMP"][:]
            
            # Clean missing values
            wind_speed_32m_clean = replace(wind_speed_32m, missing => NaN)
            wind_speed_92m_clean = replace(wind_speed_92m, missing => NaN)
            wind_direction_32m_clean = replace(wind_direction_32m, missing => NaN)
            wind_direction_92m_clean = replace(wind_direction_92m, missing => NaN)
            
            # Create DataFrame for this file
            file_df = DataFrame(
                timestamp = time_stamp,
                wind_speed_32m = wind_speed_32m_clean,
                wind_speed_92m = wind_speed_92m_clean,
                wind_direction_32m = wind_direction_32m_clean,
                wind_direction_92m = wind_direction_92m_clean
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

function plot_all(path)
    df = JLD2.load(joinpath(path, "10_min_data.jld2"), "data")
    plot(df.rel_time, [df.wind_speed_32m, df.wind_speed_92m], xlabel="Time (s)", ylabel="Wind Speed (m/s)",
        labels=["Wind Speed 32m", "Wind Speed 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
        fig="$(df.timestamp[1])")
end

function plot_direction(path)
    df = JLD2.load(joinpath(path, "10_min_data.jld2"), "data")
    plot(df.rel_time, [df.wind_direction_32m, df.wind_direction_92m], xlabel="Time (s)", ylabel="Wind Direction (°)",
        labels=["Wind Direction 32m", "Wind Direction 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
        fig="Wind_Direction_$(df.timestamp[1])")
end

function plot_combined(path)
    df = JLD2.load(joinpath(path, "10_min_data.jld2"), "data")
    # Create separate plots for speed and direction
    p=plot(df.rel_time, [df.wind_speed_32m, df.wind_speed_92m], xlabel="Time (s)", ylabel="Wind Speed (m/s)",
        labels=["Wind Speed 32m", "Wind Speed 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
        fig="Wind_Speed_$(df.timestamp[1])")
    display(p)
    p=plot(df.rel_time, [df.wind_direction_32m, df.wind_direction_92m], xlabel="Time (s)", ylabel="Wind Direction (°)",
        labels=["Wind Direction 32m", "Wind Direction 92m"], xlims=(minimum(df.rel_time), maximum(df.rel_time)), 
        fig="Wind_Direction_$(df.timestamp[1])")
    display(p)
end

end
