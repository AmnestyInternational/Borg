#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitter.log')   

log_time("Start time")

def pulltweets

  @yml['SearchTerms'].each do | search_term |

    @yml['Regions'].each do | region |

      log_time("polling: " + search_term.to_s + " from " + region[0].to_s)

      tweetdata = fetch_tweet_data(region, search_term)
  
      insert_tweets(tweetdata['tweets']) if tweetdata['tweetregions'].length > 0
      sleep 1
      insert_twitter_users(tweetdata['twitterusers']) if tweetdata['twitterusers'].length > 0
      sleep 1
      insert_tweet_user_mentions(tweetdata['tweetusermentions']) if tweetdata['tweetusermentions'].length > 0
      sleep 1
      insert_tweet_hashtags(tweetdata['tweethashtags']) if tweetdata['tweethashtags'].length > 0
      sleep 1
      insert_tweet_urls(tweetdata['tweeturls']) if tweetdata['tweeturls'].length > 0
      sleep 1
      insert_tweets_anatomized(tweetdata['tweetsanatomize']) if tweetdata['tweetsanatomize'].length > 0
      sleep 1

    end

  end

end

setvars
pulltweets

log_time("End time\n\n\n")
