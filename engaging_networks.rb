#!/usr/bin/env ruby
require_relative 'lib/engaging_networksAPIengine'

def parse_options
  options = {}
  case ARGV[0]
  when "--help"
    puts "Usage: engaging_networks.rb [switches] [arguments]\n  -d, --days     number of days\n  --help         this text"
    exit
  when "-d", "--days"
    options[:days] = ARGV[1].to_i
  else
    options[:days] = 1
  end
  options
end

days = parse_options[:days]

@LOG = Logger.new('log/e-activist.log')
# Set back to default formatter because active_support/all is messing things up
@LOG.formatter = Logger::Formatter.new 

log_time("Start time")

savedata(pullrawdata(days), 'raweactivism')

eactivist = organise(loadrawdata)

savedata(eactivist, 'cleaneactivism')

importeactivists(eactivist)

log_time("Finish time\n\n\n")
