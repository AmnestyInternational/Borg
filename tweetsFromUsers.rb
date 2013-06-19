#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/tweetsFromUsers.log')   

log_time("Start time")

def pull_tweets

  @yml['Users'].each do | user |
    max_id = nil

    loop do 

      tweetdata = fetch_user_timeline(user, nil, max_id)
      max_id = tweetdata['max_id']

      insert_tweets(tweetdata['tweets']) if tweetdata['tweets'].length > 0
      sleep 1
      insert_twitter_users(tweetdata['twitterusers']) if tweetdata['twitterusers'].length > 0
      sleep 1
      insert_tweet_regions(tweetdata['tweetregions']) if tweetdata['tweetregions'].length > 0
      sleep 1
      insert_tweet_hashtags(tweetdata['tweethashtags']) if tweetdata['tweethashtags'].length > 0
      sleep 1
      insert_tweet_urls(tweetdata['tweeturls']) if tweetdata['tweeturls'].length > 0
      sleep 1
      insert_tweets_anatomized(tweetdata['tweetsanatomize']) if tweetdata['tweetsanatomize'].length > 0
      sleep 1
      insert_tweet_user_mentions(tweetdata['tweetusermentions']) if tweetdata['tweetusermentions'].length > 0

      break if tweetdata["tweets"].empty?
      log_time("sleeping for 60 seconds...")
      sleep 60
    end

  end

end

def fetch_user_timeline(user, since_id = nil, max_id = nil)

  parameters = Hash.new
  parameters[:count] = 200
  parameters[:max_id] = max_id unless max_id.nil?
  parameters[:since_id] = since_id unless  since_id.nil?

  log_time("Pulling tweets by #{user} using #{parameters.to_s}")

  organise_raw_tweet_data(Twitter.user_timeline(user, parameters))

end

setvars

pull_tweets

log_time("End time\n\n\n")
