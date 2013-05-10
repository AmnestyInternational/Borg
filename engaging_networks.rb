#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'
require 'yaml'

token = YAML::load(File.open('yaml/api_tokens.yml'))['api_tokens']['engagingnetworkstoken']
startdate = (Time.now - (1 * 24 * 60 * 60)).strftime("%m%d%Y") # one days worth

puts "Requesting records with : http://www.e-activist.com/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml"

http = Net::HTTP.new('www.e-activist.com')
http.read_timeout = 10 * 60
response = http.request(Net::HTTP::Get.new("/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml"))
endata = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['rows'][0]['row']

puts "" + endata.length.to_s + " records imported..."

sleep 5

endata.each do | row |
puts row.inspect + "\n"
=begin
  puts "account_id: " + row['account_id'][0]
  puts "supporter_id: " + row['supporter_id'][0]
  puts "supporter_email: " + row['supporter_email'][0]
  puts "supporter_create_date: " + row['supporter_create_date'][0]
  puts "supporter_modified_date: " + row['supporter_modified_date'][0]
  puts "type: " + row['type'][0]
  puts "id: " + row['id'][0]
  puts "date: " + row['date'][0]
  puts "time: " + row['time'][0]
  puts "status: " + row['status'][0]
  puts "data1: " + row['data1'][0]
  puts "data2: " + row['data2'][0]
  puts "data3: " + row['data3'][0]
  puts "data4: " + row['data4'][0]
  puts "data5: " + row['data5'][0]
  puts "data6: " + row['data6'][0]
  puts "data7: " + row['data7'][0]
  puts "data8: " + row['data8'][0]
  puts "data9: " + row['data9'][0]
  puts "data10: " + row['data10'][0]
  puts "data11: " + row['data11'][0]
  puts "data12: " + row['data12'][0]
  puts "data13: " + row['data13'][0]
  puts "data14: " + row['data14'][0]
  puts "data15: " + row['data15'][0]
  puts "data16: " + row['data16'][0]
  puts "data17: " + row['data17'][0]
  puts "data18: " + row['data18'][0]
  puts "data19: " + row['data19'][0]
  puts "data20: " + row['data20'][0]
  puts "first_name: " + row['first_name'][0]
  puts "last_name: " + row['last_name'][0]
  puts "email: " + row['email'][0]
  puts "phone_number: " + row['phone_number'][0]
  puts "address: " + row['address'][0]
  puts "city: " + row['city'][0]
  puts "province: " + row['province'][0]
  puts "postal_code: " + row['postal_code'][0]
  puts "title: " + row['title'][0]
=end
end

