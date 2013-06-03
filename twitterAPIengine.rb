#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'tiny_tds'
require 'yaml'
require 'time'
require 'iconv'
require 'logger'

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
          INSERT tweets (id, usr, usr_id, usr_name, city, location, geo, profile_image_url, text, created)
          VALUES (
            '#{tweet[:id]}',
            '#{tweet[:usr].to_s.to_esc_sql}',
            '#{tweet[:usr_id]}',
            '#{tweet[:usr_name].to_s.to_esc_sql}',
            '#{tweet[:city]}',
            '#{tweet[:location].to_s.to_esc_sql}',
            CASE WHEN '#{tweet[:coordinates][0]}' = '' THEN
              NULL
            ELSE
              geography::STPointFromText('POINT(' + CAST('#{tweet[:coordinates][1]}' AS VARCHAR(20)) + ' ' + CAST('#{tweet[:coordinates][0]}' AS VARCHAR(20)) + ')', 4326)
            END,
            '#{tweet[:profile_image_url]}',
            '#{tweet[:text].to_s.to_esc_sql}',
            CONVERT(DATETIME, LEFT('#{tweet[:created]}', 19))
            );\n"
      
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

def fetch_tweets(region, search_term = nil)

  if search_term.nil?
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
  since_id = toprow.nil? ? 0 : toprow['max_id']

  log_time("since_id = #{since_id}")

  if search_term.nil?
    url = "http://search.twitter.com/search.json?geocode=#{region[1]['lat']},#{region[1]['long']},#{region[1]['range']}&result_type=#{@result_type}&rpp=#{@returns_per_page}&since_id=#{since_id}"
  else
    url = "http://search.twitter.com/search.json?geocode=#{region[1]['lat']},#{region[1]['long']},#{region[1]['range']}&result_type=#{@result_type}&q=#{search_term.clean_term}&rpp=#{@returns_per_page}&since_id=#{since_id}"
  end
  
  log_time(url)
  
  uri = URI(url)
  response = Net::HTTP.get(uri)
  rawtweetdata = JSON.parse(response)

  log_time("returned tweets: " + rawtweetdata["results"].length.to_s)

  unless search_term.nil?
    since_id = rawtweetdata["max_id"]

    @client.execute("
      IF EXISTS (SELECT max_id FROM TweetsRefreshUrl WHERE city = '#{region[0]}' AND searchterm = '#{search_term}')
        UPDATE TweetsRefreshUrl
        SET max_id = '#{since_id}'
        WHERE city = '#{region[0]}' AND searchterm = '#{search_term}';
      ELSE
        INSERT TweetsRefreshUrl (city, searchterm, max_id)
        VALUES ('#{region[0]}', '#{search_term}', '#{since_id}');\n").do

    log_time("since_id set to #{since_id}")
  end
  
  tweets = []
  
  rawtweetdata["results"].each do | rawtweet |

    coordinates = rawtweet['geo'].nil? ? [] : rawtweet['geo']['coordinates'] # very few people seem to be geo tweeting but this will be useful in the future
    
    tweets << {
      :id => rawtweet['id'],
      :created => Time.parse(rawtweet['created_at']),
      :usr => rawtweet['from_user'],
      :usr_id => rawtweet['from_user_id'],
      :usr_name => rawtweet['from_user_name'],
      :coordinates => coordinates,
      :city => region[0],
      :location => rawtweet['location'],
      :profile_image_url => rawtweet['profile_image_url'],
      :text => rawtweet['text']
    }

  end

  return tweets
end
