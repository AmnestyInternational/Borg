#!/usr/bin/env ruby
require_relative 'lib/twitterAPIengine'

$LOG = Logger.new('log/twitterInnitialUserPull.log')

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

users = ['RT_Erdogan']

setvars

users.each do | user |
  usr_id = lookup_twitter_user(user)['id']
  log_time("fetching #{user} with #{usr_id}")

  followersdata = fetch_follower_ids(usr_id)
  save_data(followersdata, user)
  #followersdata = loaddata(user)
  #insert_twitter_user_followers(followersdata['tweetfollowerids']) if followersdata['tweetfollowerids'].length > 0

  log_time("previous cursor #{followersdata['previous_cursor']}")
  log_time("next cursor #{followersdata['next_cursor']}")
  log_time("follower ids added = #{followersdata['tweetfollowerids'].length.to_s}\n\n")
end

log_time("End time\n\n\n")
