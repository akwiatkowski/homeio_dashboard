require "json"

class HomeioDashboard::BackJobSample < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "BackJobSample"
    @enabled = true

    @updated_at = Time.now
    @i = 0
  end

  getter :name

  def make_it_so
    @i += 1
    @updated_at = Time.now
  end

  def payload
    {"i" => @i}
  end

  def content
    return "Sample auto increment #{@i}, #{@updated_at.to_s}"
  end

end
