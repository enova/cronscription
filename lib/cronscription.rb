require 'cronscription/tab'


module Cronscription
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
