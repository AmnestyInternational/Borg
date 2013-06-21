#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/tweetsFromUsers.log')   
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new

log_time("Start time")

def pull_tweets
  totalusers = @yml['Users'].length
  log_time("#{totalusers} users in Yaml file")
  count = 0

  @yml['Users'].each do | user |
    max_id = nil
    count += 1
    user_details = lookup_twitter_user(user)
    log_time("#{user} is #{count} of #{totalusers}")
    log_time("#{user} has #{user_details['statuses_count']} tweets, collecting...")

    tweetscount = 0

    loop do

      tweetdata = fetch_user_timeline(user, nil, max_id)
      max_id = tweetdata['max_id']

      tweetscount += tweetdata['tweets'].length if tweetdata['tweets'].length > 0

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
      log_time("#{tweetscount} collected, sleeping for 60 seconds...")
      sleep 60
    end
    log_time("#{tweetscount} collected for #{user}\n")
  end

end

setvars

pull_tweets

log_time("End time\n\n\n")
