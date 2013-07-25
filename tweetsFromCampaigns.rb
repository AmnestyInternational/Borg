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
    log_time("Current campaign? #{campaigndetails.is_current?}\n\n")

    if campaigndetails.is_current?

      unless campaigndetails['Search terms'].nil?

        log_time("Collecting search terms\n\n")

        campaigndetails['Search terms'].each do | search_term |

          @yml['Regions'].each do | region |

            regionname = region[0]
            area = region[1]['areas'][0]

            since_id = get_since_id(regionname, search_term)

            log_time("Polling: #{search_term} from #{regionname} since #{since_id}")

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

            log_time("Finished polling: #{search_term} from #{regionname}\n\n")

          end
        end
        log_time("Finished collecting search terms\n\n\n")
      end

      unless campaigndetails['Users'].nil?

        log_time("Collecting users tweets\n\n")

        totalusers = campaigndetails['Users'].length
        log_time("#{totalusers} users in Yaml file")
        count = 0

        campaigndetails['Users'].each do | screen_name |
          max_id = nil
          count += 1
          user_details = lookup_twitter_user(screen_name)
          log_time("User does not exist", "error") if user_details.nil?
          next if user_details.nil?
          since_id = fetch_user_since_id(user_details)
          log_time("#{user_details[:screen_name]} is #{count} of #{totalusers}")
          log_time("#{user_details[:screen_name]} has #{user_details[:statuses_count].to_s} tweets, collecting...")

          tweetscount = 0

          loop do

            tweetdata = fetch_user_timeline(screen_name, since_id, max_id)
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
          log_time("#{tweetscount} collected for #{screen_name}\n\n")
        end
        log_time("Finished collecting users tweets\n\n")
      end
    end
  end
end

setvars
pull_tweets

log_time("End time\n\n\n\n")
