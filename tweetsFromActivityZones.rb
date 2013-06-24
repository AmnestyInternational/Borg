#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitter_activity_zones.log')
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new  

log_time("Start time")

def pull_tweets

  @yml['Activity zone'].each do | activity_zone |
    activity_zonename = activity_zone[0]
    activity_zone_details = activity_zone[1]
    activity_zone_details['timezone'] = @default_timezone unless activity_zone_details['timezone']

    log_time("Activity Zone: #{activity_zonename}")
    log_time("Start = #{activity_zone_details['start']}, end = #{activity_zone_details['end']}, timezone = #{activity_zone_details['timezone']}")
    log_time("Current? #{activity_zone_details.is_current?.to_s}")

    if activity_zone_details.is_current?

      since_id = get_since_id(activity_zonename)
      log_time("Since id: #{since_id}")
      
      activity_zone_details['areas'].each do | area |

        tweetdata = fetch_tweets_from_area(activity_zonename, area, since_id)

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
        sleep 1
      end
    end
  end
end

setvars

pull_tweets

log_time("End time\n\n\n")
