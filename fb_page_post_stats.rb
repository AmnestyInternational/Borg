#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'yaml'
require 'tiny_tds'
require 'active_support/time'
require 'logger'

track = '100'
source_id = '121222984568561'

$LOG = Logger.new('log/fb_page_post_stats.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start")

fbaccesstoken = YAML::load(File.open('yaml/api_tokens.yml'))['api_tokens']['fbaccesstoken']

uri = URI.parse("https://graph.facebook.com/fql?q=SELECT%20post_id%2C%20likes.count%2C%20share_count%2C%20comments.count%2C%20message%2C%20attachment.media%2C%20created_time%2C%20updated_time%2C%20permalink%2C%20parent_post_id%2C%20type%2C%20actor_id%0AFROM%20stream%0AWHERE%20source_id%20%3D%20'#{source_id}'%0AORDER%20BY%20created_time%20DESC%20LIMIT%200%2C#{track}&access_token=#{fbaccesstoken}")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE # read into this
response = http.get(uri.request_uri)
fbcounts = JSON.parse(response.body)['data']

dbyml = YAML::load(File.open('yaml/db_settings.yml'))['prod_settings']
client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])

log_time("inserting #{fbcounts.length} rows if they don't exist...")

fbcounts.each do |stat|

  video = 0
  photo = 0

  unless stat['attachment'].empty? # Make this pretty when you get time
    stat['attachment']['media'].each do |attachment|
      photo = 1 if attachment['type'] == 'photo'
    end

    stat['attachment']['media'].each do |attachment|
      video = 1 if attachment['type'] == 'video'
    end
  end

  updated_time = Time.at(stat['updated_time']).to_s(:db)
  created_time = Time.at(stat['created_time']).to_s(:db)
  message = stat['message'].gsub("'","''") # For the escape string

  stat['type'] = 0 unless stat['type'].is_a? Integer # Also make this pretty when you get time
  stat['share_count'] = 0 unless stat['share_count'].is_a? Integer

  if stat['likes'].empty?
    likes = 0
  else
    likes = stat['likes']['count']
  end

  if stat['comments'].empty?
    comments = 0
  else
    comments = stat['comments']['count']
  end

  client.execute("
    IF EXISTS (SELECT post_id FROM fb_page_post WHERE post_id = '#{stat['post_id']}')
      UPDATE fb_page_post
      SET updated_time = '#{updated_time}'
      WHERE post_id = '#{stat['post_id']}';
    ELSE
      INSERT fb_page_post (post_id, message, photo, video, created_time, updated_time, permalink, type, parent_post_id, actor_id)
      VALUES ('#{stat['post_id']}', '#{message}', #{photo}, #{video}, '#{created_time}', '#{updated_time}', '#{stat['permalink']}', '#{stat['type'].to_s}', '#{stat['parent_post_id']}', '#{stat['actor_id']}');
  ").do

  client.execute("
    IF EXISTS (
      SELECT post_id
      FROM fb_page_post_stat
      WHERE
        post_id = '#{stat['post_id']}' AND
        share_count = '#{stat['share_count']}' AND
        likes_count = '#{likes}' AND
        comments_count = '#{comments}')
      UPDATE fb_page_post_stat
      SET updated = GETDATE()
      WHERE
        post_id = '#{stat['post_id']}' AND
        share_count = '#{stat['share_count']}' AND
        likes_count = '#{likes}' AND
        comments_count = '#{comments}';
    ELSE
      INSERT INTO fb_page_post_stat (post_id, share_count, likes_count, comments_count)
      VALUES ('#{stat['post_id']}', '#{stat['share_count']}', '#{likes}', '#{comments}');
  ").do

end

log_time("Finish")

# FQL Query
=begin
SELECT post_id, likes.count, share_count, comments.count, message, attachment.media, created_time, updated_time, permalink, parent_post_id, type, actor_id
FROM stream
WHERE source_id = '121222984568561'
ORDER BY created_time DESC LIMIT 0,100
=end
