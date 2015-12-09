require "./../src/homeio_dashboard"

d = HomeioDashboard::Dashboard.new

w = HomeioDashboard::BackJobSample.new(d.logger)
d.add_module(w)

w = HomeioDashboard::DiskUsage.new(d.logger)
d.add_module(w)

w = HomeioDashboard::WindTurbineStats.new(d.logger)
w.load_config("config/wind_turbine.yml")
d.add_module(w)

d.start
