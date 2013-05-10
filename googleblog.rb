#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'

http = Net::HTTP.new('www.google.ca')
response = http.request(Net::HTTP::Get.new("/search?hl=en-CA&q=%22amnesty+international%22&tbm=blg&output=rss&hl=en-CA&cr=countryCA&biw=1440&bih=766&tbs=ctr:countryCA,qdr:d&source=hp"))
blogs = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['channel'][0]['item']

blogs.each do | post |
  puts "Title: " + post['title'][0]
  puts "Description: " + post['description'][0]
  puts "Source: " + post['publisher'][0]
  puts "Creator: " + post['creator'][0]
  puts "Published: " + post['date'][0]
  puts "Url: " + post['link'][0].split(/&url=/)[-1]
end

# http://www.icerocket.com/search?tab=blog&q=%22amnesty+international%22+canada&rss=1&dr=1

# http://www.google.ca/search?hl=en-CA&q=%22amnesty+international%22&tbm=blg&output=rss&hl=en-CA&cr=countryCA&biw=1440&bih=766&tbs=ctr:countryCA,qdr:d&source=hp
