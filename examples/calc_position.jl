using NCDatasets, Proj

# Example: Process a single file
path = joinpath(@__DIR__, "..", "data", "WindData", "10min_dataset")
filename="NSO-met-mast-data-10min_2021-08-09-16-40-00_2021-08-10-00-00-00.nc"

ds = Dataset(joinpath(path, filename))

pos_string = ds.attrib["Position_UTM"]
println("Position string: $pos_string")

# Parse the position string to extract coordinates and zone
# Expected format: "411734.4371 m E, 6028967.271 m N, UTM WGS84 Zone32"
function parse_utm_position(pos_str::String)
    # Split by commas and clean up whitespace
    parts = strip.(split(pos_str, ','))
    
    # Extract easting (first part)
    easting_part = parts[1]
    easting_match = match(r"([\d.]+)\s*m\s*E", easting_part)
    easting = easting_match !== nothing ? parse(Float64, easting_match.captures[1]) : error("Could not parse easting from: $easting_part")
    
    # Extract northing (second part)
    northing_part = parts[2]
    northing_match = match(r"([\d.]+)\s*m\s*N", northing_part)
    northing = northing_match !== nothing ? parse(Float64, northing_match.captures[1]) : error("Could not parse northing from: $northing_part")
    
    # Extract zone and datum (third part)
    zone_part = parts[3]
    zone_match = match(r"UTM\s+(\w+)\s+Zone(\d+)", zone_part)
    if zone_match !== nothing
        datum = zone_match.captures[1]
        zone = parse(Int, zone_match.captures[2])
    else
        error("Could not parse zone and datum from: $zone_part")
    end
    
    return easting, northing, zone, datum
end

# Parse the position string
easting, northing, zone, datum = parse_utm_position(pos_string)
println("Parsed coordinates:")
println("  Easting: $easting m")
println("  Northing: $northing m") 
println("  Zone: $zone")
println("  Datum: $datum")

# Create projection string based on parsed values
proj_string = "+proj=utm +zone=$zone +datum=$datum"
println("Projection string: $proj_string")

# Create transformer and convert coordinates
transformer = Proj.Transformation(proj_string, "+proj=longlat +datum=$datum")
lon, lat = transformer(easting, northing)

println("Converted coordinates:")
println("  Longitude: $(lon)°")
println("  Latitude: $(lat)°")
println("Google Maps URL: https://www.google.com/maps/@$(lat),$(lon),15z")

# Close the dataset
close(ds)