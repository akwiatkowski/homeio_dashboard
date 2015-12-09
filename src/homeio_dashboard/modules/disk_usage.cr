require "http"
require "json"
require "yaml"

class HomeioDashboard::DiskUsage < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "DiskUsage"
    @enabled = true

    @disk_usages = [] of Tuple(String, Int64, Int64, Float64)

    @command = "df -m"

    @updated_at = Time.now
  end

  getter :name

  def calculate_if_needed
    return @disk_usages if @disk_usages.size > 0 && (Time.now - @updated_at).to_i <= 30

    @disk_usages.clear

    result = `#{@command}`
    result.split(/\n/)[1..-1].each do |s|
      drive = s.gsub(/\s{2,50}/, " ").split(/\s+/) as Array(String)

      unless drive[0].to_s == "tmpfs"
        @disk_usages << {drive[5].to_s, drive[1].to_s.to_i64, drive[2].to_s.to_i64, 100.0 * drive[2].to_s.to_f / drive[1].to_s.to_f }
      end
    end
    @updated_at = Time.now

    @disk_usages.uniq!

    return @disk_usages
  end

  def payload
    {"disk_usages" => calculate_if_needed}
  end

  def content
    s = ""
    calculate_if_needed.each do |d|
      s += " "

      s += "#{d[0].ljust(10)}"
      s += "  "

      if d[1] > (10*1024)
        s += "#{(d[1])/1024} GB".rjust(10)
      else
        s += "#{d[1]} MB".rjust(10)
      end

      s += "  "

      if d[2] > 10*1024
        s += "#{(d[2])/1024} GB".rjust(10)
      else
        s += "#{d[2]} MB".rjust(10)
      end

      s += "  "

      s += "#{d[3].round(1)} %".rjust(10)


      s += "\n"
    end

    return s
  end

end
