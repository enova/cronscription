class CronParse
  DEFAULTS = {
    :min  => 0..59,
    :hour => 0..23,
    :day  => 0..31,
    :mon  => 1..11,
    :dow  => 0..6,
  }

  def initialize(crontab_lines)
    # Eliminate all lines starting with '#' since they are full comments
    @lines = crontab_lines.select{|l| l !~ /^\s*#/}
  end

  def find(regex)
    @lines.select{|l| l.split(nil, 6)[-1].gsub(/#.*$/, '') =~ regex}
  end

  def parse_entry(line)
    raw = {}
    raw[:min], raw[:hour], raw[:day], raw[:mon], raw[:dow], raw[:command] = line.split(nil, 6)

    entry = {}
    DEFAULTS.each do |key, range|
      entry[key] = parse_column(raw[key]).select{|v| range.include?(v) }
    end
    entry
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

  def executions_of(regex, end_time)
  end
end


describe 'CronParse' do
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
      entries = @cron_parse.find(/daily/)
      entries.should == [@crontab_lines[2]]
    end

    it 'should find all cron.* entries' do
      entries = @cron_parse.find(/cron\..*/)
      entries.should == @crontab_lines[1..4]
    end

    it 'should ignore complete line comments' do
      entries = @cron_parse.find(/.*/)
      entries.should == @crontab_lines[1..-1]
    end

    it 'should ignore trailing comments' do
      entries = @cron_parse.find(/test trailing comment/)
      entries.should == []
    end

    it 'should ignore time directives' do
      entries = @cron_parse.find(/0/)
      entries.should == [@crontab_lines[-1]]
    end
  end

  describe 'parse_column' do
    it 'should return fixed value as list of one' do
      @cron_parse.parse_column('1').should == [1]
    end

    it 'should return comma-separated as list of values' do
      @cron_parse.parse_column('5,2,8').should == [5, 2, 8]
    end

    it 'should return range as list of everything within the range' do
      @cron_parse.parse_column('4-6').should == [4, 5, 6]
    end

    it 'should return combination of range and comma-separated' do
      @cron_parse.parse_column('9, 2-5,7').should == [9, 2, 3, 4, 5, 7]
    end

    it 'should return unique entries only' do
      @cron_parse.parse_column('1,1,1').should == [1]
    end
  end

  describe 'executions_by' do
    # <minute> <hour> <day> <month> <day of week> <tags and command>
    def this_time_tomorrow
      t = Time.now
      Time.local(t.year, t.month, t.day+1, t.hour, t.min, t.sec)
    end

    def midnight_tomorrow
      t = this_time_tomorrow
      Time.local(t.year, t.month, t.day)
    end

    it 'should return single execution of command by tomorrow' do
      crontab_lines = ['0  0  *  *  *   midnight-run']
      cron_parse = CronParse.new(crontab_lines)

      executions = cron_parse.executions_of('midnight-run', this_time_tomorrow)
      executions.should == [midnight_tomorrow]
    end
  end
end
