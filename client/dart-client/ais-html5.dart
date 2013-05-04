library ais;

import 'dart:html';
import 'dart:json';
import 'dart:async';

import 'LeafletMap.dart';
import 'Vessel.dart';
import 'packages/js/js.dart' as js;


/* Array that defines for every zoomlevel the minimun speed of a displayed vessel:
               Zoomlevel 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18 */
List ZOOM_SPEED_ARRAY = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];
const WEBSOCKET_SERVER_LOCATION = '127.0.0.1';
const WEBSOCKET_SERVER_PORT = 8090;
const ANIMATION_MINIMAL_ZOOMLEVEL =13;
const RETRY_SECONDS = 2; 
const BOUNDS_TIMEOUT = 300; //Reload of page every 5 min to get Vessels in Bounds

var LMap;
Map<String, Vessel> vessels = new Map<String, Vessel>();
WebSocket  socket;

bool  encounteredError = false;

/*Logger for console output in Browser*/
logMsg(String msg){
    window.console.log(msg);
}

/*Startpoint for Dart-Client-Application*/
void main(){
  double initialZoom = 17.0;
  double initialLon = 9.947;
  double initialLat = 53.518;
  if (getParam('zoom')!= null)
  {
    initialZoom = getParam('zoom');
  }
  if (getParam('lon') != null)
  {
    initialLon = getParam('lon'); 
  }
  if (getParam('lat') != null)
  {
    initialLat = getParam('lat');
  }
  initTypeMaps();
  initWebSocket(RETRY_SECONDS,(){
    if(LMap==null)  
    {
      initMap(initialLat, initialLon, initialZoom);
    }
  });
}

/* load Leaflet-Map into mapDiv*/
initMap(double initialLat, double initialLon, double initialZoom){
  String mapDiv_id = 'map';
  var initOptions = js.map({
    'lat':initialLat,
    'lon':initialLon,
    'zoom':initialZoom,
    'boundsTimeout':BOUNDS_TIMEOUT,
    'mousePosition': js.map({'numDigits': 5  })
    });
  var mapOptions = js.map({
    'closePopupOnClick':true,
    'markerZoomAnimation': false,
    'zoomAnimation': false,
    'worldCopyJump': true,
    'maxZoom': 18,
    'minZoom': 3
    });
  var tileLayerOptions = js.map({
    'tileURL': 'http://{s}.tiles.vesseltracker.com/vesseltracker/{z}/{x}/{y}.png',
    'attribution': 'Map-Data <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-By-SA</a> by <a href="http://openstreetmap.org/">OpenStreetMap</a> contributors target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>', 
    'subdomains': '["otile1","otile2","otile3","otile4"]' 
  });
  LMap = new LeafletMap(mapDiv_id, mapOptions, initOptions, tileLayerOptions);
}

/*initialize websocket-Connection*/
void initWebSocket(int retrySeconds, callback) {
  logMsg("Connecting to Web socket");
  socket = new WebSocket('ws://${WEBSOCKET_SERVER_LOCATION}:${WEBSOCKET_SERVER_PORT}');
  
  socket.onOpen.listen((e){
    logMsg("Connected to Websocket-Server"); 
    callback();
  });

  socket.onClose.listen((evt){
    logMsg('web socket closed, retrying in $retrySeconds seconds');
    if (!encounteredError) 
    {
      new Timer(new Duration(seconds:1), () => initWebSocket(retrySeconds,(){}));
    }
    encounteredError = true;
  });

  /*process messages from websocketServer*/
  socket.onMessage.listen((evt){
    Map json = parse(evt.data);
    if (json['type'] == "vesselsInBoundsEvent")
    {
      processVesselsInBounds(json['vessels']);
    }
    if (json['type'] == "vesselPosEvent")
    {
      processVesselPositionEvent(json['vessel']);
    }
  });
  
  socket.onError.listen((evt){
    logMsg("Error connecting to ws ${evt.toString()}");
    if (!encounteredError) 
    {
      new Timer(new Duration(seconds:1), () => initWebSocket(retrySeconds,(){}));
    }
    encounteredError = true;
  });
}

/*process a websocketServerResponse with all Vessels in queried bounds*/
processVesselsInBounds(jsonArray){
  int currentZoom = LMap.getZoom();
  /*stop all animations, remove all vessels from vessels-Array and then remove all features from map*/
  vessels.forEach((k,v){
    LMap.removeFeatures(v);
    });
  vessels.clear();
  
  /* create new Vessel with Objects (Polygons, Circles) and paint to Map */
  for (var x in jsonArray)
  {
    var vessel = new Vessel(x);
    vessel.paintToMap(currentZoom, (){
      vessels["${x['mmsi']}"] = vessel;
    });
  }
  //display an Infobox with the current minimal speed of displayed vessels
  if (currentZoom < (getFirstNegative(ZOOM_SPEED_ARRAY)))
  {
    query('#zoomSpeed').text ="vessels reporting > ${ ZOOM_SPEED_ARRAY[currentZoom]} knots";
    query('#zoomSpeed').style.display =  'block';
  }
  else
  {
    query('#zoomSpeed').style.display =  'none';
  }
}

/*process a Position update, initialized by the Websocket-Server*/
processVesselPositionEvent(json){
  var vessel = vessels[json['userid'].toString()];
  //create a new Vessel, if it's not yet in vessels-Array
  if (vessel == null)
  {
    vessel = new Vessel(json);
  }
  else
  {
    LMap.removeFeatures(vessel);
    vessel.updatePosition(json);
  }
  vessel.paintToMap(LMap.getZoom(), (){
    vessels[json['userid'].toString()] = vessel;
  });
}

int getFirstNegative(List zs_Array){
  for (var x = 0; x < zs_Array.length;x++)
  { 
    if (zs_Array[x].isNegative)
      return x;
  }
}

double getParam(String name){
  name = name.replaceAll("/[\[]/","\\\[").replaceAll("/[\]]/","\\\]");
  var regexS = "[\\?&]"+name+"=([^&#]*)";
  RegExp regex = new RegExp( regexS );
  Match results = regex.firstMatch(window.location.href);

  if (results != null)
    return double.parse(results.group(1));
  else return null;
}