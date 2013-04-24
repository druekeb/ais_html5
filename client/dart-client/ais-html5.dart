library caller;

import 'dart:html';
import 'dart:json';

import 'dart:async';

import 'LeafletMap.dart' as LM;
import 'Vessel.dart';


/* Array that defines for every zoomlevel the minimun speed of a displayed vessel:
               Zoomlevel 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18 */
List ZOOM_SPEED_ARRAY = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];
const WEBSOCKET_SERVER_LOCATION = '192.168.1.112';
const WEBSOCKET_SERVER_PORT = 8090;
const ANIMATION_MINIMAL_ZOOMLEVEL =13;

var leaflet_map;
Map<String, Vessel> vessels = new Map<String, Vessel>();
WebSocket  socket;

bool  encounteredError = false;
int retrySeconds = 2;
int boundsTimeout = 300;

/*Startpoint for Dart-Client-Application*/
void main() {
  double zoom = 17.0;
  double lon = 9.947;
  double lat = 53.518;
  if (getParam('zoom')!= null)
  {
    zoom = getParam('zoom');
  }
  if (getParam('lon') != null)
  {
    lon = getParam('lon'); 
  }
  if (getParam('lat') != null)
  {
    lat = getParam('lat');
  }

  initWebSocket(2,(){
    if(leaflet_map==null)  
    {
      initMap( zoom,lon, lat);
    }
  });
  initTypeArrays();
  
}

/* load Leaflet-Map into mapDiv*/
initMap(double zoom, double lon, double lat){
  String mapDiv_id = 'map';
  String height = window.innerHeight.toString();
  String width = window.innerWidth.toString();
  height = "$height px";
  width =  "$width px";
  List mapOptions = [new LM.Coord(lat, lon),zoom, boundsTimeout];
  leaflet_map = new LM.OpenStreetMap(mapDiv_id, mapOptions, width:width, height:height);
  leaflet_map.loadMap();
}

/*Logger for console output in Browser*/
logMsg(String msg){
    window.console.log(msg);
}

/*initialize websocket-Connection*/
void initWebSocket(int retrySeconds, callback) {
  logMsg("Connecting to Web socket");
  socket = new WebSocket('ws://${WEBSOCKET_SERVER_LOCATION}:${WEBSOCKET_SERVER_PORT}');
  
  socket.onOpen.listen((e){
    logMsg("Connected to Websocket-Server"); 
    callback();
  });

  socket.onClose.listen((evt)
  {
    logMsg('web socket closed, retrying in $retrySeconds seconds');
    if (!encounteredError) 
    {
      new Timer(new Duration(seconds:1), () => initWebSocket(retrySeconds,(){}));
    }
    encounteredError = true;
  });

  /*process messages from websocketServer*/
  socket.onMessage.listen((evt)
  {
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
  
  socket.onError.listen((evt)
  {
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
  var currentZoom = leaflet_map.getZoom();
  /*stop all animations, remove all vessels from vessels-Array and then remove all features from map*/
  vessels.forEach((k,v){
    if(v.polygon !=null)
    {
      v.polygon.stopAnimation();
    }
    if (v.triangle != null)
    {
      v.triangle.stopAnimation();
    }
  });
  vessels.clear();
  leaflet_map.clearFeatureLayer();
  
  /* create new Vessel with Objects (Polygons, Circles) and paint to Map */
  for (var x in jsonArray)
  {
    var vessel = new Vessel(x);
    vessel.paintToMap(currentZoom, (){
      if (currentZoom >= ANIMATION_MINIMAL_ZOOMLEVEL)
      {
        if(vessel.triangle !=null)
        {
          vessel.triangle.startAnimation();
        }
        if(vessel.polygon !=null)
        {
          vessel.polygon.startAnimation();
        }
      }
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
//  var ts_vector, ts_polygon, ts_triangle;
  var vessel =vessels[json['userid'].toString()];
  //create a new Vessel, if it's not yet in vessels-Array
  if (vessel == null)
  {
    vessel = new Vessel(json);
  }
  else
  {
    vessel.updatePosition(json);
    if (vessel.vector != null)
    {
      vessel.vector.remove(leaflet_map, true);
      vessel.vector = null;
    }
    if (vessel.polygon != null)
    {
      vessel.polygon.stopAnimation();
      vessel.polygon.remove(leaflet_map, true);
      vessel.polygon = null;
    }
    if (vessel.triangle != null)
    {
      vessel.triangle.stopAnimation();
      vessel.triangle.remove(leaflet_map, true);
      vessel.triangle = null;
    }
  }
  vessel.paintToMap(leaflet_map.getZoom(), (){
    if (leaflet_map.getZoom() >= ANIMATION_MINIMAL_ZOOMLEVEL)
    {
      if (vessel.triangle != null)
      {
        vessel.triangle.startAnimation();
      }
      if(vessel.polygon != null)
      {
        vessel.polygon.startAnimation();
      }
    }
  });
}

/*MouseEvent-Handlers*/
onClickHandler( e, mmsi){
}
onMouseoutHandler(e){
  leaflet_map.closePopup();
}
onMouseoverHandler(e, mmsi){
  var vessel = vessels["${mmsi}"];
  var latlong = new LM.Coord(vessel.pos[1], vessel.pos[0]);
  var popupOptions = {'closeButton': false,
                      'autoPan': false,
                      'offset' : [50,-50]};
  String popupText = vessel.createMouseOverPopup();
  var popup = new LM.Popup(latlong, popupText, popupOptions);
  popup.addTo(leaflet_map);
}

int getFirstNegative(List sZA){
  for (var x = 0; x < sZA.length;x++)
  { 
    if (sZA[x].isNegative)
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



