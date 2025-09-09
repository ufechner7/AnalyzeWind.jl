using AnalyzeWind, ControlPlots, Statistics
plt = ControlPlots.plt

path = joinpath("data", "WindData", "10min_dataset")

# Coordinates of the meteorological mast
longitude = 7.640317864383007
latitude = 54.40079342584764

# Create a bar plot of data completeness over time
# Get all monthly data (not just filtered by year)
all_monthly_stats = plot_windrose(path; start_month=9, start_year=2021, lat=latitude, long=longitude)

# Create year_month strings for x-axis labels
year_month_labels = [string(row.year) * "-" * lpad(row.month, 2, '0') for row in eachrow(all_monthly_stats)]

# Create the bar plot
fig, ax = plt.subplots(figsize=(14*0.7, 6*0.7))

# Create bar plot
bars = ax.bar(1:length(year_month_labels), all_monthly_stats.percent_valid, 
              color="steelblue", alpha=0.7, edgecolor="navy", linewidth=0.5)

# Customize the plot
ax.set_xlabel("Year-Month", fontsize=12, fontweight="bold")
ax.set_ylabel("Percent Valid (%)", fontsize=12, fontweight="bold")
ax.set_title("Data Completeness by Month", fontsize=14, fontweight="bold")

# Set x-axis labels
ax.set_xticks(1:length(year_month_labels))
ax.set_xticklabels(year_month_labels, rotation=45, ha="right")

# Add horizontal line at 100% for reference
ax.axhline(y=100, color="red", linestyle="--", alpha=0.7, linewidth=1, label="100% Complete")

# Add horizontal line at 98% threshold
ax.axhline(y=98, color="orange", linestyle="--", alpha=0.7, linewidth=1, label="98% Threshold")

# Set y-axis limits
ax.set_ylim(0, 105)

# Add grid for better readability
ax.grid(true, alpha=0.3, axis="y")

# Add legend
ax.legend(loc="lower right")

# Add value labels on bars for months with <98% data
for (i, (bar, percent)) in enumerate(zip(bars, all_monthly_stats.percent_valid))
    if percent < 98
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 1, 
                "$(round(percent, digits=1))%", ha="center", va="bottom", fontsize=9, 
                color="red", fontweight="bold")
    end
end

# Adjust layout to prevent label cutoff
plt.tight_layout()

# Show the plot
plt.show()

# Print summary statistics
println("\nData Completeness Summary:")
println("Average completeness: $(round(mean(all_monthly_stats.percent_valid), digits=1))%")
println("Minimum completeness: $(minimum(all_monthly_stats.percent_valid))%")
println("Maximum completeness: $(maximum(all_monthly_stats.percent_valid))%")
println("Months with <98% data: $(sum(all_monthly_stats.percent_valid .< 98))")
println("Months with 0% data: $(sum(all_monthly_stats.percent_valid .== 0.0))")