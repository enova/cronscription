require 'cronscription/entry'


module Cronscription
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
end
