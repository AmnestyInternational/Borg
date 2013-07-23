#!/usr/bin/env ruby
require_relative 'lib/engaging_networksAPIengine'

@LOG = Logger.new('log/e-activist.log')
# Set back to default formatter because active_support/all is messing things up
@LOG.formatter = Logger::Formatter.new 

log_time("Start time")

savedata(pullrawdata(14), 'raweactivism')

eactivist = organise(loadrawdata)

savedata(eactivist, 'cleaneactivism')

importeactivists(eactivist)

log_time("Finish time\n\n\n")
