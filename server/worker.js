/**
 * Dependencies
 */

var path = require('path');
var fs = require('fs');
var connect = require('connect');
var http = require('http');
var mongo = require('mongodb');
var redis = require('redis');
var net = require('net');
var httpServer;
// list of currently connected clients (users)
var clients = [ ];



// Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
//    var zoomSpeedArray = [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1];
var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];

/**
 * Logging
 */
function log(message) {
  var message = '['+new Date().toUTCString()+'] ' + '[Worker '+process.pid+'] ' + message;
  fs.appendFile(__dirname + '/log/worker.log', message + '\n', function(err) {});
  console.log(message);
}

function logPosEvent(message) {
  var message = message +" "+new Date().getTime();
  fs.appendFile(__dirname + '/log/PosEvent.log', message + '\n', function(err) {
    if (err != null) console.log("couldn't write PosEvent :"+message+", Error: "+err);
  });
}

function logBoundsEvent(message) {
  fs.appendFile(__dirname + '/log/BoundsEvent.log', message + '\n', function(err) {
    if (err != null) console.log("couldn't write BoundsEvent :"+message+", Error: "+err);
  });
}

function startHTTPServer(callback){
  /**
   * HTTP server (use the connect package that gives static file server support)
   */
  var app = connect().use(connect.static('client'));
  httpServer = http.createServer(app).listen(8090);
  console.log("server listens on 8090");
  callback();
}
function startWebSocketServer(callback){
  /**
  *HTML5 - WebsocketServer
  */
  var WebSocketServer = require('websocket').server;

  // create the server
  wsServer = new WebSocketServer({
      httpServer: httpServer
  });
  console.log("HTML5-WebSocket-Server created");

  // This callback function is called every time someone
  // tries to connect to the WebSocket server
  wsServer.on('request', function(request) {
    console.log((new Date()) + ' Connection from origin ' + request.origin + '.');

    // accept connection - you should check 'request.origin' to make sure that
    // client is connecting from your website
    // (http://en.wikipedia.org/wiki/Same_origin_policy)
    var connection = request.accept(null, request.origin);
    console.log("connected");

    // we need to know client index to remove them on 'close' event
    var index = clients.push(connection) - 1;
    console.log((new Date()) + ' Connection accepted.');

    // This is the most important callback for us, we'll handle
    // all messages from users here.
    connection.on('message', function(message) {
       if (message.type === 'utf8') 
       {
        var rquest = JSON.parse(message.utf8Data);
        // process WebSocket message        
        // console.log(message);

        if (rquest.function == 'register')
        {
           connection.zoom = rquest.zoom;
           connection.bounds = rquest.bounds;
           getVesselsInBounds(connection, rquest.bounds, rquest.zoom);
         }
      }
     });

    connection.on('close', function(connection) {
      console.log((new Date()) + " Peer "+ request.origin + " disconnected.");
      // remove user from the list of connected clients
      clients.splice(index, 1);
      // close user connection
      });
  });
callback();
}


/**
 * Redis
 */

function connectToRedis() {
  redisClient = redis.createClient();

  redisClient.on('connect', function() {
    log('(Redis) Connection established');
  });
  redisClient.on('error', function(err) {
    log('(Redis) ' + err);
  });
  redisClient.on('message', function(channel, message) {
    if (channel == 'safetyMessage')
    {
      try
      {
        var json = JSON.parse(message);
      }
      catch(err)
      {
        log('Error parsing received JSON - safetyMessage: ' + err );
        return;
      }
      clients.forEach(function(client) {
         client.sendUTF(JSON.stringify( { type: 'safetyMessageEvent', text: message} ));
      });
    }
    if (channel == 'vesselPos') {
      try {
        var json = JSON.parse(message);
      }
      catch (err) {
        log('Error parsing received JSON - vesselpos: ' + err );
        return;
      }
      var lon = json.pos[0];
      var lat = json.pos[1];
      json.sog = json.sog/10;
      json.cog = json.cog/10;
      clients.forEach(function(client) {
        if (client.bounds != null && lon != null && lat != null) 
        {
          if (positionInBounds(lon, lat, client.bounds)) 
          {
            if(json.sog !=null && json.sog > (zoomSpeedArray[client.zoom]))
            {
              // logPosEvent(json.userid +" "+json.utc_sec);
              client.sendUTF(JSON.stringify( { type: 'vesselPosEvent', vessel:json } ));
            }
          }
        }
      });
    }
  });

  redisClient.subscribe('vesselPos');
  redisClient.subscribe('safetyMessage');
}

/**
 * MongoDB
 */

var mongoHost = 'localhost';
var mongoPort = 27017;
var mongoServer = new mongo.Server(mongoHost, mongoPort, {auto_reconnect: true});
var mongoDB = new mongo.Db('ais', mongoServer, {safe: true});

function connectToMongoDB() {
  mongoDB.open(function(err, db) {
    if (err) {
      log('(MongoDB) ' + err);
      log('Exiting ...')
      process.exit(1);
    }
    else {
      log('(MongoDB) Connection established');
      db.collection('vessels', function(err, collection) {
        if (err) {
          log('(MongoDB) ' + err);
          log('Exiting ...')
          process.exit(1);
        }
        else 
        {
          vesselsCollection = collection;
          db.collection('navigationalAid', function(err,coll){
            if(err){
              log('(MongoDB) ' + err);
              log('Exiting ...')
              process.exit(1);
            }
            else
            {
              navigationalAidCollection = coll;
              startHTTPServer(function(){
                startWebSocketServer(function(){
                  connectToRedis();
                });
              });
            }
          });
        }
      });
    }
  });
}

function getVesselsInBounds(client, bounds, zoom) {
   var timeFlex = new Date().getTime();
   var vesselCursor = vesselsCollection.find({
    pos: { $within: { $box: [ [bounds._southWest.lng,bounds._southWest.lat], [bounds._northEast.lng,bounds._northEast.lat] ] } },
    time_received: { $gt: (new Date() - 10 * 60 * 1000) },
    $or:[{sog: { $exists:true },sog: { $gt: zoomSpeedArray[zoom]}},{msgid:4},{ $gt:{msgid: 5}}]
  });
  vesselCursor.toArray(function(err, vesselData) 
  {

    if (!err)
    {
      var boundsString = '['+bounds._southWest.lng+','+bounds._southWest.lat+']['+bounds._northEast.lng+','+bounds._northEast.lat+']';
      console.log('(Debug) Found ' + vesselData.length + ' vessels in bounds ' + boundsString +" with sog > "+zoomSpeedArray[zoom]);
      var navigationalAidCursor = navigationalAidCollection.find({
          pos: { $within: { $box:[ [bounds._southWest.lng,bounds._southWest.lat], [bounds._northEast.lng,bounds._northEast.lat]]} },
          time_received: { $gt: (new Date() - 10 * 60 * 1000) }
         });
       navigationalAidCursor.toArray(function(err, navigationalAids){
          console.log('(Debug) Found ' + (navigationalAids !=null?navigationalAids.length:0) + ' navigational aids in bounds ' + boundsString);
          var vesNavArr = vesselData.concat(navigationalAids);
          // console.log ("vesNavArr: "+typeof vesNavArr +vesNavArr.length);
          logBoundsEvent(vesNavArr.length + " "+(new Date().getTime()-timeFlex ));
          client.sendUTF(JSON.stringify( { type: 'vesselsInBoundsEvent', vessels: vesNavArr} ));
        });
    }
  });
}

function positionInBounds(lon, lat, bounds) {
  return (lon > bounds._southWest.lng && lon < bounds._northEast.lng && lat > bounds._southWest.lat && lat < bounds._northEast.lat);
}

connectToMongoDB();

