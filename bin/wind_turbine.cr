require "./../src/homeio_dashboard"

d = HomeioDashboard::Dashboard.new

w = HomeioDashboard::WindTurbineStats.new(d.logger)
w.load_config("config/wind_turbine.yml")

d.add_module(w)

d.prepare
d.start


#w = HomeioDashboard::WindTurbineStats.new
#w.host = "http://lakie.waw.pl:3380"
#w.get_meas
#power = w.get_power
##power = w.get_power(Time.now - Time::Span.new(1, 0, 0), Time.now)
#puts power / (3600.0 * 1000.0)


    sleep 0.5
