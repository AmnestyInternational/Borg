#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'
require 'yaml'
require 'logger'

$LOG = Logger.new('log/e-activist.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start time")

def pullrawdata(days)
  token = YAML::load(File.open('yaml/api_tokens.yml'))['api_tokens']['engagingnetworkstoken']
  startdate = (Time.now - (days * 24 * 60 * 60)).strftime("%m%d%Y") # up to 45 days

  log_time("Requesting " + days.to_s + " day(s) of records with : https://www.e-activist.com/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml")

  uri = URI.parse("https://www.e-activist.com/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 60 * 60
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  response = http.get(uri.request_uri)
  raweactivism = XmlSimple.xml_in(response.body.force_encoding("ISO-8859-1").encode("UTF-8"), { 'KeyAttr' => 'name' })['rows'][0]['row']

  log_time(raweactivism.length.to_s + " records imported...")
  raweactivism
end

def savedata(inputdata, filename)
  open("tmp/#{filename}.yml", 'w') {|f| YAML.dump(inputdata, f)}
  loaded = open("tmp/#{filename}.yml") {|f| YAML.load(f) }
  log_time("tmp/#{filename}.yml created with #{inputdata.length.to_s} records")
end

def loadrawdata
  raweactivism = YAML::load(File.open('tmp/raweactivism.yml'))
  log_time(raweactivism.length.to_s + " records loaded from tmp/raweactivism.yml")
  raweactivism
end

def organise(raweactivism)
  eactivist = Hash.new {|hash,key| hash[key] = Hash.new {|hash,key| hash[key] = [] } }

  structure = YAML::load(File.open('yaml/engagingnetworks.yml'))['structure']

  raweactivism.each do | row |

    structure['eactivistdetails'].each do | field |
      eactivist[row["supporter_id"][0]][field] = row[field][0] unless row[field].nil? or field.nil?
    end

    # these fields need special attention for formatting. imid_id to imis_id and empty hashes being produced for phone numbers and provinces
    eactivist[row["supporter_id"][0]]['imis_id'] = row["imid_id"][0] unless row["imid_id"].nil?
    eactivist[row["supporter_id"][0]]['phone_number'] = row["phone_number"][0] unless row["phone_number"].nil? or row["phone_number"][0].empty?
    eactivist[row["supporter_id"][0]]['province'] = row["province"][0] unless row["province"].nil? or row["province"][0].empty?
    eactivist[row["supporter_id"][0]]['supporter_modified_date'] = row["supporter_modified_date"][0] unless row["supporter_modified_date"].nil? or row["supporter_modified_date"][0].empty?

    attributes = Hash.new
    structure['eactivistattributes'].each do | field |
      attributes[field] = row[field][0] unless row[field].nil?
    end
    eactivist[row["supporter_id"][0]]['attributes'] = attributes unless attributes.empty?

    activities = Hash.new
    row.each do | field |
      # rewrite this, it's messy! Possibly use any?
      activities[field[0]] = field[1][0] unless field[1][0].empty? or (structure['eactivistdetails'] + structure['eactivistattributes'] + structure['ignorefields'] + structure['specialfields']).include? field[0]
    end

    eactivist[row["supporter_id"][0]]['activities'] << activities
  end
  log_time("organised #{raweactivism.length.to_s} rows into #{eactivist.length.to_s} supporter records")
  eactivist
end

#savedata(pullrawdata(2), 'raweactivism')
eactivist = organise(loadrawdata)

savedata(eactivist, 'cleaneactivism')

log_time("Finish time")
