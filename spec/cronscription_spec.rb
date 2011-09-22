require 'cronscription'

require 'tempfile'


describe Cronscription do
  before(:all) do
    @cronstr = <<-END
      59  * 10 * * entry1
       * 12  2 * 5 entry2
    END
    @tab = Cronscription::Tab.new(@cronstr.lines.to_a)
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

