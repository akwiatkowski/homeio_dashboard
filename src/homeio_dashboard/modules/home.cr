require "json"

class HomeioDashboard::Home < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "Home"
    @enabled = true

    @updated_at = Time.now
    @io = MemoryIO.new(1024)
    @max_height = 20
  end

  getter :name
  property :io, :max_height

  def make_it_so
    mark_updated
  end

  def payload
    {"updated_at" => @updated_at = Time.now}
  end

  def content
    s = "Home updated at #{@updated_at.to_s}"
    s += "\n\n"
    s += @io.to_s.split("\n").reverse[0..(@max_height - 6)].join("\n")
    return s
  end
end
