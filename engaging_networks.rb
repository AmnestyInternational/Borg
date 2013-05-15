#!/usr/bin/env ruby
require 'xmlsimple'
require 'net/http'
require 'yaml'
require 'logger'
require 'tiny_tds'
require 'iconv'
require 'time'

$LOG = Logger.new('log/e-activist.log')   

def log_time(input)
  puts Time.now.to_s + ", " + input
  $LOG.info(input)
end

log_time("Start time")

class String
  def to_esc_sql
    output = Iconv.iconv('ascii//ignore//translit', 'utf-8', self)[0].to_s.gsub("'","''")
    output = Time.parse(output).strftime "%Y-%m-%d" if output.match(/\d\d\/\d\d\/\d\d\d\d/)
    output.to_s.empty? ? "NULL" : "'" + output + "'" 
  end
end

class Array
  def to_esc_sql
    output = Iconv.iconv('ascii//ignore//translit', 'utf-8', self[0])[0].to_s.gsub("'","''")
    output = Time.parse(output).strftime "%Y-%m-%d" if output.match(/\d\d\/\d\d\/\d\d\d\d/)
    output.to_s.empty? ? "NULL" : "'" + output + "'" 
  end
end

class Hash
  def to_esc_sql
    output = Iconv.iconv('ascii//ignore//translit', 'utf-8', self[0])[0].to_s.gsub("'","''")
    output = Time.parse(output).strftime "%Y-%m-%d" if output.match(/\d\d\/\d\d\/\d\d\d\d/)
    output.to_s.empty? ? "NULL" : "'" + output + "'" 
  end
end

def pullrawdata(days)
  token = YAML::load(File.open('yaml/api_tokens.yml'))['api_tokens']['engagingnetworkstoken']
  startdate = (Time.now - (days * 24 * 60 * 60)).strftime("%m%d%Y")

  log_time("Requesting " + days.to_s + " day(s) of records with : https://www.e-activist.com/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml")

  uri = URI.parse("https://www.e-activist.com/ea-dataservice/export.service?token=#{token}&startDate=#{startdate}&type=xml")
  http = Net::HTTP.new(uri.host, uri.port)
  http.read_timeout = 480 * 60 # the pulling process needs a huge timeout
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

def importeactivists(eactivists)
  dbyml = YAML::load(File.open('yaml/db_settings.yml'))['test_settings']
  @client = TinyTds::Client.new(:username => dbyml['username'], :password => dbyml['password'], :host => dbyml['host'], :database => dbyml['database'])
  log_time("connection to #{dbyml['database']} on #{dbyml['host']} opened, inserting / updating records")
  log_time("inserting / updating #{eactivists.length} supporters")
  log_time("inserting / updating #{eactivists.inject(0) { |result, element| result + element[1]['attributes'].length }} supporter attributes")
  log_time("holding #{eactivists.inject(0) { |result, element| result + element[1]['activities'].length }} supporter activities")

  @insertcount = Hash.new {|hash,key| hash[key] = 0 }
  eactivists.each_pair do | supporter_id, data |
    sql = "
        IF EXISTS (SELECT supporter_id FROM ENsupporters WHERE supporter_id = #{supporter_id.to_esc_sql})
          UPDATE ENsupporters
          SET
            imis_id = #{data['imis_id'].to_esc_sql},
            first_name = #{data['first_name'].to_esc_sql},
            last_name = #{data['last_name'].to_esc_sql},
            preferred_salutation = #{data['preferred_salutation'].to_esc_sql},
            title = #{data['title'].to_esc_sql},
            supporter_email = #{data['supporter_email'].to_esc_sql},
            address = #{data['address'].to_esc_sql},
            city = #{data['city'].to_esc_sql},
            postal_code = #{data['postal_code'].to_esc_sql},
            province = #{data['province'].to_esc_sql},
            phone_number = #{data['phone_number'].to_esc_sql},
            supporter_create_date = #{data['supporter_create_date'].to_esc_sql},
            supporter_modified_date = #{data['supporter_modified_date'].to_esc_sql}
          WHERE supporter_id = #{supporter_id.to_esc_sql};
        ELSE
          INSERT ENsupporters (supporter_id, imis_id, first_name, last_name, preferred_salutation, title, supporter_email, address, city, postal_code, province, phone_number, supporter_create_date, supporter_modified_date)
          VALUES (
            #{supporter_id.to_esc_sql},
            #{data['imis_id'].to_esc_sql},
            #{data['first_name'].to_esc_sql},
            #{data['last_name'].to_esc_sql},
            #{data['preferred_salutation'].to_esc_sql},
            #{data['title'].to_esc_sql},
            #{data['supporter_email'].to_esc_sql},
            #{data['address'].to_esc_sql},
            #{data['city'].to_esc_sql},
            #{data['postal_code'].to_esc_sql},
            #{data['province'].to_esc_sql},
            #{data['phone_number'].to_esc_sql},
            #{data['supporter_create_date'].to_esc_sql},
            #{data['supporter_modified_date'].to_esc_sql});\n"
      
      @insertcount['supporter'] += 1
      
      data['attributes'].each do | attribute |
        sql << "
          IF EXISTS (
            SELECT seqn
            FROM ENsupportersAttributes
            WHERE
              supporter_id = #{supporter_id.to_esc_sql} AND
              attribute = #{attribute[0].to_esc_sql})
          UPDATE ENsupportersAttributes
          SET
            updated = GETDATE(),
            value = #{attribute[1].to_esc_sql}
          WHERE
            supporter_id = #{supporter_id.to_esc_sql} AND
            attribute = #{attribute[0].to_esc_sql}
         ELSE
          INSERT INTO ENsupportersAttributes (supporter_id, attribute, value)
          VALUES (#{supporter_id.to_esc_sql}, #{attribute[0].to_esc_sql}, #{attribute[1].to_esc_sql});"

        @insertcount['attribute'] += 1

      end

    data['activities'].each do | activity |
      
    end

    puts sql
    @client.execute(sql).do
  end

  log_time("#{@insertcount['supporter']} supporters inserted / updated")
  log_time("#{@insertcount['attribute']} supporters inserted / updated")

end

savedata(pullrawdata(1), 'raweactivism')

eactivist = organise(loadrawdata)

savedata(eactivist, 'cleaneactivism')

importeactivists(eactivist)

log_time("Finish time")
