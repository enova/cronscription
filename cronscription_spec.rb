require File.join(File.dirname(__FILE__), 'cronscription')


describe Cronscription::Entry do
  before :all do
    @line = '1 2 3 4 5 comm'
    @entry = Cronscription::Entry.new(@line)
  end

  it 'should be equal when created from same values' do
    Cronscription::Entry.new(@line).should == @entry
  end

  describe 'from_s' do
    it 'should map columns with correct fields' do
      # <minute> <hour> <day> <month> <day of week> <tags and command>
      entry = Cronscription::Entry.new(@line)
      entry.times.should == {
        :min   => [1],
        :hour  => [2],
        :day   => [3],
        :month => [4],
        :wday  => [5],
      }
      entry.command.should == 'comm'
    end

    it 'should convert to original line on to_s' do
      line = '      1 2 * 4 5 fun today! # some comment'
      entry = Cronscription::Entry.new(line)
      entry.to_s.should == line
    end

    it 'should use FULL_RANGE for default values' do
      entry = Cronscription::Entry.new('* * * * * comm')
      entry.times.should == Cronscription::Entry::FULL_RANGE
    end

    it 'should understand compex command structure' do
      command = 'comm/rad --gen=ro -s tail'
      entry = Cronscription::Entry.new("* * * * * #{command}")
      entry.command.should == command
    end
  end

  describe 'parsable?' do
    it 'should be true for basic lines' do
      Cronscription::Entry.parsable?('* * * * * comm').should be_true
      Cronscription::Entry.parsable?('1 2 3 4 5 comm').should be_true
    end

    it 'should be true for compound time directives' do
      Cronscription::Entry.parsable?('1-2     *       *           *     *    comm').should be_true
      Cronscription::Entry.parsable?('  *   3,4       *           *     *    comm').should be_true
      Cronscription::Entry.parsable?('  *     *   3,4-5           *     *    comm').should be_true
      Cronscription::Entry.parsable?('  *     *       *   6-7,0,8-9     *    comm').should be_true
    end

    it 'should be true for complex commands' do
      Cronscription::Entry.parsable?('* * * * * comm/rad --gen=ro -s tail').should be_true
    end

    it 'should be false for bad time declaration' do
      Cronscription::Entry.parsable?('* b * * * comm').should be_false
      Cronscription::Entry.parsable?('* * * * . comm').should be_false
    end

    it 'should be false for dumb lines' do
      Cronscription::Entry.parsable?('   # This is a comment').should be_false
      Cronscription::Entry.parsable?('rawr!').should be_false
    end
  end

  describe 'parse_column' do
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

  describe 'times_to_execute' do
    it 'should return times based on minutes' do
      entry = Cronscription::Entry.new("21-40 * * * * comm")
      start  = Time.local(2011, 1, 1, 0, 0)
      finish = Time.local(2011, 1, 1, 0, 30)

      times = entry.times_to_execute(start, finish)
      times.should == (21..30).map{|m| Time.local(2011, 1, 1, 0, m)}
    end

    it 'should return times based on hours' do
      entry = Cronscription::Entry.new("0 1-8 * * * comm")
      start  = Time.local(2011, 1, 1, 0, 0)
      finish = Time.local(2011, 1, 1, 6, 0)

      times = entry.times_to_execute(start, finish)
      times.should == (1..6).map{|h| Time.local(2011, 1, 1, h, 0)}
    end

    it 'should return times based on days' do
      entry = Cronscription::Entry.new("0 0 8-20 * * comm")
      start  = Time.local(2011, 1,  5, 0, 0)
      finish = Time.local(2011, 1, 15, 0, 0)

      times = entry.times_to_execute(start, finish)
      times.should == (8..15).map{|d| Time.local(2011, 1, d, 0, 0)}
    end

    it 'should return times based on months' do
      entry = Cronscription::Entry.new("0 0 1 1-5 * comm")
      start  = Time.local(2011,  4, 1, 0, 0)
      finish = Time.local(2011, 12, 1, 0, 0)

      times = entry.times_to_execute(start, finish)
      times.should == (4..5).map{|m| Time.local(2011, m, 1, 0, 0)}
    end

    it 'should round start time up to the next minute' do
      entry = Cronscription::Entry.new("* * * * * comm")
      start  = Time.local(2011, 1, 1, 0, 0, 45)
      finish = Time.local(2011, 1, 1, 0, 1, 45)

      times = entry.times_to_execute(start, finish)
      times.should == [Time.local(2011, 1, 1, 0, 1)]
    end
  end
end

describe Cronscription::Tab do
  before :all do
    @cronstr = <<-END
      # <minute> <hour> <day> <month> <day of week> <tags and command>
      0  *  *  *  *   cron.hourly
      0  0  *  *  *   cron.daily
      0  0  *  *  0   cron.weekly
      0  0  1  *  *   cron.monthly
      1  2  3  4  5   0 # test trailing comment
    END
    @cron_lines = @cronstr.lines.to_a
    @tab = Cronscription::Tab.new(@cron_lines)
  end

  it 'should be equal when created from same values' do
    Cronscription::Tab.new(@cron_lines).should == @tab
  end

  describe 'find' do
    it 'should find the daily entry' do
      entries = @tab.find(/daily/).map{|e| e.to_s}
      entries.should == [@cron_lines[2]]
    end

    it 'should find all cron.* entries' do
      entries = @tab.find(/cron\..*/).map{|e| e.to_s}
      entries.should == @cron_lines[1..4]
    end

    it 'should ignore complete line comments' do
      entries = @tab.find(/.*/).map{|e| e.to_s}
      entries.should == @cron_lines[1..-1]
    end

    it 'should ignore trailing comments' do
      entries = @tab.find(/test trailing comment/).map{|e| e.to_s}
      entries.should == []
    end

    it 'should ignore time directives' do
      entries = @tab.find(/0/).map{|e| e.to_s}
      entries.should == [@cron_lines[-1]]
    end

    it 'should attempt to use possible lines when encountering mangled garbage' do
      cronstr = <<-END
        # The history of all hitherto
        existing society is the
        *  *  *  *  *   comm
        history of class struggles.
      END
      cron_lines = cronstr.lines.to_a
      tab = Cronscription::Tab.new(cron_lines)
      entries = tab.find(/.*/).map{|e| e.to_s}
      entries.should == [cron_lines[2]]
    end
  end

  describe 'sorted_merge' do
    before :all do
      @tab = Cronscription::Tab.new([])
    end

    it 'should merge in order' do
      @tab.sorted_merge([1, 4], [2, 7, 9]).should == [1, 2, 4, 7, 9]
    end

    it 'should merge while eliminating duplicates' do
      @tab.sorted_merge([2, 2, 2, 6, 7], [7, 8]).should == [2, 6, 7, 8]
    end
  end

  describe 'times_to_execute' do
    it 'should return merged times' do
      hour1 = 3
      min1 = 48

      hour2 = 6
      min2 = 21
      tab = Cronscription::Tab.new <<-END
        #{min1}  #{hour1}  *  *  *   common
        #{min2}  #{hour2}  *  *  *   common
      END

      start = Time.local(2011, 1, 1, 0, 0)
      finish = Time.local(2011, 1, 3, 0, 0)
      tab.times_to_execute(/common/, start, finish).should == [
                                                      Time.local(2011, 1, 1, hour1, min1),
                                                      Time.local(2011, 1, 1, hour2, min2),
                                                      Time.local(2011, 1, 2, hour1, min1),
                                                      Time.local(2011, 1, 2, hour2, min2),
                                                    ]
    end
  end

  describe 'convenient constructors' do
    it 'should create from string' do
      Cronscription.from_s(@cronstr).should == @tab
    end

    it 'should create from filepath' do
      path = nil
      Tempfile.open('cronscription') do |f|
        f.write(@cronstr)
        path = f.path
      end

      Cronscription.from_filepath(path).should == @tab
    end
  end
end

