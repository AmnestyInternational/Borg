#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitter.log')   

log_time("Start time")

def pulltweets

  @yml['SearchTerms'].each do | search_term |

    @yml['Cities'].each do | city |

      log_time("polling: " + search_term.to_s + " from " + city[0].to_s)
  
      puts city.inspect

      tweets = fetch_tweets(city, search_term)

      sleep 5 # We don't want to piss Twitter off by hounding their servers
  
      insert_tweets(tweets) if tweets.length > 0

    end

  end

end

setvars
pulltweets

log_time("End time\n\n\n")
