#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'tiny_tds'
require 'yaml'
require 'time'
require 'iconv'
require 'logger'
require 'twitter'
require 'active_support/all'
require 'oauth'

def log_time(input, type = 'info')
  puts Time.now.to_s + ", " + input
  type == 'error' ? $LOG.error(input) : $LOG.info(input)
end

def loadyaml(yaml)
  log_time("loading #{yaml}")
  begin
    return YAML::load(File.open(yaml))
  rescue Exception => e
    log_time("error loading #{yaml} - #{e.message}", 'error')
  end
end

def setvars
  log_time('setting variables')

  @sql_insert_batch_size = 100
  @yml = loadyaml('config/twitter.yml')

  begin
    @result_type = @yml['Settings']['result type']
  rescue Exception => e
    @result_type = 'recent'
    log_time("error loading result type! #{e.message}. Using #{@result_type} as result_type", 'error')
  end

  begin
    @returns_per_page = @yml['Settings']['returns per page']
  rescue Exception => e
    @returns_per_page = 100
    log_time("error loading returns per page! #{e.message}. Using #{@returns_per_page} as returns per page", 'error')
  end

  begin
    @default_timezone = @yml['Settings']['default timezone']
  rescue Exception => e
    @default_timezone = 'Eastern Time (US & Canada)'
    log_time("error loading default timezone! #{e.message}. using #{@default_timezone} as default timezone", 'error')
  end

  begin
    $ignored_words = @yml['Ignored words']
  rescue Exception => e
    $ignored_words = []
    log_time("error loading ignored words! #{e.message}. Using empty array as ignored words", 'error')
  end

  dbyml = loadyaml('config/db_settings.yml')['prod_settings']
  log_time("error loading prod settings!", 'error') if dbyml == nil

  begin
    @client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'], :timeout => 30000)
  rescue Exception => e
    log_time("error connecting to database! #{e.message}", 'error')
    log_time("graceful exit\n\n")
    exit
  end
  log_time("connected to #{dbyml['database']} on #{dbyml['host']}")

  @tokens = loadyaml('config/api_tokens.yml')['twitter']
  log_time("error loading twitter api token!", 'error') if @tokens == nil

  Twitter.configure do |config|
    config.consumer_key = @tokens['consumer_key']
    config.consumer_secret = @tokens['consumer_secret']
    config.oauth_token = @tokens['oauth_token']
    config.oauth_token_secret = @tokens['oauth_token_secret']
  end

  log_time("Preparing oauth token")
  consumer = OAuth::Consumer.new(@tokens['consumer_key'], @tokens['consumer_secret'],
    { :site => "http://api.twitter.com",
      :scheme => :header
    })

  token_hash = { :oauth_token => @tokens['oauth_token'],
                 :oauth_token_secret => @tokens['oauth_token_secret']
               }
  @access_token = OAuth::AccessToken.from_hash(consumer, token_hash )
end

class Hash
  def is_current?
    Time.zone = self['timezone']
    Time.zone.parse(self['start'].to_s) <= Time.now && Time.zone.parse(self['end'].to_s) >= Time.now
  end
end

class String
  def to_esc_sql
    Iconv.iconv('ascii//ignore//translit', 'utf-8', self)[0].to_s.gsub("'","''")
  end

  def nil_to_null
    self.nil? || self == '0' || self.empty? ? 'NULL' : "'#{self}'"
  end

  def false_to_bit
    self == 'true' ? '1' : '0'
  end

  def anatomize
    self.split(/\"|\.\"|[^a-z0-9]\'|\(|\)|\s+|[^a-z0-9]\s+|[^a-z0-9]\z+|\.\.+|$|^/imx).reject{ |s| $ignored_words.include? s.downcase }.uniq
  end
end

def insert_tweet_user_mentions(user_mentions)

  exit unless user_mentions.length > 0

  log_time ("inserting #{user_mentions.length} user_mentions(s)...")
  sql = String.new

  user_mentions.each do | user_mention |
    sql << "
      IF EXISTS (SELECT tweet_id FROM TweetUserMentions WHERE tweet_id = '#{user_mention[:tweet_id]}' AND usr_id = '#{user_mention[:usr_id]}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT TweetUserMentions (tweet_id, usr_id)
        VALUES (
          '#{user_mention[:tweet_id]}',
          '#{user_mention[:usr_id]}');\n"
  end

  @client.execute(sql).do

end

def insert_tweet_hashtags(hashtags)

  exit unless hashtags.length > 0

  log_time ("inserting #{hashtags.length} hashtags(s)...")
  sql = String.new

  hashtags.each do | hashtag |
    hashtagclean = hashtag[:hashtag].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM TweetHashtags WHERE tweet_id = '#{hashtag[:tweet_id]}' AND hashtag = '#{hashtagclean}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT TweetHashtags (tweet_id, hashtag)
        VALUES (
          '#{hashtag[:tweet_id]}',
          '#{hashtagclean}');\n"
  end

  @client.execute(sql).do

end

def insert_tweet_urls(urls)

  exit unless urls.length > 0

  log_time ("inserting #{urls.length} url(s)...")
  sql = String.new

  urls.each do | url |
    urlclean = url[:url].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM Tweeturls WHERE tweet_id = '#{url[:tweet_id]}' AND url = '#{urlclean}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT Tweeturls (tweet_id, url)
        VALUES (
          '#{url[:tweet_id]}',
          '#{urlclean}');\n"
  end

  @client.execute(sql).do

end

def insert_twitter_user_followers(user_followers)

  exit unless user_followers.length > 0

  log_time ("#{user_followers.length} user_follower(s) relationships to insert / update...")

  # This is a special case insert because it can be quite large so they are inserted in groups of 100 with a 1 second sleep inbetween

  user_followers_batches = user_followers.each_slice(@sql_insert_batch_size).to_a

  log_time ("user_followers array split into #{user_followers_batches.length} part(s)...")

  count = 0

  user_followers_batches.each do | user_followers_batch |

    count += user_followers_batch.length

    sql = String.new

    user_followers_batch.each do | user_follower |
      sql << "
        IF EXISTS (SELECT usr_id FROM TwitterFollowers WHERE usr_id = '#{user_follower[:usr_id].to_s}' AND followers_usr_id = '#{user_follower[:followers_usr_id].to_s}')
          SELECT 'Do nothing' ;
        ELSE
          INSERT TwitterFollowers (usr_id, followers_usr_id)
          VALUES (
            '#{user_follower[:usr_id].to_s}',
            '#{user_follower[:followers_usr_id].to_s}');\n"
    end

    @client.execute(sql).do

    log_time ("inserted / updated #{user_followers_batch.length} user_follower(s) relationships, #{((count.to_f/user_followers.length.to_f)*100).round(2)}% complete...")

    sleep 0.5

  end

end

def insert_tweet_regions(regions)

  exit unless regions.length > 0

  log_time ("inserting #{regions.length} region(s)...")
  sql = String.new

  regions.each do | region |
    region_name = region[:region].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM TweetRegions WHERE tweet_id = '#{region[:tweet_id]}' AND region = '#{region_name}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT TweetRegions (tweet_id, region)
        VALUES (
          '#{region[:tweet_id]}',
          '#{region_name}');\n"
  end

  @client.execute(sql).do

end

def insert_twitter_users(users)

  exit unless users.length > 0

  log_time ("inserting / updating #{users.length} users(s)...")
  sql = String.new

  users.each do | user |
    id = user[:id].to_s.to_esc_sql.nil_to_null
    screen_name = user[:screen_name].to_s.to_esc_sql.nil_to_null
    name = user[:name].to_s.to_esc_sql.nil_to_null
    location = user[:location].to_s.to_esc_sql.nil_to_null
    protected = user[:protected].to_s.to_esc_sql.false_to_bit
    verified = user[:verified].to_s.to_esc_sql.false_to_bit
    followers_count = user[:followers_count].to_s.to_esc_sql.nil_to_null
    friends_count = user[:friends_count].to_s.to_esc_sql.nil_to_null
    statuses_count = user[:statuses_count].to_s.to_esc_sql.nil_to_null
    time_zone = user[:time_zone].to_s.to_esc_sql.nil_to_null
    utc_offset = user[:utc_offset].to_s.to_esc_sql.nil_to_null
    profile_image_url = user[:profile_image_url].to_s.to_esc_sql.nil_to_null
    created_at = user[:created_at].to_s.to_esc_sql.nil_to_null

    sql << "
      IF EXISTS (SELECT id FROM TwitterUsers WHERE id = #{id})
        UPDATE TwitterUsers
        SET
          screen_name = #{screen_name},
          name = #{name},
          location = #{location},
          protected = #{protected},
          verified = #{verified},
          followers_count = #{followers_count},
          friends_count = #{friends_count},
          statuses_count = #{statuses_count},
          time_zone = #{time_zone},
          utc_offset = #{utc_offset},
          profile_image_url = #{profile_image_url},
          created_at = CONVERT(DATETIME, LEFT(#{created_at}, 19)),
          updated_at = GETDATE()
        WHERE id = '10777082';
      ELSE
        INSERT TwitterUsers (id, screen_name, name, location, protected, verified, followers_count, friends_count, statuses_count, time_zone, utc_offset, profile_image_url, created_at)
        VALUES (
          #{id},
          #{screen_name},
          #{name},
          #{location},
          #{protected},
          #{verified},
          #{followers_count},
          #{friends_count},
          #{statuses_count},
          #{time_zone},
          #{utc_offset},
          #{profile_image_url},
          CONVERT(DATETIME, LEFT(#{created_at}, 19)) );
    \n"
  end

  @client.execute(sql).do

end

def insert_tweets_anatomized(terms)

  exit unless terms.length > 0

  log_time ("inserting #{terms.length} anatomized term(s)...")
  sql = String.new

  terms.each do | term |
    cleaned_term = term[:term].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM tweetsanatomize WHERE tweet_id = '#{term[:tweet_id]}' AND term = '#{cleaned_term}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT tweetsanatomize (tweet_id, term)
        VALUES (
          '#{term[:tweet_id]}',
          '#{cleaned_term}');\n"
  end

  @client.execute(sql).do

end

def insert_tweets(tweets)

  exit unless tweets.length > 0

  log_time ("inserting #{tweets.length} tweet(s)...")

  sql = String.new

  tweets.each do | tweet |
    sql << "
      IF EXISTS (SELECT id FROM Tweets WHERE id = '#{tweet[:id]}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT Tweets (id, usr_id, coordinates, text, created)
        VALUES (
          '#{tweet[:id]}',
          '#{tweet[:usr_id]}',
          CASE WHEN '#{tweet[:coordinates][0]}' = '' THEN
            NULL
          ELSE
            geography::STPointFromText('POINT(' + CAST('#{tweet[:coordinates][1]}' AS VARCHAR(20)) + ' ' + CAST('#{tweet[:coordinates][0]}' AS VARCHAR(20)) + ')', 4326)
          END,
          '#{tweet[:text].to_s.to_esc_sql}',
          CONVERT(DATETIME, LEFT('#{tweet[:created]}', 19))
          );\n"
  end

  @client.execute(sql).do

end

def get_since_id(region_name, search_term = nil)
  if search_term == nil
    result = @client.execute("
      SELECT MAX(id) 'max_id'
      FROM vAI_Tweets
      WHERE region = '#{region_name}'")
  else
    result = @client.execute("
      SELECT TOP 1 id 'max_id'
      FROM
        Tweets AS T
        LEFT JOIN
        TweetRegions AS TR
        ON T.id = TR.tweet_id
      WHERE
        TR.region = '#{region_name}' AND
        imported < DATEADD(HOUR, -12, GETDATE())
      ORDER BY imported DESC")
  end

  top_row = result.first
  top_row.nil? ? 0 : top_row['max_id'].to_i
end

def fetch_tweets_from_area(region_name, area, since_id, search_term = '')

  lat = area['lat']
  long = area['long']
  range = area['range']

  parameters = { :geocode => "#{lat},#{long},#{range}", :count => @returns_per_page, :result_type => @result_type, :since_id => since_id }

  log_time("query using: search term '#{search_term}' and parameters '#{parameters.to_s}'")

  raw_tweet_data = Twitter.search( search_term, parameters ).results

  log_time("returned tweets: #{raw_tweet_data.length}")

  return organise_raw_tweet_data(raw_tweet_data, region_name)

end

def organise_raw_tweet_data(raw_tweet_data, region_name = nil)

  log_time("Organising #{raw_tweet_data.length} tweets")

  organised_data = Hash.new{|hash, key| hash[key] = Array.new}

  organised_data['max_id'] = organised_data['since_id'] = 0

  if raw_tweet_data
    raw_tweet_data.map! do | raw_tweet |

      organised_data['max_id'] = ( raw_tweet.id - 1 ) if (raw_tweet.id <= organised_data['max_id'] || organised_data['max_id'] == 0)
      organised_data['since_id'] = ( raw_tweet.id  + 1 ) if raw_tweet.id >= organised_data['since_id']

      # Tweets
      coordinates = raw_tweet.geo.nil? ? [] : raw_tweet.geo.coordinates

      organised_data['tweets'] << {
        :id => raw_tweet.id,
        :usr_id => raw_tweet.user.id,
        :coordinates => coordinates,
        :text => raw_tweet.text,
        :source => raw_tweet.source,
        :truncated => raw_tweet.truncated,
        :in_reply_to_status_id => raw_tweet.in_reply_to_status_id,
        :in_reply_to_user_id => raw_tweet.in_reply_to_user_id,
        :retweet_count => raw_tweet.retweet_count,
        :favorite_count => raw_tweet.favorite_count,
        :place => raw_tweet.place,
        :lang => raw_tweet.lang,
        :created => Time.parse(raw_tweet.created_at.to_s).to_s }
        
      # Twitterusers
      utc_offset = raw_tweet.user.utc_offset.nil? ? nil : (raw_tweet.user.utc_offset / (60 * 60) ).to_s
      created_at = raw_tweet.user.created_at.nil? ? nil : Time.parse(raw_tweet.user.created_at.to_s).to_s

      organised_data['twitterusers'] << {
        :id => raw_tweet.user.id,
        :screen_name => raw_tweet.user.screen_name,
        :name => raw_tweet.user.name,
        :location => raw_tweet.user.location,
        :description => raw_tweet.user.description,
        :protected => raw_tweet.user.protected.to_s,
        :verified => raw_tweet.user.verified.to_s,
        :followers_count => raw_tweet.user.followers_count,
        :friends_count => raw_tweet.user.friends_count,
        :statuses_count => raw_tweet.user.statuses_count,
        :favourites_count => raw_tweet.user.favourites_count,
        :time_zone => raw_tweet.user.time_zone,
        :utc_offset => utc_offset,
        :profile_image_url => raw_tweet.user.profile_image_url_https,
        :created_at => created_at }
        
      # Tweetsanatomize
      terms = raw_tweet.text.to_s.anatomize
      terms.each do | term |
        term = term[0,32]
        organised_data['tweetsanatomize'] << {
          :tweet_id => raw_tweet.id,
          :term => term }
      end

      # Tweetusermentions
      if raw_tweet.user_mentions
        raw_tweet.user_mentions.map! do | mention |
          organised_data['tweetusermentions'] << {
            :tweet_id => raw_tweet.id,
            :usr_id => mention.id }
        end
      end

      # Tweethashtags
      if raw_tweet.hashtags
        raw_tweet.hashtags.map! do | hashtag |
          organised_data['tweethashtags'] << {
            :tweet_id => raw_tweet.id,
            :hashtag => hashtag.text[0,32] }
        end
      end
        
      # Tweeturls
      if raw_tweet.urls
        raw_tweet.urls.map! do | url |
          organised_data['tweeturls'] << {
            :tweet_id => raw_tweet.id,
            :url => url.expanded_url[0,256] }
        end
      end
      
      # Tweetregions
      if region_name
        organised_data['tweetregions'] << {
          :tweet_id => raw_tweet.id,
          :region => region_name[0,32] }
      end
    end
  end

  organised_data['twitterusers'] = organised_data['twitterusers'].uniq { |h| h[:id] }

  log_time("#{raw_tweet_data.length} tweets organised into #{organised_data['tweets'].length} tweets, #{organised_data['twitterusers'].length} users, #{organised_data['tweetsanatomize'].length} words, #{organised_data['tweetusermentions'].length} user mentions, #{organised_data['tweethashtags'].length} hashtags, #{organised_data['tweeturls'].length} urls, #{organised_data['tweetregions'].length} region connections.")

  return organised_data
end

def lookup_twitter_user(screen_name)
  log_time("Querring Twitter.user for #{screen_name} details")
  user = Array.new
  rawuserdata = Twitter.user(screen_name)

  utc_offset = rawuserdata.utc_offset.nil? ? nil : (rawuserdata.utc_offset / (60 * 60) ).to_s
  created_at = rawuserdata.created_at.nil? ? nil : Time.parse(rawuserdata.created_at.to_s).to_s

  user << {
    :id => rawuserdata.id,
    :screen_name => rawuserdata.screen_name.to_s,
    :name => rawuserdata.name.to_s,
    :location => rawuserdata.location.to_s,
    :protected => rawuserdata.protected.to_s,
    :verified => rawuserdata.verified.to_s,
    :followers_count => rawuserdata.followers_count.to_s,
    :friends_count => rawuserdata.friends_count.to_s,
    :statuses_count => rawuserdata.statuses_count.to_s,
    :time_zone => rawuserdata.time_zone.to_s,
    :utc_offset => utc_offset,
    :profile_image_url => rawuserdata.profile_image_url_https.to_s,
    :created_at => created_at }

  insert_twitter_users(user) if user.length > 0

  log_time("#{user[0].inspect}")

  return user[0]
end

def save_data(inputdata, filename)
  open("tmp/#{filename}.yml", 'w') {|f| YAML.dump(inputdata, f)}
  loaded = open("tmp/#{filename}.yml") {|f| YAML.load(f) }
  log_time("tmp/#{filename}.yml created with #{inputdata['tweetfollowerids'].length.to_s} records")
end

def load_data(filename)
  file = YAML::load(File.open("tmp/#{filename}.yml"))
  log_time("#{file['tweetfollowerids'].length.to_s} records loaded from tmp/#{filename}.yml")
  return file
end

def fetch_follower_ids(usr_id, cursor = -1, count = 5000)
  log_time("fetching follower_ids of usr_id #{usr_id.to_i} with cursor #{cursor.to_i} using https://api.twitter.com/1.1/followers/ids.json?cursor=#{cursor}&user_id=#{usr_id}&count=#{count}")

  rawfollowersdata = JSON.parse(@access_token.request(:get, "https://api.twitter.com/1.1/followers/ids.json?cursor=#{cursor}&user_id=#{usr_id}&count=#{count}").body)

  log_time("#{rawfollowersdata['ids'].length} ids fetched")

  tweetdata = Hash.new{|hash, key| hash[key] = Array.new}

  if rawfollowersdata['ids']
    rawfollowersdata['ids'].each do | followerid |

      # Tweetfollowerids
      tweetdata['tweetfollowerids'] << {
        :usr_id => usr_id,
        :followers_usr_id => followerid }
    end
  end

  tweetdata['nextrun'] = Time.now + 60
  tweetdata['next_cursor'] = rawfollowersdata['next_cursor']
  tweetdata['previous_cursor'] = rawfollowersdata['previous_cursor']

  return tweetdata
end

def fetch_user_timeline(user, since_id = nil, max_id = nil)
  parameters = Hash.new
  parameters[:count] = 200
  parameters[:max_id] = max_id unless max_id.nil?
  parameters[:since_id] = since_id unless since_id.nil?

  log_time("Polling Twitter API for tweets by #{user} using parameters: #{parameters.to_s}")

  tweetdata = organise_raw_tweet_data(Twitter.user_timeline(user, parameters))
  tweetdata['nextrun'] = Time.now + 60
  return tweetdata
end

def fetch_user_since_id(user_details)
  log_time("Looking up the max since_id for #{user_details['screen_name']} from TwitterUsers Table")
  result = @client.execute("
    SELECT MAX(id) 'since_id'
    FROM Tweets
    WHERE
      usr_id = '#{user_details[:id].to_s}' AND
      id NOT IN (SELECT tweet_id FROM TweetRegions)")

  toprow = result.first
  since_id = toprow.empty? ? nil : toprow['since_id'].to_i
  log_time("Max since_id #{since_id}")
  return since_id
end
