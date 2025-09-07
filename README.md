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
plot_all()
plot_direction()
plot_combined()
```

