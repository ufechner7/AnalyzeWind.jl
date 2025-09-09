module AnalyzeWind

using DataFrames
using NCDatasets
using ControlPlots
using Dates
using JLD2
using Statistics

export process_all_nc_files
export print_variables, describe_variable
export plot_all, plot_direction, plot_combined, plot_windrose

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

# Function to print all variables in a NetCDF dataset
function print_variables(ds; filter="")
    for key in keys(ds)
        if filter == "" || occursin(filter, key)
            println(key)
        end
    end
end

# Function to print metadata of a specific variable
function describe_variable(ds, variable_name)
    if haskey(ds, variable_name)
        var = ds[variable_name]
        println("Variable: $variable_name")
        println("Dimensions: $(dimnames(var))")
        println("Shape: $(size(var))")
        println("Data type: $(eltype(var))")
        
        # Print attributes
        attrs = var.attrib
        if length(attrs) > 0
            println("Attributes:")
            for (key, value) in attrs
                println("  $key: $value")
            end
        else
            println("No attributes")
        end
    else
        println("Variable '$variable_name' not found in dataset")
    end
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

"""
    plot_windrose(path::String; height=92, nbins=16, speed_bins=[0, 3, 6, 10, 15, 20], start_year=nothing, start_month=nothing, lat=nothing, long=nothing)

Create a wind rose plot showing wind direction frequency and speed distribution.

# Arguments
- `path`: Path to the folder containing "10_min_data.jld2"
- `height`: Height level to plot (32 or 92), default is 92m
- `nbins`: Number of direction bins (default 16, i.e., 22.5° sectors)
- `speed_bins`: Wind speed bins for color coding (default [0,3,6,10,15,20] m/s)
- `start_year`: Starting year for 12-month period, or nothing for all data
- `start_month`: Starting month (1-12), defaults to 1 (January) if start_year is specified
- `lat`: Latitude in degrees (will be displayed in lower left corner if provided)
- `long`: Longitude in degrees (will be displayed in lower left corner if provided)
"""
function plot_windrose(path::String; height=92, nbins=16, speed_bins=[0, 3, 6, 10, 15, 20], start_year=nothing, start_month=nothing, lat=nothing, long=nothing)
    # Access matplotlib/PyPlot API
    plt = ControlPlots.plt
    
    # Load data
    df = JLD2.load(joinpath(path, "10_min_data.jld2"), "data")
    
    # Filter by start_year and start_month if specified
    if start_year !== nothing
        # Set default start_month to 1 (January) if not specified
        if start_month === nothing
            start_month = 1
        end
        
        # Calculate end year and month (12 months from start)
        end_year = start_year
        end_month = start_month + 11
        
        # Handle year wraparound if needed
        if end_month > 12
            end_year += 1
            end_month -= 12
        end
        
        # Create date range filter
        start_date = Date(start_year, start_month, 1)
        end_date = Date(end_year, end_month, Dates.daysinmonth(end_year, end_month))
        
        # Filter data within the 12-month period
        date_mask = (Date.(df.timestamp) .>= start_date) .& (Date.(df.timestamp) .<= end_date)
        df = df[date_mask, :]
        
        println("Filtered data from $start_date to $end_date: $(nrow(df)) records")
        
        if nrow(df) == 0
            error("No data found for the period starting $start_year-$(lpad(start_month, 2, '0'))")
        end
    end
    
    # Select the appropriate columns based on height
    if height == 32
        wind_dir = df.wind_direction_32m
        wind_speed = df.wind_speed_32m
        title_height = "32m"
    elseif height == 92
        wind_dir = df.wind_direction_92m
        wind_speed = df.wind_speed_92m
        title_height = "92m"
    else
        error("Height must be either 32 or 92")
    end
    
    # Remove NaN values
    valid_indices = .!(isnan.(wind_dir) .| isnan.(wind_speed))
    wind_dir_clean = wind_dir[valid_indices]
    wind_speed_clean = wind_speed[valid_indices]
    
    if isempty(wind_dir_clean)
        error("No valid wind data found")
    end
    
    # Create direction bins (degrees)
    dir_bin_size = 360.0 / nbins
    dir_bins = 0:dir_bin_size:(360-dir_bin_size)
    dir_centers = collect(dir_bins .+ dir_bin_size/2)
    
    # Convert direction centers to radians (matplotlib uses radians for polar plots)
    # Do not adjust for meteorological convention (0° = North, clockwise)
    # theta = (90.0 .- dir_centers) .* π ./ 180.0  # Convert to mathematical convention
    theta = deg2rad.(dir_centers)  
    
    # Create speed bin labels
    speed_labels = String[]
    colors = ["#3498db", "#2ecc71", "#f1c40f", "#e67e22", "#e74c3c", "#9b59b6"]  # Blue to red gradient
    
    for i in 1:(length(speed_bins)-1)
        push!(speed_labels, "$(speed_bins[i])-$(speed_bins[i+1]) m/s")
    end
    push!(speed_labels, ">$(speed_bins[end]) m/s")
    
    # Initialize frequency matrix: [direction_bin, speed_bin]
    freq_matrix = zeros(nbins, length(speed_labels))
    
    # Bin the data
    for (dir_val, speed_val) in zip(wind_dir_clean, wind_speed_clean)
        # Find direction bin (handle 360° wrap-around)
        dir_bin_idx = Int(floor(mod(dir_val, 360) / dir_bin_size)) + 1
        if dir_bin_idx > nbins
            dir_bin_idx = 1
        end
        
        # Find speed bin
        speed_bin_idx = length(speed_bins)  # default to highest bin
        for i in 1:(length(speed_bins)-1)
            if speed_val < speed_bins[i+1]
                speed_bin_idx = i
                break
            end
        end
        
        freq_matrix[dir_bin_idx, speed_bin_idx] += 1
    end
    
    # Convert to percentages
    total_count = sum(freq_matrix)
    freq_matrix_pct = freq_matrix ./ total_count * 100
    
    # Create polar plot
    fig = plt.figure(figsize=(10, 10))
    ax = fig.add_subplot(111, projection="polar")
    
    # Plot stacked bars for each speed bin
    bottom = zeros(nbins)
    bar_width = dir_bin_size * π / 180  # Convert to radians
    
    for speed_idx in 1:length(speed_labels)
        # Get color for this speed bin
        color = speed_idx <= length(colors) ? colors[speed_idx] : colors[end]
        
        # Plot bars
        bars = ax.bar(theta, freq_matrix_pct[:, speed_idx], 
                     width=bar_width, 
                     bottom=bottom,
                     label=speed_labels[speed_idx],
                     color=color,
                     alpha=0.8,
                     edgecolor="white",
                     linewidth=0.5)
        
        # Update bottom for stacking
        bottom .+= freq_matrix_pct[:, speed_idx]
    end
    
    # Customize the plot
    ax.set_theta_zero_location("N")  # North at top
    ax.set_theta_direction(-1)       # Clockwise
    
    # Create title with period information if filtered
    if start_year !== nothing
        if start_month === nothing
            start_month = 1
        end
        end_year = start_year
        end_month = start_month + 11
        if end_month > 12
            end_year += 1
            end_month -= 12
        end
        period_text = "$(start_year)-$(lpad(start_month, 2, '0')) to $(end_year)-$(lpad(end_month, 2, '0'))"
        ax.set_title("Wind Rose - $(title_height) Height ($period_text)", fontsize=14, fontweight="bold", pad=10)
    else
        start_date = Dates.format(Date(df.timestamp[1]), "yyyy-mm-dd")
        end_date = Dates.format(Date(df.timestamp[end]), "yyyy-mm-dd")
        # Main title
        ax.set_title("Wind Rose - $(title_height) Height", fontsize=14, fontweight="bold", pad=20)
        # Subtitle with smaller font
        ax.text(0.5, 1.04, "$start_date - $end_date", transform=ax.transAxes, 
                ha="center", va="bottom", fontsize=10)
    end
    
    # Set radial labels
    ax.set_ylabel("Frequency (%)", labelpad=40)
    ax.grid(true, alpha=0.3)
    
    # Add legend
    ax.legend(loc="upper left", bbox_to_anchor=(1.0, 1.0))
    
    # Set angular labels (directions)
    ax.set_thetagrids(collect(0:45:315), ["N", "NE", "E", "SE", "S", "SW", "W", "NW"])
    
    # Add coordinates in lower right corner if provided
    if lat !== nothing && long !== nothing
        coord_text = "Latitude:  $(lat)°\nLongitude: $(long)°"
        ax.text(0.90, 0.02, coord_text, transform=ax.transAxes, 
                fontsize=10, ha="left", va="bottom")
    elseif lat !== nothing
        coord_text = "Latitude:  $(lat)°"
        ax.text(0.90, 0.02, coord_text, transform=ax.transAxes, 
                fontsize=10, ha="left", va="bottom")
    elseif long !== nothing
        coord_text = "Longitude: $(long)°"
        ax.text(0.90, 0.02, coord_text, transform=ax.transAxes, 
                fontsize=10, ha="left", va="bottom")
    end
    
    # Adjust layout to reduce whitespace and prevent legend cutoff
    plt.subplots_adjust(top=1.0, bottom=0.0, left=0.08, right=0.85)
    plt.tight_layout()
    
    # Show plot
    plt.show()
    
    # Print statistics
    if start_year !== nothing
        if start_month === nothing
            start_month = 1
        end
        end_year = start_year
        end_month = start_month + 11
        if end_month > 12
            end_year += 1
            end_month -= 12
        end
        period_text = " ($(start_year)-$(lpad(start_month, 2, '0')) to $(end_year)-$(lpad(end_month, 2, '0')))"
    else
        period_text = ""
    end
    println("Wind Rose Statistics for $(title_height) height$period_text:")
    println("Total valid measurements: $(length(wind_dir_clean))")
    
    # Find first and last valid sample timestamps
    valid_timestamps = df.timestamp[valid_indices]
    first_valid = valid_timestamps[1]
    last_valid = valid_timestamps[end]
    println("First valid sample: $first_valid")
    println("Last valid sample: $last_valid")
    
    # Find most frequent direction
    max_freq_idx = argmax(sum(freq_matrix, dims=2))[1]
    most_freq_dir = dir_centers[max_freq_idx]
    println("Most frequent direction: $(round(most_freq_dir, digits=1))°")
    println("Average wind speed: $(round(mean(wind_speed_clean), digits=2)) m/s")
    
    # Print frequency by direction sector
    println("\nFrequency by direction sector:")
    for (i, dir_center) in enumerate(dir_centers)
        total_freq = sum(freq_matrix[i, :])
        if total_freq > 0
            println("$(round(dir_center, digits=1))°: $(round(total_freq/total_count*100, digits=1))%")
        end
    end
    
    # Create monthly statistics DataFrame
    monthly_stats = DataFrame(
        month = Int[],
        year = Int[],
        valid_samples = Int[],
        max_samples = Int[],
        percent_valid = Float64[]
    )
    
    # Group data by year and month
    for timestamp in df.timestamp
        year_val = Dates.year(timestamp)
        month_val = Dates.month(timestamp)
        
        # Check if we already have an entry for this month/year
        existing_row = findfirst((monthly_stats.year .== year_val) .& (monthly_stats.month .== month_val))
        
        if existing_row === nothing
            # Calculate max possible samples for this month (10-minute intervals)
            # Days in month * 24 hours * 6 (10-minute intervals per hour)
            days_in_month = Dates.daysinmonth(Date(year_val, month_val, 1))
            max_samples = days_in_month * 24 * 6
            
            # Count valid samples for this month/year
            month_mask = (Dates.year.(df.timestamp) .== year_val) .& (Dates.month.(df.timestamp) .== month_val)
            month_data = df[month_mask, :]
            
            # Count valid samples (non-NaN) for the selected height
            if height == 32
                valid_count = sum(.!isnan.(month_data.wind_direction_32m) .& .!isnan.(month_data.wind_speed_32m))
            else
                valid_count = sum(.!isnan.(month_data.wind_direction_92m) .& .!isnan.(month_data.wind_speed_92m))
            end
            
            # Calculate percentage of valid samples
            percent_valid = max_samples > 0 ? (valid_count / max_samples * 100.0) : 0.0
            
            push!(monthly_stats, (
                month = month_val,
                year = year_val,
                valid_samples = valid_count,
                max_samples = max_samples,
                percent_valid = round(percent_valid, digits=1)
            ))
        end
    end
    
    # Sort by year and month
    sort!(monthly_stats, [:year, :month])
    
    println("\nMonthly sample statistics:")
    println(monthly_stats)
    
    return monthly_stats
end

end
