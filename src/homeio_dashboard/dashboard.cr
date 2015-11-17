require "logger"

class HomeioDashboard::Dashboard
  def initialize
    @logger = Logger.new(STDOUT)
    @logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
                          io << severity[0] << ", [" << datetime.to_s("%H:%M:%S.%L") << "] "
                          io << severity.rjust(5) << ": " << message
                        end
    @logger.level = Logger::DEBUG

    @modules = [] of HomeioDashboard::Abstract
  end

  getter :logger

  def add_module(m)
    @modules << m
  end

  def prepare
    @modules.each do |s|
      s.prepare
    end
  end

  def make_it_so
    @modules.each do |s|
      s.make_it_so
    end
  end

  def start
    loop do
      make_it_so
      sleep 10
    end
  end
end
