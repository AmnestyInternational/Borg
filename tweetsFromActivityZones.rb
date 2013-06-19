#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitterActivityZones.log')
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new  

log_time("Start time")

def pull_tweets

  @yml['ActivityZone'].each do | activityzone |
    activityzonename = activityzone[0]
    activityzonedetails = activityzone[1]
    activityzonedetails['timezone'] = @defaulttimezone unless activityzonedetails['timezone']

    log_time("Activity Zone: #{activityzonename}")
    log_time("Start = #{activityzonedetails['start']}, end = #{activityzonedetails['end']}, timezone = #{activityzonedetails['timezone']}")
    log_time("Current? #{activityzonedetails.is_current?.to_s}")

    if activityzonedetails.is_current?

      since_id = get_since_id(activityzonename)
      log_time("Since id: #{since_id}")
      
      activityzonedetails['areas'].each do | area |

        tweetdata = fetch_tweets_from_area(activityzonename, area, since_id)

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
