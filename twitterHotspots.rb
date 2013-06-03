#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitterHotspots.log')   

log_time("Start time")

def pulltweets

  @yml['Hotspots'].each do | hotspot |

    log_time("polling: all tweets from " + hotspot[0].to_s)

    tweets = fetch_tweets(hotspot)

    sleep 5 # We don't want to piss Twitter off by hounding their servers
  
    insert_tweets(tweets) if tweets.length > 0
  end

end

setvars
pulltweets

log_time("End time\n\n\n")
