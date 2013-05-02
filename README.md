Social-Pull
===========

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

Create a user to run the Social-Pull scripts.

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
    likes_count INT,sudo useradd --create-home --shell /bin/bash --user-group socialpull

    comments_count INT,
    created datetime default CURRENT_TIMESTAMP,
    updated datetime default CURRENT_TIMESTAMP
    )

#### Twitter monitor

    USE <dbname>;
    
    CREATE TABLE tweets
    (
    id BIGINT PRIMARY KEY NOT NULL,
    usr VARCHAR(32) NULL,
    usr_id INT NULL,
    usr_name VARCHAR(32) NULL,
    city VARCHAR(16) NULL,
    location VARCHAR(32) NULL,
    geo GEOGRAPHY NULL,
    profile_image_url VARCHAR(128) NULL,
    text VARCHAR(160) NULL,
    created DATETIME NULL,
    imported DATETIME DEFAULT CURRENT_TIMESTAMP
    )
    

### Git clone and set permissions

    $ cd /path/to/dir
    $ git clone https://github.com/AmnestyInternational/Social-Pull.git
    $ sudo chown -R <username>:<groupname> Social-Pull/

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
    */10      *      *      *       *       cd /path/to/Social-Pull; ruby fb_page_post_stats.rb;
    */10      *      *      *       *       cd /path/to/Social-Pull; ruby fb_link_count.rb;
    27      *      *      *       *       cd /path/to/Social-Pull; ruby twitter.rb;

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
