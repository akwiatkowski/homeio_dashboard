require "json"

class HomeioDashboard::Home < HomeioDashboard::Abstract
  def initialize(l)
    @logger = l

    @name = "Home"
    @enabled = true

    @updated_at = Time.now
    @io = MemoryIO.new(1024)
  end

  getter :name
  property :io

  def make_it_so
    @updated_at = Time.now
  end

  def payload
    {"updated_at" => @updated_at = Time.now}
  end

  def content
    s = "Home updated at #{@updated_at.to_s}"
    s += "\n\n"
    s += @io.to_s
    return s
  end

end
