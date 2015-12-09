require "http"
require "json"

abstract class HomeioDashboard::Abstract
  getter :name, :updated_at

  def initialize(l)
    @updated_at = Time.now
  end

  def prepare
  end

  def make_it_so
  end

  def key
  end

  def payload
  end

  def payload
    return Hash(String, String)
  end

  def content
    return ""
  end

  def mark_updated
    @updated_at = Time.now
    @logger.debug "#{self.name} updated"
  end

  def send_key(char)
    return false
  end
end
