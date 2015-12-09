struct Time
  def to_json(io)
    io << self.to_s("%Y-%m-%dT%H:%M:%S%z").to_json
  end
end

class Hash
  def self.to_json(io)
    io << self.to_json
  end
end
