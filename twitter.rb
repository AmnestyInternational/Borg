#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitter.log')   

log_time("Start time")

def pulltweets

  @yml['SearchTerms'].each do | search_term |

    @yml['Cities'].each do | city |

      log_time("polling: " + search_term.to_s + " from " + city[0].to_s)

      tweets = fetch_tweets(city, search_term)

      sleep 5 # We don't want to piss Twitter off by hounding their servers
  
      insert_tweets(tweets) if tweets.length > 0

    end

  end

end

=begin
def pullhotspottweets
  @yml['Hotspots'].each do | hotspot |
    log_time("polling: all tweets from " + hotspot[0].to_s)

    tweets = fetch_tweets(hotspot)

    log_time("returned tweets: " + tweets["results"].length.to_s)
    
    tweets["results"].each do | tweet |
      coordinates = tweet['geo'].nil? ? [] : tweet['geo']['coordinates'] # very few people seem to be geo tweeting but this will be useful in the future
    
      @tweet << {
        :id => tweet['id'],
        :created => Time.parse(tweet['created_at']),
        :usr => tweet['from_user'],
        :usr_id => tweet['from_user_id'],
        :usr_name => tweet['from_user_name'],
        :coordinates => coordinates,
        :city => hotspot[0],
        :location => tweet['location'],
        :profile_image_url => tweet['profile_image_url'],
        :text => tweet['text']
      }
    end
  
    insert_tweets(@tweet)

    sleep 5 # We don't want to piss Twitter off by hounding their servers. We'll need to increase this once we have more cities and hash tags

  end

end
=end

setvars
pulltweets

log_time("End time\n\n\n")
