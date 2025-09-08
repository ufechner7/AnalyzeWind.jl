# import the files Turbine_placement_AWG.csv and Turbine_placement_NSO.csv
# and convert them from lat/lon to x and y positions in meters
# the reference point is the position of the turbine most to the southwest
# (i.e. the one with the smallest x and y coordinates)
# and save the output as DataFrames
using Proj
using CSV
using DataFrames
using ControlPlots
using YAML

# Read CSV files from the data folder
data_path = joinpath(@__DIR__, "..", "data")
df_AWG = CSV.read(joinpath(data_path, "Turbine_placement_AWG.csv"), DataFrame)
df_NSO = CSV.read(joinpath(data_path, "Turbine_placement_NSO.csv"), DataFrame)

# Convert lat/lon to UTM coordinates
function latlon_to_utm(df)
    # UTM Zone 32 transformation (appropriate for this region)
    transformer = Proj.Transformation("+proj=longlat +datum=WGS84", "+proj=utm +zone=32 +datum=WGS84")
    
    # Convert each lat/lon pair to UTM
    utm_coords = [transformer(lon, lat) for (lat, lon) in zip(df.latitude, df.longitude)]
    
    # Extract x and y coordinates
    df.x = [coord[1] for coord in utm_coords]  # Easting
    df.y = [coord[2] for coord in utm_coords]  # Northing
    
    return df
end

# Convert positions to meters relative to reference point
function convert_to_relative_meters(df)
    # Find the reference point (southwest corner)
    ref_x = minimum(df.x)
    ref_y = minimum(df.y)
    
    # Convert to relative positions in meters
    df.rel_x = df.x .- ref_x
    df.rel_y = df.y .- ref_y
    
    return df
end

# Process both datasets
df_AWG = latlon_to_utm(df_AWG)
df_AWG = convert_to_relative_meters(df_AWG)

df_NSO = latlon_to_utm(df_NSO)
df_NSO = convert_to_relative_meters(df_NSO)

# Create combined dataframe with all turbine positions
function create_combined_dataframe(df_AWG, df_NSO)
    # Add wind farm identifier column to each dataframe
    df_AWG_copy = copy(df_AWG)
    df_NSO_copy = copy(df_NSO)
    
    df_AWG_copy.wind_farm = fill("AWG", nrow(df_AWG_copy))
    df_NSO_copy.wind_farm = fill("NSO", nrow(df_NSO_copy))
    
    # Combine the dataframes
    df_combined = vcat(df_AWG_copy, df_NSO_copy)
    
    # Find the global minimum coordinates across all turbines
    global_min_lat = minimum([minimum(df_AWG.latitude), minimum(df_NSO.latitude)])
    global_min_lon = minimum([minimum(df_AWG.longitude), minimum(df_NSO.longitude)])
    
    println("=== Global Reference Point ===")
    println("Global minimum latitude:  $(round(global_min_lat, digits=6))")
    println("Global minimum longitude: $(round(global_min_lon, digits=6))")
    
    # Convert global reference point to UTM
    transformer = Proj.Transformation("+proj=longlat +datum=WGS84", "+proj=utm +zone=32 +datum=WGS84")
    global_ref_utm = transformer(global_min_lon, global_min_lat)
    ref_x_global = global_ref_utm[1]
    ref_y_global = global_ref_utm[2]
    
    # Calculate relative positions using the global reference
    df_combined.rel_x = df_combined.x .- ref_x_global
    df_combined.rel_y = df_combined.y .- ref_y_global
    
    return df_combined
end

# Create the combined dataframe
df_combined = create_combined_dataframe(df_AWG, df_NSO)

# Print min/max coordinates for each wind farm
println("\n=== Wind Farm Coordinate Ranges ===")
println("\nAWG Wind Farm:")
println("  Latitude range:  $(round(minimum(df_AWG.latitude), digits=6)) to $(round(maximum(df_AWG.latitude), digits=6))")
println("  Longitude range: $(round(minimum(df_AWG.longitude), digits=6)) to $(round(maximum(df_AWG.longitude), digits=6))")

println("\nNSO Wind Farm:")
println("  Latitude range:  $(round(minimum(df_NSO.latitude), digits=6)) to $(round(maximum(df_NSO.latitude), digits=6))")
println("  Longitude range: $(round(minimum(df_NSO.longitude), digits=6)) to $(round(maximum(df_NSO.longitude), digits=6))")

println("\nCombined Dataset:")
println("  Total turbines: $(nrow(df_combined))")
println("  Relative X range: $(round(minimum(df_combined.rel_x), digits=1)) to $(round(maximum(df_combined.rel_x), digits=1)) meters")
println("  Relative Y range: $(round(minimum(df_combined.rel_y), digits=1)) to $(round(maximum(df_combined.rel_y), digits=1)) meters")

# Create plot of turbine positions using relative coordinates
plt = ControlPlots.plt

# Create figure with subplots: individual wind farms + combined view
fig, (ax1, ax2, ax3) = plt.subplots(1, 3, figsize=(18, 6))

# Plot AWG wind farm
ax1.scatter(df_AWG.rel_x, df_AWG.rel_y, marker="+", s=100, c="red", linewidths=2, label="AWG Turbines")
ax1.set_xlabel("Relative X (m)")
ax1.set_ylabel("Relative Y (m)")
ax1.set_title("AWG Wind Farm - Turbine Positions")
ax1.grid(true, alpha=0.3)
ax1.axis("equal")
ax1.set_xlim(minimum(df_AWG.rel_x)-400, maximum(df_AWG.rel_x)+1000)
println("X limits for AWG plot: ", ax1.get_xlim())

# Add turbine names as annotations
for i in 1:nrow(df_AWG)
    ax1.annotate(df_AWG.name[i], (df_AWG.rel_x[i], df_AWG.rel_y[i]), 
                xytext=(5, 5), textcoords="offset points", fontsize=8)
end

# Plot NSO wind farm
ax2.scatter(df_NSO.rel_x, df_NSO.rel_y, marker="+", s=100, c="blue", linewidths=2, label="NSO Turbines")
ax2.set_xlabel("Relative X (m)")
ax2.set_ylabel("Relative Y (m)")
ax2.set_title("NSO Wind Farm - Turbine Positions")
ax2.axis("equal")
ax2.set_xlim(minimum(df_NSO.rel_x)-400, maximum(df_NSO.rel_x)+1000)
ax2.grid(true, alpha=0.3)
# Add turbine names as annotations
for i in 1:nrow(df_NSO)
    ax2.annotate(df_NSO.name[i], (df_NSO.rel_x[i], df_NSO.rel_y[i]), 
                xytext=(5, 5), textcoords="offset points", fontsize=8)
end

# Plot combined wind farms using the global reference
awg_mask = df_combined.wind_farm .== "AWG"
nso_mask = df_combined.wind_farm .== "NSO"

ax3.scatter(df_combined.rel_x[awg_mask], df_combined.rel_y[awg_mask], 
           marker="+", s=100, c="red", linewidths=2, label="AWG Turbines")
ax3.scatter(df_combined.rel_x[nso_mask], df_combined.rel_y[nso_mask], 
           marker="x", s=100, c="blue", linewidths=2, label="NSO Turbines")
ax3.set_xlabel("Relative X (m)")
ax3.set_ylabel("Relative Y (m)")
ax3.set_title("Combined Wind Farms - All Turbine Positions")
ax3.grid(true, alpha=0.3)
ax3.axis("equal")
ax3.legend()

# Add turbine names as annotations for combined plot
for i in 1:nrow(df_combined)
    color = df_combined.wind_farm[i] == "AWG" ? "red" : "blue"
    ax3.annotate(df_combined.name[i], (df_combined.rel_x[i], df_combined.rel_y[i]), 
                xytext=(5, 5), textcoords="offset points", fontsize=7, color=color)
end

plt.tight_layout()
plt.show()

# Function to create YAML file based on dataframe and template
function create_yaml_file(df, output_filename, template_path)
    """
    Create a YAML file for wind farm configuration based on turbine position dataframe.
    Uses the template structure from template.yaml and fills in actual turbine positions.
    
    Parameters:
    - df: DataFrame with turbine positions (must have rel_x, rel_y columns)
    - output_filename: Path where to save the YAML file
    - template_path: Path to the template YAML file for structure reference
    """
    # Read the template to understand the structure
    template = YAML.load_file(template_path)
    
    # Create turbines array based on dataframe
    turbines = []
    
    for (i, row) in enumerate(eachrow(df))
        # Extract turbine ID from name (remove prefix if present)
        turbine_id = i  # Use row index as ID, or could parse from name
        
        # Create turbine entry following template structure
        turbine = Dict(
            "id" => turbine_id,
            "type" => "SWT-3.6-120",  # Default turbine type from template
            "x" => round(Int, row.rel_x),  # Convert to integer meters
            "y" => round(Int, row.rel_y),  # Convert to integer meters
            "z" => 0,                      # Ground level
            "a" => 0.33,                   # Default from template (axial induction factor)
            "yaw" => 0,                    # Default yaw angle
            "ti" => 0.06                   # Default turbulence intensity
        )
        
        push!(turbines, turbine)
    end
    
    # Create the final YAML structure
    yaml_data = Dict("turbines" => turbines)
    
    # Write to YAML file
    YAML.write_file(output_filename, yaml_data)
    
    println("Created YAML file: $output_filename with $(length(turbines)) turbines")
    return yaml_data
end

# Create awg.yaml file based on df_AWG data
template_path = joinpath(@__DIR__, "..", "docs", "template.yaml")
output_path = joinpath(@__DIR__, "..", "out", "awg.yaml")

if isfile(template_path)
    create_yaml_file(df_AWG, output_path, template_path)
    println("AWG YAML file created successfully at: $output_path")
else
    println("Warning: Template file not found at $template_path")
end

# # Display the combined dataframe
# println("\n=== Combined Turbine Dataset ===")
# println("Columns: $(names(df_combined))")
# println("\nFirst few rows of combined dataset:")
# println(first(df_combined, 5))

# println("\nSample from each wind farm:")
# awg_sample = df_combined[df_combined.wind_farm .== "AWG", :]
# nso_sample = df_combined[df_combined.wind_farm .== "NSO", :]
# println("AWG turbines (first 3):")
# println(first(awg_sample, 3))
# println("NSO turbines (first 3):")
# println(first(nso_sample, 3))
