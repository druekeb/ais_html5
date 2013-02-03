
// How many clients should we simulate?
var clients = 100;

// What bounds should we use?
var bounds = {	_southWest: {lat:53.54279383653008, lng:9.946274757385254},
		_northEast: {lat:53.5472180724181, lng:9.973740577697754} 
	};

// What zoomLevel should we use?
var zoomLevel = 13;

// Where should we connect to?
var serverUrl = "http://localhost:8090/"


var clientsConnected = 0;

setInterval(connectClient, 500);




function connectClient() {
	if(clientsConnected < clients)
	{
		var startTime = new Date();
		// if user is running mozilla then use it's built-in WebSocket
//		var WebSocket = require('websocket').client;

var sys = require('sys');
var WebSocket = require('./websocket').WebSocket;

var connection = new WebSocket('ws+unix://127.0.0.1:8090');

connection.addListener('message', function(message) {
      		var json = JSON.parse(message.data);
        
	        // console.debug(zoomLevel+"|"+json.vessels.length+"|"+(new Date().getTime() -timeQuery));
		var endTime = new Date();
		console.log('Client received response within ' + (endTime - startTime) + 'ms');
		});

connection.addListener('open', function() {
	var message = {};
	        message.function = "register"
        	message.zoom = zoomLevel;
        	message.bounds = bounds;
        	// connection.emit(JSON.stringify(message));
    connection.send(message);
});

    		// var connection = new WebSocket('');
    		// for (x in connection)
    		// {
    		// 	console.log(x+":"+connection[x]);
    		// }
    		// connection.emit('request');
    		

		clientsConnected++;
		console.log('Connected clients: ' + clientsConnected);

		
	}
}
