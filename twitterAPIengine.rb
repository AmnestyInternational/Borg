#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'tiny_tds'
require 'yaml'
require 'time'
require 'iconv'
require 'logger'
require 'twitter'

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

def setvars
  @yml = YAML::load(File.open('config/twitter.yml'))
  @result_type = @yml['Settings']['result_type']
  @returns_per_page = @yml['Settings']['returns_per_page']
  $ignoredwords = @yml['IgnoredWords']
  dbyml = YAML::load(File.open('config/db_settings.yml'))['prod_settings']
  @client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])
  log_time ("connected to #{dbyml['database']} on #{dbyml['host']}")

  tokens = YAML::load(File.open('config/api_tokens.yml'))['api_tokens']['twitter']
  Twitter.configure do |config|
    config.consumer_key = tokens['consumer_key']
    config.consumer_secret = tokens['consumer_secret']
    config.oauth_token = tokens['oauth_token']
    config.oauth_token_secret = tokens['oauth_token_secret']
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
    self.split(/\"|\.\"|[^a-z0-9]\'|\(|\)|\s+|[^a-z0-9]\s+|[^a-z0-9]\z+|\.\.+|$|^/imx).reject{ |s| $ignoredwords.include? s.downcase }.uniq
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

def insert_tweet_regions(regions)

  exit unless regions.length > 0

  log_time ("inserting #{regions.length} region(s)...")
  sql = String.new

  regions.each do | region |
    regionclean = region[:region].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM TweetRegions WHERE tweet_id = '#{region[:tweet_id]}' AND region = '#{regionclean}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT TweetRegions (tweet_id, region)
        VALUES (
          '#{region[:tweet_id]}',
          '#{regionclean}');\n"
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
    termclean = term[:term].to_s.to_esc_sql
    sql << "
      IF EXISTS (SELECT tweet_id FROM tweetsanatomize WHERE tweet_id = '#{term[:tweet_id]}' AND term = '#{termclean}')
        SELECT 'Do nothing' ;
      ELSE
        INSERT tweetsanatomize (tweet_id, term)
        VALUES (
          '#{term[:tweet_id]}',
          '#{termclean}');\n"
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

def fetch_tweet_data(region, search_term = '')

  regionname = region[0]
  lat = region[1]['area'][0]['lat']
  long = region[1]['area'][0]['long']
  range = region[1]['area'][0]['range']

  if search_term == ''
    result = @client.execute("
      SELECT MAX(id) 'max_id'
      FROM vAI_Tweets
      WHERE region = '#{regionname}'")
  else
    result = @client.execute("
      SELECT TOP 1 id 'max_id'
      FROM
        Tweets AS T
        LEFT JOIN
        TweetRegions AS TR
        ON T.id = TR.tweet_id
      WHERE
        TR.region = '#{regionname}' AND
        imported < DATEADD(HOUR, -12, GETDATE())
      ORDER BY imported DESC")
  end

  toprow = result.first
  since_id = toprow.nil? ? 0 : toprow['max_id'].to_i

  log_time("since_id = #{since_id}")

  log_time("query using: #{search_term}, :geocode => #{lat},#{long},#{range}, :count => #{@returns_per_page}, :result_type => #{@result_type}, :since_id => #{since_id}")

  rawtweetdata = Twitter.search(search_term, :geocode => "#{lat},#{long},#{range}", :count => @returns_per_page, :result_type => @result_type, :since_id => since_id).results

  log_time("returned tweets: " + rawtweetdata.length.to_s)
  
  tweetdata = Hash.new{|hash, key| hash[key] = Array.new}

  if rawtweetdata
    rawtweetdata.map! do | rawtweet |

      # Tweets
      coordinates = rawtweet.geo.nil? ? [] : rawtweet.geo.coordinates

      tweetdata['tweets'] << {
        :id => rawtweet.id,
        :usr_id => rawtweet.user.id,
        :coordinates => coordinates,
        :text => rawtweet.text.to_s,
        :created => Time.parse(rawtweet.created_at.to_s).to_s }
        
      # Twitterusers
      utc_offset = rawtweet.user.utc_offset.nil? ? nil : (rawtweet.user.utc_offset / (60 * 60) ).to_s
      created_at = rawtweet.user.created_at.nil? ? nil : Time.parse(rawtweet.user.created_at.to_s).to_s

      tweetdata['twitterusers'] << {
        :id => rawtweet.user.id,
        :screen_name => rawtweet.user.screen_name.to_s,
        :name => rawtweet.user.name.to_s,
        :location => rawtweet.user.location.to_s,
        :protected => rawtweet.user.protected.to_s,
        :verified => rawtweet.user.verified.to_s,
        :followers_count => rawtweet.user.followers_count.to_s,
        :friends_count => rawtweet.user.friends_count.to_s,
        :statuses_count => rawtweet.user.statuses_count.to_s,
        :time_zone => rawtweet.user.time_zone.to_s,
        :utc_offset => utc_offset,
        :profile_image_url => rawtweet.user.profile_image_url_https.to_s,
        :created_at => created_at }
        
      # Tweetsanatomize
      terms = rawtweet.text.to_s.anatomize
      terms.each do | term |
        term = term[0,32]
        tweetdata['tweetsanatomize'] << {
          :tweet_id => rawtweet.id,
          :term => term }
      end

      # Tweetusermentions
      if rawtweet.user_mentions
        rawtweet.user_mentions.map! do | mention |
          tweetdata['tweetusermentions'] << {
            :tweet_id => rawtweet.id,
            :usr_id => mention.id }
        end
      end

      # Tweethashtags
      if rawtweet.hashtags
        rawtweet.hashtags.map! do | hashtag |
          tweetdata['tweethashtags'] << {
            :tweet_id => rawtweet.id,
            :hashtag => hashtag.text[0,32] }
        end
      end
        
      # Tweeturls
      if rawtweet.urls
        rawtweet.urls.map! do | url |
          tweetdata['tweeturls'] << {
            :tweet_id => rawtweet.id,
            :url => url.expanded_url[0,256] }
        end
      end
        
      # Tweetregions
      tweetdata['tweetregions'] << {
        :tweet_id => rawtweet.id,
        :region => regionname[0,32] }

    end
  end

  return tweetdata
end
