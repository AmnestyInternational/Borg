#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitter_campaigns.log')
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new   

log_time("Start time")

def pull_tweets

  @yml['Campaigns'].each do | campaign |
    campaignname = campaign[0]
    campaigndetails = campaign[1]
    campaigndetails['timezone'] = @default_timezone unless campaigndetails['timezone']

    log_time("Campaign: #{campaignname}")
    log_time("Start = #{campaigndetails['start']}, end = #{campaigndetails['end']}, timezone = #{campaigndetails['timezone']}")
    log_time("Current? #{campaigndetails.is_current?.to_s}")

    if campaigndetails.is_current?

      campaigndetails['Search terms'].each do | search_term |

        @yml['Regions'].each do | region |

          regionname = region[0]
          area = region[1]['areas'][0]

          since_id = get_since_id(regionname, search_term)

          log_time("polling: #{search_term} from #{regionname} since #{since_id}")

          tweetdata = fetch_tweets_from_area(regionname, area, since_id, search_term)

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

        end
      end
    end
  end
end

setvars
pull_tweets

log_time("End time\n\n\n")
