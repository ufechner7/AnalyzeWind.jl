# import the files Turbine_placement_AWG.csv and Turbine_placement_NSO.csv
# and convert them from lat/lon to x and y positions in meters
# the reference point is the position of the turbine most to the southwest
# (i.e. the one with the smallest x and y coordinates)
# and save the output as DataFrames
using Proj
using CSV
using DataFrames

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

# println("\n=== Turbine Placement Data ===")
# println("AWG Turbine Placement:")
# println(df_AWG)
# println("\nNSO Turbine Placement:")
# println(df_NSO) 