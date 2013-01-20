# AIS ship positions with a html5 websocket-server in node.js and a javascript-client

## Getting started

### On Ubuntu 12.04:

#### 1. Install node.js

    $ sudo add-apt-repository -y ppa:chris-lea/node.js
    $ sudo apt-get update 
    $ sudo apt-get install nodejs nodejs-dev npm

#### 3. Install MongoDB

To get the newest stable version we have to add the official MongoDB repository to our sources.
    
    $ apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
    $ echo "deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen" | tee -a /etc/apt/sources.list.d/10gen.list
    $ apt-get update
    $ apt-get install mongodb-10gen

#### 4. Clone project

  via ssh

    git clone git@github.com:druekeb/ais_dart.git

  or via https

    git clone https://github.com/druekeb/ais_dart.git

4. Install modules via NPM

    npm install

