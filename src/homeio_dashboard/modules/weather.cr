require "json"
require "yaml"

class HomeioDashboard::Weather < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "Weather"
    @enabled = false

    @payload_path = ""
    @payload_metar_path = ""

    @lat = 0.0
    @lon = 0.0
    @max_distance = 20_000_000.0 # in meters

    # city, country, distance, time, temperature, wind
    @weathers = [] of Tuple(String, String, Float64, Time, Float64, Float64)
    @weathers_temp = [] of Tuple(String, String, Float64, Time, Float64, Float64)

    @updated_at = Time.now

    @cursor = 0
    @per_page = 20
    @pages = 0
  end

  getter :name

  def load_config(path)
    s = File.read(path)
    data = YAML.load(s) as Hash(YAML::Type, YAML::Type)
    @enabled = data["enabled"].to_s == "true" if data.has_key?("enabled")

    @payload_path = data["payload_path"].to_s if data.has_key?("payload_path")
    @payload_metar_path = data["payload_metar_path"].to_s if data.has_key?("payload_metar_path")

    @lat = data["lat"].to_s.to_f if data.has_key?("lat")
    @lon = data["lon"].to_s.to_f if data.has_key?("lon")
  end

  property :host

  def prepare
    return unless @enabled
    get_weather
  end

  def make_it_so
    return unless @enabled
    return if (Time.now - @updated_at) < Time::Span.new(1, 0, 0)
    get_weather
  end

  def get_weather
    @logger.error "#{self.name} getting weather"

    @weathers_temp.clear

    s = File.read(@payload_path)
    data = JSON.parse(s) as Array(JSON::Type)

    data.each do |w|
      wh = w as Hash(String, JSON::Type)
      wlat = wh["lat"].to_s.to_f
      wlon = wh["lon"].to_s.to_f

      distance = get_distance(wlat, wlon)
      time = Time.epoch( wh["time_to"].to_s.to_i )
      dtime = Time.now - time

      if distance < @max_distance #&& dtime.to_i >= -3600 && dtime.to_i <= 3600
        # add to list
        @weathers_temp << {
          wh["city"].to_s,
          wh["country"].to_s,
          distance,
          time,
          wh["temperature"].to_s.to_f,
          wh["wind"].to_s.to_f,
        }
      end
    end

    s = File.read(@payload_metar_path)
    data = JSON.parse(s) as Array(JSON::Type)

    data.each do |w|
      wh = w as Hash(String, JSON::Type)
      wlat = wh["lat"].to_s.to_f
      wlon = wh["lon"].to_s.to_f

      distance = get_distance(wlat, wlon)
      time = Time.epoch( wh["time_to"].to_s.to_i )
      dtime = Time.now - time

      if distance < @max_distance #&& dtime.to_i >= -3600 && dtime.to_i <= 3600
        # add to list
        @weathers_temp << {
          wh["city"].to_s,
          wh["country"].to_s,
          distance,
          time,
          wh["temperature"].to_s.to_f,
          wh["wind"].to_s.to_f,
        }
      end
    end

    @weathers.clear

    @weathers_temp.sort do |a,b|
      a[2] <=> b[2]
    end.each do |w|
      if @weathers.select{|u| u[0] == w[0]}.size == 0
        @weathers << w
      end
    end

    @pages = (@weathers.size.to_f / @per_page.to_f).ceil

    mark_updated
  end

  def payload
    return {"result" => @weathers}
  end

  def content
    s = "Page: #{@cursor + 1}\n\n"

    pagination_from = @cursor * @per_page
    pagination_to = (@cursor + 1) * @per_page

    @weathers[pagination_from...pagination_to].each do |w|
      s += "#{w[0]}, #{w[1]}".gsub(/\W/, " ").rjust(42)
      s += "#{( (w[2]) / 1000.0).round(1)} km".rjust(13)
      s += "#{w[3].to_s("%H:%M:%S")}".rjust(15)
      s += "#{w[4]} C".rjust(10)
      s += "#{w[5].round(1)} m/s".rjust(10)
      s += "\n"
    end

    return s
  end

  def get_distance(lat, lon)
    # return Math.sqrt( (@lat - lat) ** 2 + (@lon - lon) ** 2 )

    rad_per_deg = (Math::PI) / 180.0  # PI / 180
    rkm = 6371                  # Earth radius in kilometers
    rm = rkm * 1000             # Radius in meters

    dlat_rad = (lat-@lat) * rad_per_deg  # Delta, converted to rad
    dlon_rad = (lon-@lon) * rad_per_deg

    lat1_rad, lon1_rad = lat * rad_per_deg, @lat * rad_per_deg
    lat2_rad, lon2_rad = lon * rad_per_deg, @lon * rad_per_deg

    a = Math.sin(dlat_rad/2.0)**2 + Math.cos(lat1_rad) * Math.cos(lat2_rad) * Math.sin(dlon_rad/2.0)**2
    c = 2.0 * Math.atan2(Math.sqrt(a), Math.sqrt(1.0-a))

    return rm * c # Delta in meters
  end

  def move_cursor(offset)
    return unless 0 <= @cursor + offset < @pages
    @cursor += offset
  end

  def send_key(char)
    if char == 68
      move_cursor(-1)
    elsif char == 67
      move_cursor(1)
    else
      return false
    end
  end

end
