#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitter.log')   

log_time("Start time")

def pull_tweets

  querycount = (@yml['SearchTerms'].length * @yml['Regions'].length)
  runfreq = @yml['Settings']['run_freq']
  starttime = Time.now
  secbetweenfetches = ( runfreq * 60 * 60 ) / querycount
  fetchcount = 0

  log_time("#{querycount} queries in #{runfreq} hours equals one fetch every #{secbetweenfetches} seconds")

  @yml['SearchTerms'].each do | search_term |

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

      fetchcount += 1
      if querycount >= fetchcount
        log_time("waiting #{((starttime + (secbetweenfetches * fetchcount)) - Time.now).to_i} seconds before next fetch")
        sleep(1) until Time.now > (starttime + (secbetweenfetches * fetchcount))
      end

    end

  end

end

setvars
pull_tweets

log_time("End time\n\n\n")
