#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitterFollowersInnitialPull.log')
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new

log_time("Start time")

# test cases
#user = 'kaanmentes' # 200
#user = 'mavigozluev' # 400
#user = 'aylincoskun' # 4590
#user = 'ugurtotales' # 9530
#user = 'Joaquin_Pereira' # 51780
#user = 'salmasaid' # 101209
#user = 'Ceyda_duvenci' # 415103
#user = 'ADEL_FELAIFIL' # 423000
#user = 'RT_Erdogan' # 3189000
#user = 'cbabdullahgul' # 3522000

users = ['RT_Erdogan','cbabdullahgul']

setvars

users.each do | user |
  userdetails = lookup_twitter_user(user)
  log_time("#{user} has #{userdetails['followers_count']} followers")

  cursor = -1
  followerscount = 0

  loop do
    followersdata = fetch_follower_ids(userdetails['id'], cursor)

    insert_twitter_user_followers(followersdata['tweetfollowerids']) if followersdata['tweetfollowerids'].length > 0

    cursor = followersdata['next_cursor']
    followerscount += followersdata['tweetfollowerids'].length

    log_time("#{followersdata['tweetfollowerids'].length.to_s} follower ids added for #{user}, #{((followerscount.to_f/userdetails['followers_count'].to_f)*100).round(2)}% complete...")

    break if followersdata['tweetfollowerids'].empty?
    log_time("waiting #{(followersdata['nextrun'] - Time.now).to_i} seconds before next fetch")
    sleep(1) until Time.now > followersdata['nextrun']
  end

  log_time("#{followerscount} followers added for user #{user}\n")
end

log_time("End time\n\n\n")
