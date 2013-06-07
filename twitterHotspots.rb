#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitterHotspots.log')   

log_time("Start time")

def pulltweets

  @yml['ActivityZone'].each do | activityzone |

    log_time("polling: " + activityzone[0].to_s)

    tweetdata = fetch_tweet_data(activityzone)

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

setvars

pulltweets

log_time("End time\n\n\n")
