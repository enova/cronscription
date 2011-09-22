module Cronscription
  class Entry
    ORDERED_KEYS = [:min, :hour, :day, :month, :wday]
    FULL_RANGE = {
      :min   => (0..59).to_a,
      :hour  => (0..23).to_a,
      :day   => (1..31).to_a,
      :month => (1..12).to_a,
      :wday  => (0..6).to_a,
    }

    attr_reader :times, :command

    def initialize(line)
      @line = line
      @times = {}

      raw = {}
      raw[:min], raw[:hour], raw[:day], raw[:month], raw[:wday], @command = line.split(nil, 6)
      @command.gsub!(/#.*/, '')

      raw.each do |key, val|
        @times[key] = parse_column(val, FULL_RANGE[key])
      end
    end

    def ==(other)
      @line == other.instance_variable_get(:@line)
    end

    def to_s
      @line
    end

    def self.parsable?(str)
      !!(str =~ /([*\d,-]+\s+){5}.*/)
    end

    def parse_column(column, default=[])
      case column
        when /\*/ then default
        when /,/  then column.split(',').map{|c| parse_column(c)}.flatten.uniq
        when /-/  then Range.new(*column.split('-').map{|c| c.to_i}).to_a
        else           [column.to_i]
      end
    end

    def match_command?(regex)
      regex === @command
    end

    def times_to_execute(start, finish)
      ret = []

      incr_min  = 60
      incr_hour = incr_min*60
      incr_day  = incr_hour*24
      incr      = incr_min

      if start.sec == 0
        current = start
      else
        current = Time.local(start.year, start.month, start.day, start.hour, start.min + 1, 0)
      end
      while current <= finish
        if ORDERED_KEYS.map{|k| @times[k].include?(current.send k)}.all?
          ret << current 
          # If only I could goto into the middle of the loop, this wouldn't run every time.
          # Optimizations to reduce execution time.  No need to run minutely if there is only one minute.
          if @times[:min].size == 1
            if @times[:hour].size == 1
              incr = incr_day
            else
              incr = incr_hour
            end
          end
        end
        current += incr
      end

      ret
    end
  end

  class Tab
    def initialize(cron_lines)
      # Eliminate all lines starting with '#' since they are full comments
      @entries = cron_lines.select{|l| Entry.parsable?(l)}.map{|e| Entry.new(e)}
    end

    def ==(other)
      @entries == other.instance_variable_get(:@entries)
    end

    def find(regex)
      @entries.select{|e| e.match_command?(regex)}
    end

    def sorted_merge(*arrs)
      arrs.flatten.uniq.sort
    end

    def times_to_execute(regex, start, finish)
      sorted_merge(find(regex).map{|e| e.times_to_execute(start, finish)})
    end
  end

  class << self
    # Convenient construction methods
    def from_s(str)
      Tab.new(str.lines.to_a)
    end

    def from_filepath(path)
      File.open(path) do |f|
        Tab.new(f.readlines)
      end
    end
  end
end
