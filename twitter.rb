#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'tiny_tds'
require 'yaml'
require 'time'
require 'iconv'
require 'logger'

$LOG = Logger.new('log/twitter.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start time")

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

def insert_tweets

  log_time ("inserting #{@tweet.length} tweet(s)...")

  @tweet.each do |tweet|
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

    #puts sql
    @client.execute(sql).do
  end

  @tweet = []
end

def fetch_tweets(region, search_term = nil)

  if search_term.nil?
    result = @client.execute("
      SELECT TOP 1 max_id
      FROM TweetsRefreshUrl
      WHERE city = '#{region[0]}' AND searchterm = '#{search_term}'")
  else
    result = @client.execute("
      SELECT TOP 1 id 'max_id'
      FROM Tweets
      WHERE city = '#{region[0]}'")
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
  tweets = JSON.parse(response)

  since_id = tweets["max_id"]

  @client.execute("
    IF EXISTS (SELECT max_id FROM TweetsRefreshUrl WHERE city = '#{region[0]}' AND searchterm = '#{search_term}')
      UPDATE TweetsRefreshUrl
      SET max_id = '#{since_id}'
      WHERE city = '#{region[0]}' AND searchterm = '#{search_term}';
    ELSE
      INSERT TweetsRefreshUrl (city, searchterm, max_id)
      VALUES ('#{region[0]}', '#{search_term}', '#{since_id}');\n").do

  return tweets
end

def pulltweets
  dbyml = YAML::load(File.open('yaml/db_settings.yml'))['prod_settings']
  @client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])

  @tweet = []

  @yml['SearchTerms'].each do | search_term |

    @yml['Cities'].each do | city |

      log_time("polling: " + search_term.to_s + " from " + city[0].to_s)

      tweets = fetch_tweets(city, search_term)
    
      log_time("returned tweets: " + tweets["results"].length.to_s)
    
      tweets["results"].each do | tweet |
        coordinates = tweet['geo'].nil? ? [] : tweet['geo']['coordinates'] # very few people seem to be geo tweeting but this will be useful in the future
    
        @tweet << {
          :id => tweet['id'],
          :created => Time.parse(tweet['created_at']),
          :usr => tweet['from_user'],
          :usr_id => tweet['from_user_id'],
          :usr_name => tweet['from_user_name'],
          :coordinates => coordinates,
          :city => city[0],
          :location => tweet['location'],
          :profile_image_url => tweet['profile_image_url'],
          :text => tweet['text']
        }
    
      end
  
    insert_tweets if @tweet.length > 0

    sleep 5 # We don't want to piss Twitter off by hounding their servers. We'll need to increase this once we have more cities and hash tags
    end

  end

  @yml['Hotspots'].each do | hotspot |
    log_time("polling: all tweets from " + hotspot[0].to_s)

    tweets = fetch_tweets(hotspot)

    log_time("returned tweets: " + tweets["results"].length.to_s)
    
    tweets["results"].each do | tweet |
      coordinates = tweet['geo'].nil? ? [] : tweet['geo']['coordinates'] # very few people seem to be geo tweeting but this will be useful in the future
    
      @tweet << {
        :id => tweet['id'],
        :created => Time.parse(tweet['created_at']),
        :usr => tweet['from_user'],
        :usr_id => tweet['from_user_id'],
        :usr_name => tweet['from_user_name'],
        :coordinates => coordinates,
        :city => hotspot[0],
        :location => tweet['location'],
        :profile_image_url => tweet['profile_image_url'],
        :text => tweet['text']
      }
    end
  
    insert_tweets if @tweet.length > 0

    sleep 5 # We don't want to piss Twitter off by hounding their servers. We'll need to increase this once we have more cities and hash tags

  end

end

def setvars
  @yml = YAML::load(File.open('yaml/twitter.yml'))
  @result_type = @yml['Settings']['result_type']
  @returns_per_page = @yml['Settings']['returns_per_page']
  $ignoredwords = @yml['IgnoredWords']
end

setvars
pulltweets

log_time("End time\n\n\n")

#   uri = URI("http://search.twitter.com/search.json?q=%23bieber&rpp=100") # for testing, bieber gets more tweets then us :(
