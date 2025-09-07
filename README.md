# AnalyzeWind

[![Build Status](https://github.com/ufechner7/AnalyzeWind.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ufechner7/AnalyzeWind.jl/actions/workflows/CI.yml?query=branch%3Amain)

Software to analyze two types of wind data:
- from measurement masts
- SCADA data from wind turbines

See also: https://github.com/JuliaGeo/NCDatasets.jl

# Examples
```
include("examples/import.jl")
```
This will convert and plot the first file in the `data/WindData/10min_dataset` folder.

To convert all `.nc` files, call:
```
process_all_nc_files(path)
```
This will convert the files into a dataframe, which is stored as `.jld2` file in the same folder.

For plotting, you can use any of the functions:

```julia
plot_all(path)
plot_direction(path)
plot_combined(path)
```
where path is the file path with the jld2 file.

## Creating a wind rose
```julia
using AnalyzeWind

path = joinpath("data", "WindData", "10min_dataset")

# Wind rose for 92m height (default)
plot_windrose(path)

# Wind rose for 32m height
plot_windrose(path; height=32)

# Wind rose for specific year only
plot_windrose(path; year=2021)

# Custom wind rose with more direction bins and different speed bins
plot_windrose(path; height=92, nbins=24, speed_bins=[0, 2, 4, 6, 8, 12, 16])

# Combined: specific year with custom parameters
plot_windrose(path; height=92, year=2021, nbins=24, speed_bins=[0, 2, 4, 6, 8, 12, 16])
```

**Note**: The wind rose follows meteorological convention where 0° represents North, and angles increase clockwise (North=0°, East=90°, South=180°, West=270°).

