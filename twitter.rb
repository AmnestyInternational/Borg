#!/usr/bin/env ruby
require 'json'
require 'net/http'
require 'tiny_tds'
require 'yaml'
require 'time'
require 'iconv'
require 'logger'

# variables
@result_type = 'recent'
@returns_per_page = '100'

$LOG = Logger.new('log/twitter.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start time")

def sql_escape(input)
  Iconv.iconv('ascii//ignore//translit', 'utf-8', input)[0].to_s.gsub("'","''")
end

class String
  def clean_term
    self.to_s.gsub(/[@# ]/, '@' => '%40', '#' => '%23', ' ' => '+')
  end
end

def insert_tweets

  log_time ("inserting #{@tweet.length} tweet(s)...")

  @tweet.each do |tweet|

    @client.execute("
        IF EXISTS (SELECT id FROM tweets WHERE id = '#{tweet[:id]}')
          SELECT 'Do nothing' ;
        ELSE
          INSERT tweets (id, usr, usr_id, usr_name, city, location, geo, profile_image_url, text, created)
          VALUES (
            '#{tweet[:id]}',
            '#{sql_escape(tweet[:usr])}',
            '#{tweet[:usr_id]}',
            '#{sql_escape(tweet[:usr_name])}',
            '#{tweet[:city]}',
            '#{sql_escape(tweet[:location])}',
            CASE WHEN '#{tweet[:coordinates][0]}' = '' THEN
              NULL
            ELSE
              geography::STPointFromText('POINT(' + CAST('#{tweet[:coordinates][1]}' AS VARCHAR(20)) + ' ' + CAST('#{tweet[:coordinates][0]}' AS VARCHAR(20)) + ')', 4326)
            END,
            '#{tweet[:profile_image_url]}',
            '#{sql_escape(tweet[:text])}',
            CONVERT(DATETIME, LEFT('#{tweet[:created]}', 19))
            );").do
  end

  @tweet = []
end

def get_min_since_id
  # There are issues deducing the since_id for urls because of URL shortening so this will give us a minimum since_id
  result = @client.execute("
    SELECT TOP 1 id
    FROM tweets
    WHERE imported < DATEADD(MINUTE, -90, GETDATE())
    ORDER BY id DESC")

  row = result.each(:first => true)
  @since_id = row.empty? ? 0 : row[0]['id']
end

def fetch_tweets(city, serach_term)
  result = @client.execute("
    SELECT TOP 1 id
    FROM tweets
    WHERE city = '#{city[0]}' AND text LIKE '%#{serach_term}%'
    ORDER BY id DESC")

  row = result.each(:first => true) # can make this prettier
  since_id = row.empty? ? @since_id : row[0]['id']

  log_time("since_id = #{since_id}")
  
  log_time("http://search.twitter.com/search.json?geocode=#{city[1]['lat']},#{city[1]['long']},#{city[1]['range']}&result_type=#{@result_type}&q=#{serach_term.clean_term}&rpp=#{@returns_per_page}&since_id=#{since_id}")
  
  uri = URI("http://search.twitter.com/search.json?geocode=#{city[1]['lat']},#{city[1]['long']},#{city[1]['range']}&result_type=#{@result_type}&q=#{serach_term.clean_term}&rpp=#{@returns_per_page}&since_id=#{since_id}")
  response = Net::HTTP.get(uri)
  tweets = JSON.parse(response)
end

dbyml = YAML::load(File.open('yaml/db_settings.yml'))['prod_settings']
@client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])

@tweet = []

yml = YAML::load(File.open('yaml/twitter.yml'))

get_min_since_id

yml['SearchTerms'].each do |serach_term|

  yml['Cities'].each do |city|

    log_time("polling: " + serach_term.to_s + " from " + city[0].to_s)

    tweets = fetch_tweets(city, serach_term)
    
    log_time("returned tweets: " + tweets["results"].length.to_s)
    
    tweets["results"].each do |tweet|
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

log_time("End time\n\n\n")

#   uri = URI("http://search.twitter.com/search.json?q=%23bieber&rpp=100") # for testing, bieber gets more tweets then us :(
