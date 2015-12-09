require "ncurses"
require "logger"
require "json"

class HomeioDashboard::Dashboard
  def initialize
    @io = MemoryIO.new(1024 * 64)
    @logger = Logger.new(@io)
    @logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
                          io << severity[0] << ", [" << datetime.to_s("%H:%M:%S.%L") << "] "
                          io << severity.rjust(5) << ": " << message
                        end
    @logger.level = Logger::DEBUG

    @modules = [] of HomeioDashboard::Abstract

    #menu
    NCurses.init
    NCurses.raw
    NCurses.no_echo

    @max_height, @max_width = NCurses.stdscr.max_dimensions

    @menu = NCurses::Window.new(1, @max_width, 0, 0)
    @content = NCurses::Window.new(@max_height - 2, @max_width, 2, 0)

    @cursor = 0
    @enabled = true

    # default home
    w = HomeioDashboard::Home.new(@logger)
    w.io = @io
    add_module(w)
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

  def run_all
    @modules.each do |s|
      s.make_it_so
    end
  end

  def save_payload
    result = String.build do |io|
      io.json_object do |object|
        @modules.each do |m|
          object.field m.name, m.payload
        end
      end
    end

    f = File.new(File.join("www", "payload.json"), "w")
    f.puts(result)
    f.close
  end

  def start_menu
    begin
      while @enabled
        refresh
        wait_for_input
      end
    ensure
      NCurses.end_win
    end
  end

  def current_module
    @modules[@cursor].name
  end

  def current_content
    @modules[@cursor].content
  end

  def current_updated_at
    @modules[@cursor].updated_at as Time
  end

  def refresh
    render_menu
    render_content
  end

  def menu_header
    s = "HomeIO: #{current_module}"
    s += "#{@cursor + 1}/#{@modules.size} | #{current_updated_at.to_s("%H:%M:%S")}".rjust(@max_width - s.size)
    return s
  end

  def render_menu
    @menu.clear
    @menu.print(menu_header)
    @menu.refresh
  end

  def render_content
    @content.clear
    @content.print(current_content)
    @content.refresh
  end

  def move_cursor(offset)
    return unless 0 <= @cursor + offset < @modules.size
    @cursor += offset
    # force refresh
  end

  def wait_for_input
    @menu.on_input do |char, modifier|
      case char
      when :escape then
        @enabled = false
      when 'q' then
        @enabled = false

      when :up then
        move_cursor(-1)
      when :down then
        move_cursor(1)

      else
        # nothing
      end
    end
  end

  def start
    prepare

    future do
      start_menu
    end

    future do
      loop do
        run_all
        save_payload
        sleep 5
      end
    end

    while @enabled
      sleep 1
    end
  end

end
