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

  tokens = YAML::load(File.open('config/api_tokens.yml'))['api_tokens']['twitter']
  Twitter.configure do |config|
    config.consumer_key = tokens['consumer_key']
    config.consumer_secret = tokens['consumer_secret']
    config.oauth_token = tokens['oauth_token']
    config.oauth_token_secret = tokens['oauth_token_secret']
  end

end

class String
  def clean_term
    self.to_s.gsub(/[@# ]/, '@' => '%40', '#' => '%23', ' ' => '+')
  end

  def to_esc_sql
    Iconv.iconv('ascii//ignore//translit', 'utf-8', self)[0].to_s.gsub("'","''")
  end

  def anatomize
    self.split(/\"|\.\"|[^a-z0-9]\'|\(|\)|\s+|[^a-z0-9]\s+|[^a-z0-9]\z+|\.\.+|$|^/imx).reject{ |s| $ignoredwords.include? s.downcase }.uniq
  end
end

def insert_tweets(tweets)

  exit unless tweets.length > 0

  log_time ("inserting #{tweets.length} tweet(s)...")

  tweets.each do | tweet |
    sql = "
        IF EXISTS (SELECT id FROM tweets WHERE id = '#{tweet[:id]}')
          SELECT 'Do nothing' ;
        ELSE
          INSERT tweets (id, usr, usr_id, usr_name, city, location, profile_image_url, text, created)
          VALUES (
            '#{tweet[:id]}',
            '#{tweet[:usr].to_s.to_esc_sql}',
            '#{tweet[:usr_id]}',
            '#{tweet[:usr_name].to_s.to_esc_sql}',
            '#{tweet[:city]}',
            '#{tweet[:location].to_s.to_esc_sql}',
            '#{tweet[:profile_image_url]}',
            '#{tweet[:text].to_s.to_esc_sql}',
            CONVERT(DATETIME, LEFT('#{tweet[:created]}', 19))
            );\n"

#            geo,

#            CASE WHEN '#{tweet[:coordinates][0]}' = '' THEN
#              NULL
#            ELSE
#              geography::STPointFromText('POINT(' + CAST('#{tweet[:coordinates][1]}' AS VARCHAR(20)) + ' ' + CAST('#{tweet[:coordinates][0]}' AS VARCHAR(20)) + ')', 4326)
#            END,
      
      terms = tweet[:text].anatomize
      
      terms.each do |term|
        term = term[0,32].to_esc_sql
        sql << "
          IF EXISTS (SELECT tweet_id FROM tweetsanatomize WHERE tweet_id = '#{tweet[:id]}' AND term = '#{term}')
            SELECT 'Do nothing' ;
          ELSE
            INSERT tweetsanatomize (tweet_id, term)
            VALUES (
              '#{tweet[:id]}',
              '#{term}');\n"
      end
    
    @client.execute(sql).do
  end

end

def fetch_tweets(region, search_term = '')

  if search_term = ''
    result = @client.execute("
      SELECT MAX(id) 'max_id'
      FROM Tweets
      WHERE city = '#{region[0]}'")
  else
    result = @client.execute("
      SELECT TOP 1 max_id
      FROM TweetsRefreshUrl
      WHERE city = '#{region[0]}' AND searchterm = '#{search_term}'")
  end

  toprow = result.first
  since_id = toprow.nil? ? 0 : toprow['max_id'].to_i

  log_time("since_id = #{since_id}")

  rawtweetdata = Twitter.search(search_term.clean_term, :geocode => "#{region[1]['lat']},#{region[1]['long']},#{region[1]['range']}", :count => @returns_per_page, :result_type => @result_type, :since_id => since_id).results #since_id not working

  log_time("returned tweets: " + rawtweetdata.length.to_s)
  
  tweets = []

  if rawtweetdata
    rawtweetdata.map! do | rawtweet |

      tweets << {
      :id => rawtweet.id,
      :created => Time.parse(rawtweet.created_at.to_s),
      :usr => rawtweet.user.screen_name,
      :usr_id => rawtweet.user.id,
      :usr_name => rawtweet.user.name,
      :coordinates => rawtweet.geo, #not working atm
      :city => region[0],
      :location => rawtweet.user.location,
      :profile_image_url => rawtweet.user.profile_image_url_https,
      :text => rawtweet.text
    }
    end
  end

  return tweets
end
