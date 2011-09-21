class CronParse
  def initialize(crontab_lines)
    # Eliminate all lines starting with '#' since they are full comments
    @entries = crontab_lines.select{|l| l !~ /^\s*#/}.map{|e| Entry.new(e)}
  end

  def find(regex)
    @entries.select{|e| e.match_command?(regex)}
  end


  class Entry
    CHECK_KEYS = [:min, :hour, :day, :mon, :wday]
    attr_reader :times, :command

    def initialize(line)
      @line = line
      @times = {}

      raw = {}
      raw[:min], raw[:hour], raw[:day], raw[:mon], raw[:wday], @command = line.split(nil, 6)
      @command.gsub!(/#.*/, '')

      CHECK_KEYS.each do |key, range|
        @times[key] = parse_column(raw[key])
      end
      @times
    end

    def [](key)
      @times[key]
    end

    def parse_column(column)
      if column =~ /,/
        return column.split(',').map{|c| parse_column(c)}.flatten.uniq
      end

      if column =~ /-/
        Range.new(*column.split('-').map{|c| c.to_i}).to_a
      else
        [column.to_i]
      end
    end

    def filter_bounds(entry, start, finish)
      entry.map do |k, vals|
        start_val  = start.send(k)
        finish_val = finish.send(k)
        if start_val < finish_val
          vals.select{|v| start_val < v && v < finish_val}
        else
          vals
        end
      end
    end

    def to_s
      @line
    end

    def match_command?(regex)
      regex === @command
    end
  end
end



describe CronParse do
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
    @cron_parse = CronParse.new(@crontab_lines)
  end

  describe 'find' do
    it 'should find the daily entry' do
      entries = @cron_parse.find(/daily/).map{|e| e.to_s}
      entries.should == [@crontab_lines[2]]
    end

    it 'should find all cron.* entries' do
      entries = @cron_parse.find(/cron\..*/).map{|e| e.to_s}
      entries.should == @crontab_lines[1..4]
    end

    it 'should ignore complete line comments' do
      entries = @cron_parse.find(/.*/).map{|e| e.to_s}
      entries.should == @crontab_lines[1..-1]
    end

    it 'should ignore trailing comments' do
      entries = @cron_parse.find(/test trailing comment/).map{|e| e.to_s}
      entries.should == []
    end

    it 'should ignore time directives' do
      entries = @cron_parse.find(/0/).map{|e| e.to_s}
      entries.should == [@crontab_lines[-1]]
    end
  end
end

describe CronParse::Entry do
  describe 'from_s' do
    it 'should map columns with correct fields' do
      # <minute> <hour> <day> <month> <day of week> <tags and command>
      entry = CronParse::Entry.new('1 2 3 4 5 comm')
      entry.times[:min].should  == [1]
      entry.times[:hour].should == [2]
      entry.times[:day].should  == [3]
      entry.times[:mon].should  == [4]
      entry.times[:wday].should == [5]
      entry.command.should      == 'comm'
    end

    it 'should convert to original line on to_s' do
      line = '      1 2 3 4 5 fun today! # some comment'
      entry = CronParse::Entry.new(line)
      entry.to_s.should == line
    end
  end

  describe 'parse_column' do
    before :all do
      @entry = CronParse::Entry.new('1 2 3 4 5 6')
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

    it 'should return unique entries only' do
      @entry.parse_column('1,1,1').should == [1]
    end
  end

  describe 'match_command?' do
    it 'should match command by regex' do
      entry = CronParse::Entry.new('1 2 3 4 5 command one')
      entry.match_command?(/m*and\s*on/).should be_true
    end

    it 'should not match command within comments' do
      entry = CronParse::Entry.new('1 2 3 4 5 command #herp')
      entry.match_command?(/herp/).should be_false
    end

    it 'should not match command within time directives' do
      entry = CronParse::Entry.new('1 2 3 4 5 command #herp')
      entry.match_command?(/\d/).should be_false
    end
  end
end
