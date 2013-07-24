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

  @yml['Users'].each do | screen_name |
    max_id = nil
    count += 1
    user_details = lookup_twitter_user(screen_name)
    (log_time("User does not exist", "error") && next) if user_details.nil?
    since_id = fetch_user_since_id(user_details)
    log_time("#{screen_name} is #{count} of #{totalusers}")
    log_time("#{screen_name} has #{user_details[:statuses_count].to_s} tweets, collecting...")

    tweetscount = 0

    loop do

      tweetdata = fetch_user_timeline(screen_name, since_id, max_id)
      max_id = tweetdata['max_id']

      tweetscount += tweetdata['tweets'].length.to_i

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

      log_time("#{tweetscount} collected, waiting #{(tweetdata['nextrun'] - Time.now).to_i} seconds before next fetch")
      sleep(1) until Time.now > tweetdata['nextrun']
      break if tweetdata["tweets"].empty?
    end
    log_time("#{tweetscount} collected for #{screen_name}\n")
  end

end

setvars

pull_tweets

log_time("End time\n\n\n")
