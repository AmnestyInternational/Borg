#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'

http = Net::HTTP.new('news.google.ca')
response = http.request(Net::HTTP::Get.new("/news/feeds?q=%22amnesty+international%22&hgl=ca&pz=1&cf=all&ned=ca&hl=en&topic=n&output=rss"))
articles = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['channel'][0]['item']

articles.each do | article |
  puts "Title: " + article['title'][0].split(/\s-\s+/)[0]
  puts "Description: " + article['description'][0]
  puts "Source: " + article['title'][0].split(/\s-\s+/)[-1]
  puts "Published: " + article['pubDate'][0]
  puts "Url: " + article['link'][0].split(/&url=/)[-1]
end

# https://news.google.ca/news/feeds?q=%22amnesty+international%22&hgl=ca&pz=1&cf=all&ned=ca&hl=en&topic=n&output=rss
