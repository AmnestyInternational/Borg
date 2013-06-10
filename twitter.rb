#!/usr/bin/env ruby
require_relative 'twitterAPIengine'

$LOG = Logger.new('log/twitter.log')   

log_time("Start time")

def pulltweets

  querycount = (@yml['SearchTerms'].length * @yml['Regions'].length)
  runfreq = @yml['Settings']['run_freq']
  starttime = Time.now
  secbetweenfetches = ( runfreq * 60 * 60 ) / querycount
  fetchcount = 0

  log_time("#{querycount} queries in #{runfreq} hours equals one fetch every #{secbetweenfetches} seconds")

  @yml['SearchTerms'].each do | search_term |

    @yml['Regions'].each do | region |

      log_time("polling: " + search_term.to_s + " from " + region[0].to_s)

      tweetdata = fetch_tweet_data(region, search_term)

      insert_tweets(tweetdata['tweets']) if tweetdata['tweetregions'].length > 0
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
pulltweets

log_time("End time\n\n\n")
