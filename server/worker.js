/* Dependencies */
var path = require('path');
var fs = require('fs');
/* connect package for static file server support and logging*/
var connect = require('connect');
/* HTTP - Server */
var http = require('http');
/* Mongo - Datenbank*/
var mongo = require('mongodb');
/* Redis - Datenbank*/
var redis = require('redis');
/* HTML5 - WebsocketServer */
var WebSocketServer = require('websocket').server;

/* HTTP Server, that the Websocketserver uses */
var httpServer;

/* list of currently connected websocket-Clients*/
var clients = [ ];

//               Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];

const HTTP_SERVER_PORT = 8090;

/* Logging */
function log(message) {
  var message = '['+new Date().toUTCString()+'] ' + '[Worker '+process.pid+'] ' + message;
  fs.appendFile(__dirname + '/log/worker.log', message + '\n', function(err) {});
  console.log(message);
}

/* start the initial HTTPServer ...*/ 
function startHTTPServer(callback){
  var httpLogFile = fs.createWriteStream(__dirname + '/log/http_server.log', {flags: 'a'});
  var app = connect()
    .use(connect.logger({stream: httpLogFile}))
    .use(connect.static('client'));
  httpServer = http.createServer(app).listen(HTTP_SERVER_PORT);
  log('HTTP Server started, listens on Port ' + HTTP_SERVER_PORT);
  callback();
}

/* upgrade HTTP-Connection to Websocket-Connection */
function startWebSocketServer(callback){
  wsServer = new WebSocketServer({
      httpServer: httpServer
  });
  log("HTML5-WebSocket-Server created");

  /* This callback function is called every time a client tries to connect to the WebSocket server*/
  wsServer.on('request', function(request) {
    /* accept connection - check 'request.origin' to make sure that client connecting from correct website*/
    var connection = request.accept(null, request.origin);
    log(' Connection from origin ' + request.origin + 'accepted.');

    /* client index necessary to remove client on 'close' event*/
    var index = clients.push(connection) - 1;

    /* most important callback: handles all messages from clients*/
    connection.on('message', function(message) {
       if (message.type === 'utf8') 
       {
        var rquest = JSON.parse(message.utf8Data);
        /* process WebSocket message*/        
        if (rquest.function == 'register')
        {
           connection.zoom = rquest.zoom;
           connection.bounds = rquest.bounds;
           getVesselsInBounds(connection, rquest.bounds, rquest.zoom);
         }
      }
    });

    connection.on('close', function(connection) {
      log((new Date()) + " Peer "+ request.origin + " disconnected.");
      /* remove user from the list of connected clients */
      clients.splice(index, 1);
      /* close user connection */
      });
  });
  callback();
}


/* open Redis - Database -Connection */
function connectToRedis() {
  redisClient = redis.createClient();

  redisClient.on('connect', function() {
    log('(Redis) Connection established');
  });
  redisClient.on('error', function(err) {
    log('(Redis) ' + err);
  });
  redisClient.on('message', function(channel, message) {
    if (channel == 'vesselPos') 
    {
      try 
      {
        var json = JSON.parse(message);
      }
      catch (err) 
      {
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
          /* check, if Client-Connection is affected by Vessel-Position-Update */
          if (positionInBounds(lon, lat, client.bounds)) 
          {
            if(json.sog !=null && json.sog > (zoomSpeedArray[client.zoom]) && json.sog != 102.3)
            {
              /* transfer message as stringified object */
              client.sendUTF(JSON.stringify( { type: 'vesselPosEvent', vessel:json } ));
            }
          }
        }
      });
    }
  });
  redisClient.subscribe('vesselPos');
}

/* MongoDB -Connection */
var mongoHost = 'localhost';
var mongoPort = 27017;
var mongoServer = new mongo.Server(mongoHost, mongoPort, {auto_reconnect: true});
var mongoDB = new mongo.Db('ais', mongoServer, {safe: true});

function connectToMongoDB() {
  mongoDB.open(function(err, db) {
    if (err) 
    {
      log('(MongoDB) ' + err);
      log('Exiting ...')
      process.exit(1);
    }
    else 
    {
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

/* get all Vessels in Bounds of a Client-Request */
function getVesselsInBounds(client, bounds, zoom) {
   var timeFlex = new Date().getTime();
   var vesselCursor = vesselsCollection.find({
    pos: { $within: { $box: [ [bounds._southWest.lng,bounds._southWest.lat], [bounds._northEast.lng,bounds._northEast.lat] ] } },
    time_received: { $gt: (new Date() - 10 * 60 * 1000) }, /* only messages younger than 10 minutes */
    sog: { $exists:true },
    sog: { $gt: zoomSpeedArray[zoom]},
    sog: {$ne: 102.3}
  });
  vesselCursor.toArray(function(err, vesselData) 
  {
    if (!err)
    {
      var boundsString = '['+bounds._southWest.lng+','+bounds._southWest.lat+']['+bounds._northEast.lng+','+bounds._northEast.lat+']';
      var logMessage = '(Debug) Found ' + vesselData.length + ' vessels in bounds ' + boundsString;
      logMessage += zoomSpeedArray[zoom] > 0? 'with sog > '+zoomSpeedArray[zoom]:'';
      log(logMessage);
      client.sendUTF(JSON.stringify({ type: 'vesselsInBoundsEvent', vessels: vesselData}));
    }
    else
    {
      log(err + ", bounds:"+boundsString);
    }
  });
}

/*Help-function to check, if a vessels Position (lon, lat) is in a clients viewed bounds */
function positionInBounds(lon, lat, bounds) {
  return (lon > bounds._southWest.lng && lon < bounds._northEast.lng && lat > bounds._southWest.lat && lat < bounds._northEast.lat);
}

/* this is the starting point of the worker.js - Process */
connectToMongoDB();

