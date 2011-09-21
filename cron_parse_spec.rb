class CronParse
  def initialize(crontab_lines)
    # Eliminate all lines starting with '#' since they are full comments
    @lines = crontab_lines.select{|l| l !~ /^\s*#/}
  end

  def find(regex)
    @lines.select{|l| l.split(nil, 6)[-1].gsub(/#.*$/, '') =~ regex}
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
end
