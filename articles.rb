#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'
require 'yaml'
require 'logger'
require 'tiny_tds'
require 'iconv'
require 'active_support/all'
require 'time'

$LOG = Logger.new('log/articles.log')
# Set back to default formatter because active_support/all is messing things up
$LOG.formatter = Logger::Formatter.new

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start time")

class String
  def strip_tags
    self.gsub( %r{</?[^>]+?>}, ' ' ).squeeze(' ')
  end

  def to_esc_sql
    output = Iconv.iconv('ascii//ignore//translit', 'utf-8', self.gsub('&#39;',"'"))[0].gsub("'","''")
    output.to_s.empty? ? "NULL" : "'" + output + "'" 
  end
end


def pullgooglenews
  log_time("polling Google News")
  http = Net::HTTP.new('news.google.ca')
  response = http.request(Net::HTTP::Get.new("/news/feeds?q=%22amnesty+international%22+canada&hgl=ca&pz=1&cf=all&ned=ca&hl=en&output=rss"))
  newsarticles = Array.new
  newsarticles = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['channel'][0]['item']
  
  log_time("#{newsarticles.length.to_s} articles retrieved from Google News")

  newsarticles.each do | article |
    @articles << {
      'url' => article['link'][0].split(/&url=/)[-1],
      'title' => article['title'][0].split(/\s-\s+/)[0],
      'source' => article['title'][0].split(/\s-\s+/)[-1],
      'type' => 'news',
      'description' => article['description'][0].strip_tags,
      'published' => article['pubDate'][0].to_datetime}
  end
# https://news.google.ca/news/feeds?q=%22amnesty+international%22&hgl=ca&pz=1&cf=all&ned=ca&hl=en&output=rss
end

def pullicerocket
  log_time("polling Ice Rocket")
  http = Net::HTTP.new('www.icerocket.com')
  response = http.request(Net::HTTP::Get.new("/search?tab=blog&q=%22amnesty+international%22+canada&rss=1&dr=1"))
  blogs = Array.new
  blogs = XmlSimple.xml_in(response.body, { 'KeyAttr' => 'name' })['channel'][0]['item']

  log_time("#{blogs.length.to_s} articles retrieved from Ice Rocket")

  blogs.each do | post |
    @articles << {
      'url' => post['link'][0],
      'title' =>  post['title'][0],
      'source' => post['source'][0]['content'],
      'type' => 'blog',
      'description' => post['description'][0].strip_tags,
      'published' => post['pubDate'][0].to_datetime}
  end
# http://www.icerocket.com/search?tab=blog&q=%22amnesty+international%22+canada&rss=1&dr=1
end

def pullgoogleblog
  log_time("polling Google Blogs")
  http = Net::HTTP.new('www.google.ca')
  response = http.request(Net::HTTP::Get.new("/search?hl=en-CA&q=%22amnesty+international%22&tbm=blg&output=rss&hl=en-CA&cr=countryCA&biw=1440&bih=766&tbs=ctr:countryCA,qdr:d&source=hp"))
  blogs = Array.new
  blogs = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['channel'][0]['item']

  log_time("#{blogs.length.to_s} articles retrieved from Google Blogs")

  blogs.each do | post |
    @articles << {
      'url' => post['link'][0].split(/&url=/)[-1],
      'title' => post['title'][0],
      'source' => post['publisher'][0],
      'type' => 'blog',
      'description' => post['description'][0].strip_tags,
      'published' => post['date'][0].to_datetime}
  end
# http://www.google.ca/search?hl=en-CA&q=%22amnesty+international%22&tbm=blg&output=rss&hl=en-CA&cr=countryCA&biw=1440&bih=766&tbs=ctr:countryCA,qdr:d&source=hp
end

def importarticles
  dbyml = YAML::load(File.open('yaml/db_settings.yml'))['prod_settings']
  client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])
  log_time("connection to #{dbyml['database']} on #{dbyml['host']} opened, inserting / updating records")
  log_time("inserting / updating #{@articles.length.to_s} articles")

  insertcount = Hash.new {|hash,key| hash[key] = 0 }
  @articles.each do | article |
     sql = "
        IF EXISTS (SELECT url FROM Articles WHERE url = #{article['url'].to_esc_sql})
          UPDATE Articles
          SET
            updated = GETDATE()
          WHERE url = #{article['url'].to_esc_sql};
        ELSE
          INSERT Articles (url, title, source, type, description, published)
          VALUES (
            #{article['url'].to_esc_sql},
            #{article['title'].to_esc_sql},
            #{article['source'].to_esc_sql},
            #{article['type'].to_esc_sql},
            #{article['description'].to_esc_sql},
            '#{article['published'].to_s(:db)}');\n"

    insertcount['article'] += 1
    puts sql
    client.execute(sql).do
  end

  log_time("#{insertcount['article']} articles inserted / updated")
end

@articles = Array.new

pullgooglenews
pullicerocket
pullgoogleblog

importarticles

log_time("Finish time")
