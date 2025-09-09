using AnalyzeWind

path = joinpath("data", "WindData", "10min_dataset")
plot_windrose(path; year=2022)