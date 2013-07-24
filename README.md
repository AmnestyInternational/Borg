![Amnesty International logotype and logo banner](http://amnesty.ca/sites/default/files/ai-lockup-2c-banner.png)
Borg
====

Disclosure statement
--------------------
Amnesty International only uses data towards the universal recognition of human rights.

Purpose
-------
The purpose of this project is to pull publicly available data from social media sites relevant to Amnesty International. This data will be used to;
* Track the success of campaigns
* Determine which issues are important to our supporters
* Responds quickly to changes in the social media sphere

Install procedure
-----------------
These instructions are designed for Ubuntu 12.04 running Ruby 1.9.1 and SQL Server 2008

### Permissions

#### Create Ubuntu user

Create a user to run the Borg scripts.

    $ sudo useradd --create-home --shell /bin/bash --user-group <username>

#### Create SQL user

##### Create user with SQL Authentication
    CREATE LOGIN <username> WITH PASSWORD = '<password>', DEFAULT_DATABASE = <dbname>
    GO

##### Add read and write permissions for user to database
    USE <dbname>;
    CREATE USER <username> FOR LOGIN <username>;
    GO
    EXEC sp_addrolemember db_datareader, <username> 
    GO
    EXEC sp_addrolemember db_datawriter, <username> 
    GO

### Create SQL tables

#### Facebook link counter

    USE <dbname>;
    
    CREATE TABLE fb_link_count
    (
    seqn INT IDENTITY PRIMARY KEY,
    url VARCHAR(32),
    share_count INT,
    like_count INT,
    comment_count INT,
    created datetime default CURRENT_TIMESTAMP,
    updated datetime default CURRENT_TIMESTAMP
    )

#### Facebook page post reach monitor

    USE <dbname>;
    
    CREATE TABLE fb_page_post
    (
    post_id VARCHAR(50) PRIMARY KEY,
    message VARCHAR(MAX),
    photo BIT,
    video BIT,
    created_time datetime,
    updated_time datetime,
    permalink VARCHAR(128),
    type INT,
    parent_post_id VARCHAR(32),
    actor_id VARCHAR(64)
    )
    
    CREATE TABLE fb_page_post_stat
    (
    seqn INT IDENTITY PRIMARY KEY,
    post_id VARCHAR(50),
    share_count INT,
    likes_count INT,
    comments_count INT,
    created datetime default CURRENT_TIMESTAMP,
    updated datetime default CURRENT_TIMESTAMP
    )

#### Twitter monitor

    USE <dbname>;
    
    # Tables

    CREATE TABLE Tweets
    (
    id BIGINT PRIMARY KEY NOT NULL,
    usr_id INT NOT NULL,
    coordinates GEOGRAPHY NULL,
    text VARCHAR(160) NOT NULL,
    created DATETIME NULL,
    imported DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    
    CREATE TABLE TwitterUsers
    (
    id INT PRIMARY KEY NOT NULL,
    screen_name VARCHAR(32) NOT NULL,
    name  VARCHAR(32) NULL,
    location VARCHAR(32) NULL,
    protected BIT NULL,
    verified BIT NULL,
    followers_count INT NULL,
    friends_count INT NULL,
    statuses_count INT NULL,
    time_zone VARCHAR(32) NULL,
    utc_offset FLOAT NULL,
    profile_image_url VARCHAR(128) NULL,
    created_at DATETIME,
    imported_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    
    CREATE TABLE TweetsAnatomize
    (
    tweet_id BIGINT NOT NULL,
    term VARCHAR(32) NOT NULL,
    CONSTRAINT pk_TweetsAnatomize PRIMARY KEY (tweet_id,term)
    )
    
    CREATE TABLE TweetUserMentions
    (
    tweet_id BIGINT NOT NULL,
    usr_id INT NOT NULL,
    CONSTRAINT pk_TwitterUserMentions PRIMARY KEY (tweet_id,usr_id)
    )
    
    CREATE TABLE TweetHashtags
    (
    tweet_id BIGINT NOT NULL,
    hashtag VARCHAR(32) NOT NULL,
    CONSTRAINT pk_TweetHashtags PRIMARY KEY (tweet_id,hashtag)
    )
    
    CREATE TABLE TweetUrls
    (
    tweet_id BIGINT NOT NULL,
    url VARCHAR(256) NOT NULL,
    CONSTRAINT pk_TweetUrls PRIMARY KEY (tweet_id,url)
    )
    
    CREATE TABLE TweetRegions
    (
    tweet_id BIGINT NOT NULL,
    region VARCHAR(32) NOT NULL,
    CONSTRAINT pk_TweetRegion PRIMARY KEY (tweet_id,region)
    )

    # Views

    CREATE VIEW vAI_Tweets AS
      SELECT
        T.id,
        TU.screen_name,
        TU.name,
        TR.region,
        TU.location,
        T.coordinates,
        TU.profile_image_url,
        T.text,
        T.created,
        T.imported,
        TU.followers_count,
        TU.friends_count,
        TU.statuses_count 'tweet_count',
        DATEDIFF(DAY, TU.created_at, GETDATE()) 'days_active',
        CASE WHEN (DATEDIFF(DAY, TU.created_at, GETDATE())) = 0 THEN
          TU.statuses_count
        ELSE
          (TU.statuses_count / (DATEDIFF(DAY, TU.created_at, GETDATE())))
        END 'tweets_per_day'
      FROM
        Tweets AS T
        INNER JOIN
        TwitterUsers AS TU
        ON T.usr_id = TU.id
        INNER JOIN
        TweetRegions AS TR
        ON T.id = TR.tweet_id
        
    CREATE VIEW vAI_CanadianTweets AS
      SELECT *
      FROM vAI_Tweets
      WHERE
        region IN ('GTA', 'London', 'Calgary', 'Montreal', 'Victoria', 'Ottawa', 'Winnipeg', 'Oshawa', 'Edmonton', 'St Catharines', 'Kitchener', 'Vancouver', 'Halifax', 'Quebec City')


#### Engaging Networks

    USE <dbname>;
    CREATE TABLE ENsupporters
    (
    supporter_id INT PRIMARY KEY NOT NULL,
    imis_id INT NULL,
    first_name VARCHAR(32) NULL,
    last_name VARCHAR(32) NULL,
    preferred_salutation VARCHAR(32) NULL,
    title VARCHAR(8) NULL,
    supporter_email VARCHAR(64) NULL,
    address VARCHAR(32) NULL,
    city VARCHAR(32) NULL,
    postal_code VARCHAR(10) NULL,
    province VARCHAR(16) NULL,
    phone_number VARCHAR(16) NULL,
    supporter_create_date DATE NULL,
    supporter_modified_date DATE NULL,
    imported DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    
    CREATE TABLE ENsupportersAttributes
    (
    seqn INT IDENTITY PRIMARY KEY,
    supporter_id INT NOT NULL,
    attribute VARCHAR(32) NOT NULL,
    value VARCHAR(32) NOT NULL,
    imported DATETIME default CURRENT_TIMESTAMP,
    updated DATETIME default CURRENT_TIMESTAMP
    )
    
    CREATE TABLE ENsupportersActivities
    (
    seqn INT IDENTITY PRIMARY KEY,
    supporter_id INT NOT NULL,
    type VARCHAR(16) NOT NULL,
    id VARCHAR(64) NULL,
    datetime DATETIME,
    status VARCHAR(16) NULL,
    data1 VARCHAR(MAX) NULL,
    data2 VARCHAR(MAX) NULL,
    data3 VARCHAR(MAX) NULL,
    data4 VARCHAR(MAX) NULL,
    data5 VARCHAR(MAX) NULL,
    data6 VARCHAR(MAX) NULL,
    data7 VARCHAR(MAX) NULL,
    data8 VARCHAR(MAX) NULL,
    data9 VARCHAR(MAX) NULL,
    data10 VARCHAR(MAX) NULL,
    data11 VARCHAR(MAX) NULL,
    data12 VARCHAR(MAX) NULL,
    data13 VARCHAR(MAX) NULL,
    data14 VARCHAR(MAX) NULL,
    data15 VARCHAR(MAX) NULL,
    data16 VARCHAR(MAX) NULL,
    data17 VARCHAR(MAX) NULL,
    data18 VARCHAR(MAX) NULL,
    data19 VARCHAR(MAX) NULL,
    data20 VARCHAR(MAX) NULL,
    imported DATETIME default CURRENT_TIMESTAMP,
    updated DATETIME default CURRENT_TIMESTAMP
    )

#### Articles

    USE <dbname>;
    CREATE TABLE Articles
    (
    url VARCHAR(256) PRIMARY KEY NOT NULL,
    title VARCHAR(128) NULL,
    source VARCHAR(32) NULL,
    type VARCHAR(8) NOT NULL,
    description VARCHAR(MAX) NULL,
    published DATETIME NULL,
    imported DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    
    CREATE TABLE ArticlesAnatomize
    (
    url VARCHAR(128) NOT NULL,
    term VARCHAR(32) NOT NULL,
    count INT,
    CONSTRAINT pk_ArticlesAnatomize PRIMARY KEY (url,term)
    )

### Git clone and set permissions

    $ cd /path/to/dir
    $ git clone https://github.com/AmnestyInternational/Borg.git
    $ bundle install
    $ sudo chown -R <username>:<groupname> Borg/

### YAML settings

Update
* yaml/api_tokens.yml
* yaml/db_settings.yml

### Create cronjobs

Add cronjobs for the social pull user

    $ sudo su -- <username> -c 'crontab -e'

It is necessary to include the variable paths in the cron table.

    GEM_HOME=/usr/local/lib/ruby/gems/1.9.1
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games
    
    # Social media api scripts
    */10    *       *       *       *       cd /srv/Borg; ruby fb_page_post_stats.rb;
    */10    *       *       *       *       cd /srv/Borg; ruby fb_link_count.rb;
    45      *       *       *       *       cd /srv/Borg; ruby twitter.rb;
    15      00      *       *       *       cd /srv/Borg; ruby engaging_networks.rb;
    55      *       *       *       *       cd /srv/Borg; ruby articles.rb;
    
References
==========

### Engaging Networks

Campaign Type Codes

| Type of Activity                                    | Default code           |
| --------------------------------------------------- |:----------------------:|
| email to target                                     | ET                     |
| data capture                                        | DC                     |
| tell-a-friend                                       | TAF                    |
| broadcast email                                     | B                      |
| jamii registration                                  | J                      |
| jamii custom form                                   | JF                     |
| question checkbox                                   | Q                      |
| question multiple                                   | QM                     |
| donation page                                       | TAF                    |
| donation page – credit/debit card single payment    | CREDIT/DEBIT_SINGLE    |
| donation page – credit/debit card recurring payment | CREDIT/DEBIT_RECURRING |
| donation page – bank single payment                 | BANK_SINGLE            |
| donation page – bank recurring payment              | BANK_RECURRING         |


Licence
=======

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
