require "ncurses"
require "logger"
require "json"

class HomeioDashboard::Dashboard
  def initialize
    @io = MemoryIO.new(1024 * 64)
    @logger = Logger.new(@io)
    #@logger = Logger.new(File.new("log.log", "w"))

    @logger.formatter = Logger::Formatter.new do |severity, datetime, progname, message, io|
      io << severity[0] << ", [" << datetime.to_s("%H:%M:%S.%L") << "] "
      io << severity.rjust(5) << ": " << message
    end
    @logger.level = Logger::DEBUG

    @modules = [] of HomeioDashboard::Abstract

    # menu
    NCurses.init
    NCurses.raw
    NCurses.no_echo

    @max_height, @max_width = NCurses.stdscr.max_dimensions

    @menu = NCurses::Window.new(1, @max_width, 0, 0)
    @content = NCurses::Window.new(@max_height - 2, @max_width, 2, 0)

    @cursor = 0
    @enabled = true
    @last_refresh = Time.now
    @auto_refresh_every = 1.0

    # default home
    w = HomeioDashboard::Home.new(@logger)
    w.io = @io
    w.max_height = @max_height
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

  def current_module
    @modules[@cursor]
  end

  def current_module_name
    current_module.name
  end

  def current_content
    current_module.content
  end

  def current_updated_at
    current_module.updated_at as Time
  end

  def refresh
    render_menu
    render_content

    @last_refresh = Time.now
  end

  def auto_refresh
    if (Time.now - @last_refresh).to_f > @auto_refresh_every
      refresh
    end
  end

  def menu_header
    s = "HomeIO: #{current_module_name}"
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
  end

  def wait_for_input
    @menu.timeout = 0.2
    char = @menu.get_char
    case char
    when 65 then
      move_cursor(-1)
      refresh
    when 66 then
      move_cursor(1)
      refresh
    when 'q' then
      @enabled = false
    #when 27 then # esc
    #  @enabled = false
    else
      # if return true, then must update
      result = current_module.send_key(char)
      refresh if result

    end
  end

  def start_menu_thread
    future do
      refresh

      loop do
        wait_for_input
        auto_refresh
        sleep 0.03
      end
    end
  end

  def start_back_thread
    future do
      prepare

      loop do
        @logger.debug "Back thread loop"

        run_all
        save_payload
        sleep 1
      end
    end
  end

  def enabled_loop
    while @enabled
      sleep 1
    end
  end

  def start
    begin
      start_menu_thread
      start_back_thread
      enabled_loop
    ensure
      NCurses.end_win
    end
  end
end
