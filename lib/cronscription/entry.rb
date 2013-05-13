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
        when /\*\/(\d+)/ then default.select { |val| val % $1.to_i == 0 }
        when /\*/        then default
        when /,/         then column.split(',').map{|c| parse_column(c)}.flatten.uniq
        when /-/         then Range.new(*column.split('-').map{|c| c.to_i}).to_a
        else                  [column.to_i]
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

      current = nearest_minute(start)
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

    private
    def nearest_minute(time)
      if time.sec == 0
        time
      else
        # Always round up
        time + (60 - time.sec)
      end
    end
  end
end
