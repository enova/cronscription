require 'cronscription'

require 'tempfile'


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
      cronfile = <<-END
        #{min1}  #{hour1}  *  *  *   common
        #{min2}  #{hour2}  *  *  *   common
      END
      tab = Cronscription::Tab.new(cronfile.lines.to_a)

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
end

