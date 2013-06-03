#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'yaml'
require 'tiny_tds'
require 'logger'

$LOG = Logger.new('log/fb_link_count.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start")

# urls to monitor
urls = YAML::load(File.open('config/facebook.yml'))['urls']

searchstring = 'SELECT%20share_count,%20like_count,%20comment_count,%20url%20FROM%20link_stat%20WHERE'

urls.each do |url|
  searchstring << "%20url='" + URI::encode(url) + "'%20OR"
end

http = Net::HTTP.new('graph.facebook.com')
response = http.request(Net::HTTP::Get.new("/fql?q=#{searchstring[0..-6]}"))
fbcounts = JSON.parse(response.body)['data']

dbyml = YAML::load(File.open('config/db_settings.yml'))['prod_settings']
client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])

log_time("inserting details of #{fbcounts.length} links...")

fbcounts.each do |stat|
  result = client.execute("
    IF EXISTS (
      SELECT seqn
      FROM fb_link_count
      WHERE
        url = '#{stat['url']}' AND
        share_count = '#{stat['share_count']}' AND
        like_count = '#{stat['like_count']}' AND
        comment_count = '#{stat['comment_count']}')
      UPDATE fb_link_count
      SET updated = GETDATE()
      WHERE
        url = '#{stat['url']}' AND
        share_count = '#{stat['share_count']}' AND
        like_count = '#{stat['like_count']}' AND
        comment_count = '#{stat['comment_count']}';
    ELSE
      INSERT INTO fb_link_count (url, share_count, like_count, comment_count)
      SELECT '#{stat['url']}', '#{stat['share_count']}', '#{stat['like_count']}', '#{stat['comment_count']}'
  ").do
end

log_time("Finish")

# FQL Query
# SELECT share_count, like_count, comment_count, url FROM link_stat WHERE url = "amnesty.ca" OR url = "amnesty.org" OR url = "amnesty.org.au" OR url = "amnesty.org.uk"
