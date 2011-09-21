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

    def parse_column(column, default=[])
      case column
        when /\*/ then default
        when /,/  then column.split(',').map{|c| parse_column(c)}.flatten.uniq
        when /-/  then Range.new(*column.split('-').map{|c| c.to_i}).to_a
        else           [column.to_i]
      end
    end

    def to_s
      @line
    end

    def match_command?(regex)
      regex === @command
    end

    def times_to_execute_between(start, finish)
      ret = []

      incr_min  = 60
      incr_hour = incr_min*60
      incr_day  = incr_hour*24
      incr      = incr_min

      current = start
      while current < finish
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
    def initialize(crontab_lines)
      # Eliminate all lines starting with '#' since they are full comments
      @entries = crontab_lines.select{|l| l !~ /^\s*#/}.map{|e| Entry.new(e)}
    end

    def find(regex)
      @entries.select{|e| e.match_command?(regex)}
    end
  end
end


describe Cronscription::Entry do
  describe 'parse_column' do
    before :all do
      @entry = Cronscription::Entry.new('1 2 3 4 5 6')
    end

    it 'should return fixed value as list of one' do
      @entry.parse_column('1').should == [1]
    end

    it 'should return comma-separated as list of values' do
      @entry.parse_column('5,2,8').should == [5, 2, 8]
    end

    it 'should return range as list of everything within the range' do
      @entry.parse_column('4-6').should == [4, 5, 6]
    end

    it 'should return combination of range and comma-separated' do
      @entry.parse_column('9,2-5,7').should == [9, 2, 3, 4, 5, 7]
    end

    it 'should use default value on asterisk' do
      default = [1, 5, 9, 2, 6]
      @entry.parse_column('*', default).should == default
    end

    it 'should return unique entries only' do
      @entry.parse_column('1,1,1').should == [1]
    end
  end

  describe 'from_s' do
    it 'should map columns with correct fields' do
      # <minute> <hour> <day> <month> <day of week> <tags and command>
      entry = Cronscription::Entry.new('1 2 3 4 5 comm')
      entry.times.should == {
        :min => [1],
        :hour => [2],
        :day => [3],
        :month => [4],
        :wday => [5],
      }
      entry.command.should == 'comm'
    end

    it 'should convert to original line on to_s' do
      line = '      1 2 3 4 5 fun today! # some comment'
      entry = Cronscription::Entry.new(line)
      entry.to_s.should == line
    end

    it 'should use FULL_RANGE for default values' do
      entry = Cronscription::Entry.new('* * * * * comm')
      entry.times.should == Cronscription::Entry::FULL_RANGE
    end
  end

  describe 'match_command?' do
    it 'should match command by regex' do
      entry = Cronscription::Entry.new('1 2 3 4 5 command one')
      entry.match_command?(/m*and\s*on/).should be_true
    end

    it 'should not match command within comments' do
      entry = Cronscription::Entry.new('1 2 3 4 5 command #herp')
      entry.match_command?(/herp/).should be_false
    end

    it 'should not match command within time directives' do
      entry = Cronscription::Entry.new('1 2 3 4 5 command #herp')
      entry.match_command?(/\d/).should be_false
    end
  end

  describe 'times_to_execute_between' do
    it 'should return times based on minutes' do
      entry = Cronscription::Entry.new("21-40 * * * * comm")
      start = Time.local(2011, 1, 1, 0, 0)
      finish = Time.local(2011, 1, 1, 0, 30)

      times = entry.times_to_execute_between(start, finish)
      times == (21..30).map{|m| Time.local(2011, 1, 1, 0, m)}
    end

    it 'should return times based on hours' do
      entry = Cronscription::Entry.new("0 1-8 * * * comm")
      start = Time.local(2011, 1, 1, 0, 0)
      finish = Time.local(2011, 1, 1, 6, 0)

      times = entry.times_to_execute_between(start, finish)
      times == (1..6).map{|h| Time.local(2011, 1, 1, h, 0)}
    end

    it 'should return times based on days' do
      entry = Cronscription::Entry.new("0 0 8-20 * * comm")
      start = Time.local(2011, 1, 5, 0, 0)
      finish = Time.local(2011, 1, 15, 0, 0)

      times = entry.times_to_execute_between(start, finish)
      times == (8..15).map{|d| Time.local(2011, 1, d, 0, 0)}
    end

    it 'should return times based on months' do
      entry = Cronscription::Entry.new("0 0 1 1-5 * comm")
      start = Time.local(2011, 4, 1, 0, 0)
      finish = Time.local(2011, 12, 1, 0, 0)

      times = entry.times_to_execute_between(start, finish)
      times == (4..5).map{|m| Time.local(2011, m, 1, 0, 0)}
    end
  end
end

describe Cronscription::Tab do
  before :all do
    @crontab = <<-END
      # <minute> <hour> <day> <month> <day of week> <tags and command>
      0  *  *  *  *   cron.hourly
      0  0  *  *  *   cron.daily
      0  0  *  *  0   cron.weekly
      0  0  1  *  *   cron.monthly
      1  2  3  4  5   0 # test trailing comment
    END
    @crontab_lines = @crontab.lines.to_a
    @tab = Cronscription::Tab.new(@crontab_lines)
  end

  describe 'find' do
    it 'should find the daily entry' do
      entries = @tab.find(/daily/).map{|e| e.to_s}
      entries.should == [@crontab_lines[2]]
    end

    it 'should find all cron.* entries' do
      entries = @tab.find(/cron\..*/).map{|e| e.to_s}
      entries.should == @crontab_lines[1..4]
    end

    it 'should ignore complete line comments' do
      entries = @tab.find(/.*/).map{|e| e.to_s}
      entries.should == @crontab_lines[1..-1]
    end

    it 'should ignore trailing comments' do
      entries = @tab.find(/test trailing comment/).map{|e| e.to_s}
      entries.should == []
    end

    it 'should ignore time directives' do
      entries = @tab.find(/0/).map{|e| e.to_s}
      entries.should == [@crontab_lines[-1]]
    end
  end

  describe 'merged_times' do
    it 'should merge times into sorted array' do
    end
  end
end

