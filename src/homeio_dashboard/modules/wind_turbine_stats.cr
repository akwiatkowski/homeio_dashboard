require "http"
require "json"
require "yaml"

class HomeioDashboard::WindTurbineStats < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "WindTurbine"
    @enabled = false

    @host = "http://localhost:8080"
    @meas_path = "/api/meas.json"

    @voltage_meas_name = "batt_u"
    @current_meas_name = "i_gen_batt"

    @voltage_meas_coeff_linear = 1.0 as Float64
    @voltage_meas_coeff_offset = 0 as Int32

    @current_meas_coeff_linear = 1.0 as Float64
    @current_meas_coeff_offset = 0 as Int32

    @interval = 1 # in miliseconds

    @initial_count = 2 # how many initial hours calculate

    @powers = [] of Tuple(Time, Float64)

    @updated_at = Time.now
  end

  getter :name

  def load_config(path)
    s = File.read(path)
    data = YAML.load(s) as Hash(YAML::Type, YAML::Type)
    @host = data["host"].to_s if data.has_key?("host")

    @initial_count = data["initial_count"].to_s.to_i if data.has_key?("initial_count")
    @enabled = data["enabled"].to_s == "true" if data.has_key?("enabled")
  end

  property :host


  def prepare
    return unless @enabled

    get_meas
    @logger.info("#{@name} prepared, got meas")
    populate_initial_energies
    @logger.info("#{@name} populated initials")
  end

  def make_it_so
    return unless @enabled

    return populate_energy_for_hour_ago(1)
  end

  def populate_initial_energies
    (1..@initial_count).reverse_each do |i|
      populate_energy_for_hour_ago(i)
    end
  end

  def populate_energy_for_hour_ago(i)
    populate_energy_for_hour( Time.now.at_beginning_of_hour - Time::Span.new(i, 0, 0) )
  end

  def populate_energy_for_hour(t)
    return false if @powers.size > 0 && @powers.last[0] == t

    @logger.info("#{@name} getting power for #{t}")
    power = get_power(t, t + Time::Span.new(1, 0, 0) )
    power /= 3600.0
    @logger.info("#{@name} got #{power} Wh")

    @powers << {t, power}

    @powers = @powers.select{|p| (Time.now - p[0] as Time) <= Time::Span.new(48, 0, 0) }
  end

  def payload
    {"powers" => @powers}
  end

  def get_meas
    s = HTTP::Client.get(@host + @meas_path)
    data = JSON.parse(s.body) as Hash(String, JSON::Type)
    array = data["array"] as Array(JSON::Type)

    array.each do |m|
      meas = m as Hash(String, JSON::Type)
      if meas["name"] == @voltage_meas_name
        @voltage_meas_coeff_linear = meas["coefficientLinear"].to_s.to_f
        @voltage_meas_coeff_offset = meas["coefficientOffset"].to_s.to_i
      end

      if meas["name"] == @current_meas_name
        @current_meas_coeff_linear = meas["coefficientLinear"].to_s.to_f
        @current_meas_coeff_offset = meas["coefficientOffset"].to_s.to_i
      end
    end

  end

  def get_power(time_from = Time.now.at_beginning_of_day, time_to = Time.now.at_end_of_day)
    url = url_for_meas_raws(@voltage_meas_name, time_from, time_to)
    s = HTTP::Client.get(url)
    data = JSON.parse(s.body) as Hash(String, JSON::Type)
    array_u = data["data"] as Array(JSON::Type)

    @interval = data["interval"].to_s.to_i

    @logger.debug("#{@name} got voltages count #{array_u.size}")

    url = url_for_meas_raws(@current_meas_name, time_from, time_to)
    s = HTTP::Client.get(url)
    data = JSON.parse(s.body) as Hash(String, JSON::Type)
    array_i = data["data"] as Array(JSON::Type)

    @logger.debug("#{@name} got currents count #{array_i.size}")

    i = 0
    power = 0.0
    while i < array_u.size && i < array_i.size
      voltage = (array_u[i].to_s.to_i + @voltage_meas_coeff_offset) * @voltage_meas_coeff_linear
      current = (array_i[i].to_s.to_i + @current_meas_coeff_offset) * @current_meas_coeff_linear

      quant = voltage * current *  @interval * 0.001
      power += quant if quant > 0.0

      i += 1
    end

    @logger.debug("#{@name} power calculated #{power} Ws")

    return power # in Ws, you need to divide 1000 * 3600 if you want kWh
  end

  def url_for_meas_raws(meas_name, time_from, time_to)
    "#{@host}/api/meas/#{meas_name}/raw_for_time/#{(time_from.epoch_f * 1000.0).to_i64}/#{(time_to.epoch_f * 1000.0).to_i64}/.json"
  end

  def content
    s = ""

    @powers.reverse.each do |p|
      s += "#{p[0]} - #{p[1]} Wh"
      s += "\n"
    end

    return s
  end

end
