# import the files Turbine_placement_AWG.csv and Turbine_placement_NSO.csv
# and convert them from lat/lon to x and y positions in meters
# the reference point is the position of the turbine most to the southwest
# (i.e. the one with the smallest x and y coordinates)
# and save the output as DataFrames
using Proj
using CSV
using DataFrames
using ControlPlots

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

# Print min/max coordinates for each wind farm
println("=== Wind Farm Coordinate Ranges ===")
println("\nAWG Wind Farm:")
println("  Latitude range:  $(round(minimum(df_AWG.latitude), digits=6)) to $(round(maximum(df_AWG.latitude), digits=6))")
println("  Longitude range: $(round(minimum(df_AWG.longitude), digits=6)) to $(round(maximum(df_AWG.longitude), digits=6))")

println("\nNSO Wind Farm:")
println("  Latitude range:  $(round(minimum(df_NSO.latitude), digits=6)) to $(round(maximum(df_NSO.latitude), digits=6))")
println("  Longitude range: $(round(minimum(df_NSO.longitude), digits=6)) to $(round(maximum(df_NSO.longitude), digits=6))")

# Create plot of turbine positions using relative coordinates
plt = ControlPlots.plt

# Create figure with subplots for both wind farms
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

# Plot AWG wind farm
ax1.scatter(df_AWG.rel_x, df_AWG.rel_y, marker="+", s=100, c="red", linewidths=2, label="AWG Turbines")
ax1.set_xlabel("Relative X (m)")
ax1.set_ylabel("Relative Y (m)")
ax1.set_title("AWG Wind Farm - Turbine Positions")
ax1.grid(true, alpha=0.3)
ax1.axis("equal")
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
ax2.grid(true, alpha=0.3)
ax2.axis("equal")
# Add turbine names as annotations
for i in 1:nrow(df_NSO)
    ax2.annotate(df_NSO.name[i], (df_NSO.rel_x[i], df_NSO.rel_y[i]), 
                xytext=(5, 5), textcoords="offset points", fontsize=8)
end

plt.tight_layout()
plt.show()

# # println("\n=== Turbine Placement Data ===")
# # println("AWG Turbine Placement:")
# # println(df_AWG)
# # println("\nNSO Turbine Placement:")
# # println(df_NSO)  