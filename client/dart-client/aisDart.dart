library caller;

import 'dart:html';
import 'dart:json';
import 'dart:math';
import 'dart:async';

import 'leaflet_maps.dart' as leaflet_maps;


var leaflet_map;
Map<String, Object> vessels = new Map<String, Object>();
WebSocket  socket;
Map<int, String> shipTypes = new Map<int, String>();
Map<int,String> shipTypeColors = new Map<int,String>();
Map<int,String> nav_stati = new Map<int,String>();
Map<int,String> aton_types = new Map<int,String>();
              // Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];


bool  encounteredError = false;
int retrySeconds = 2;
int timeFlex;



void main() {

  initWebSocket(2);
  initTypeArrays();
}

initMap(){
  String el_id = 'map';
  String height = window.innerHeight.toString();
  String width = window.innerWidth.toString();
  height = "$height px";
  width =   "$width px";
  List mapOptions = [new leaflet_maps.Coord(53.54, 9.91),15];
  leaflet_map = new leaflet_maps.OpenStreetMap(el_id, mapOptions, width:width, height:height);
  leaflet_map.loadMap();
  //leaflet_map.on.moveend(logMsg("moveend"));
}

logMsg(String msg){
    window.console.log(msg);
}

void initWebSocket(int retrySeconds) {
  
  logMsg("Connecting to Web socket");
   socket = new WebSocket('ws://192.168.1.112:8090');
   //socket = new WebSocket('ws://127.0.0.1:8090');
  
  socket.onOpen.listen((e){
    logMsg("Connected to Websocket-Server"); 
    if(leaflet_map==null)  initMap();
  });

  socket.onClose.listen((evt)
  {
    logMsg('web socket closed, retrying in $retrySeconds seconds');
    if (!encounteredError) 
    {
      new Timer(new Duration(seconds:1), () => initWebSocket(retrySeconds/**2*/));
    }
    encounteredError = true;
  });
  
  socket.onMessage.listen((evt)
  {
    var timeMessage = new DateTime.now().millisecondsSinceEpoch;
    var timeQuery = timeMessage - timeFlex;

    Map json = parse(evt.data);
    if (json['type'] == "vesselsInBoundsEvent")
    {
      logMsg("BoundsEvent: ${leaflet_map.getZoom()} ${json['vessels'].length} ${timeQuery}");
      processVesselsInBounds(json['vessels'], timeMessage);
    }
    if (json['type'] == "vesselPosEvent")
    {
      //logMsg("vesselsPositionEvent: ${json['vessel']}");
      processVesselPositionEvent(json['vessel']);
    }
  });
  
  socket.onError.listen((evt)
  {
    logMsg("Error connecting to ws ${evt.toString()}");
    if (!encounteredError) 
    {
      new Timer(new Duration(seconds:1), () => initWebSocket(retrySeconds/**2*/));
    }
    encounteredError = true;
  });
}

processVesselsInBounds(jsonArray, timeMessage){
  var currentZoom = leaflet_map.getZoom();
  vessels.forEach((k,v){
    if(v['polygon']!=null)
    {
//      leaflet_maps.AnimatedPolygon ap = v['polygon'];
//      ap.stopAnimation();
      v['polygon'].stopAnimation();
    }
    if (v['triangle']!= null)
    {
//      leaflet_maps.AnimatedPolygon ap = v['triangle'];
//      ap.stopAnimation();
      v['triangle'].stopAnimation();
    }
  });
  vessels.clear();
  leaflet_map.clearFeatureLayer();

  // male vessel-Marker, Polygone und speedVectoren in die karte
  // anschließend starte die Animation für Polygone und Schiffsdreiecke
  for (var x in jsonArray)
  {
    paintToMap(x, currentZoom, (vesselWithMapObjects){
      var timeStart = new DateTime.now().millisecondsSinceEpoch;
      vessels["${x['mmsi']}"] = vesselWithMapObjects;
      if (currentZoom > 12)
      {
        if(vesselWithMapObjects['triangle']!=null)
        {
          leaflet_maps.AnimatedPolygon ap = vesselWithMapObjects['triangle'];
          ap.startAnimation();
        }
        if(vesselWithMapObjects['polygon']!=null)
        {
          leaflet_maps.AnimatedPolygon ap = vesselWithMapObjects['polygon'];
          ap.startAnimation();
        }
      }
      var ts_posEvent = new DateTime.now().millisecondsSinceEpoch;
      //logMsg("painted in totally ${ts_posEvent - timeStart} ms\n");
    });
  }
//   zeige eine Infobox über die aktuelle minimal-Geschwindigkeit angezeigter Schiffe
  if (currentZoom < 13)
  {
    query('#zoomSpeed').text ="vessels reporting > ${ zoomSpeedArray[currentZoom]} knots";
    query('#zoomSpeed').style.display =  'block';
  }
  else
  {
    query('#zoomSpeed').style.display =  'none';
  }
  var timePainted = new DateTime.now().millisecondsSinceEpoch;
  logMsg("painted ${vessels.length}  ${timePainted - timeMessage} msec");
}

processVesselPositionEvent(json){
  //update or create vessel

  var timeStart = new DateTime.now().millisecondsSinceEpoch;
  var ts_vector, ts_polygon, ts_triangle;
  var vessel =vessels[json['userid'].toString()];
  if (vessel == null)
  {
    vessel = {};
    vessel['mmsi'] = json['userid'];
  }
  vessel['msgid'] =  json['msgid'];
  vessel['time_received'] = json['time_received'];
  vessel['cog'] = json['cog'];
  vessel['sog'] = json['sog'];
  vessel['pos'] = json['pos'];
  vessel['true_heading'] = json['true_heading'];

  if (vessel['vector'] != null)
  {
    vessel['vector'].remove(leaflet_map, true);
    vessel.remove('vector');
    //ts_vector= new Date.now().millisecondsSinceEpoch;
    //logMsg("vector removed ${ts_vector - timeStart}");
  }
  if (vessel['polygon'] != null)
  {
    vessel['polygon'].stopAnimation();
    vessel['polygon'].remove(leaflet_map, true);
    vessel.remove('polygon');
    //ts_polygon = new Date.now().millisecondsSinceEpoch;
    //logMsg("remove Polygon ${ts_polygon - timeStart}");
  }
  if (vessel['triangle'] != null)
  {
    vessel['triangle'].stopAnimation();
    vessel['triangle'].remove(leaflet_map, true);
    vessel.remove('triangle');
//    ts_triangle = new Date.now().millisecondsSinceEpoch;
//    logMsg("pos Event processed ${ts_triangle - timeStart}");
  }
    paintToMap(vessel, leaflet_map.getZoom(), (vesselWithMapObjects){
    vessels[json['userid'].toString()] = vesselWithMapObjects;
    if (leaflet_map.getZoom() > 12)
    {
      if (vesselWithMapObjects.containsKey('triangle'))
      {
        vesselWithMapObjects['triangle'].startAnimation();
      }
      if(vesselWithMapObjects.containsKey('polygon'))
      {
        vesselWithMapObjects['polygon'].startAnimation();
      }
    }
    var ts_posEvent = new DateTime.now().millisecondsSinceEpoch;
    //logMsg("painted in totally ${ts_posEvent - timeStart} ms\n");

  });
}

onClickHandler( e, mmsi){
  print("clickEvent on ${e.type} for ship ${mmsi}");
}
onMouseoutHandler(e){
//  print("mouseoutEvent on ${e.type}");
  leaflet_map.closePopup();
}
onMouseoverHandler(e, mmsi){
//  logMsg("mouseOverEvent on ${e} for ship ${mmsi}");
  var vessel = vessels["${mmsi}"];
  var pos = vessel['pos'];
  var latlong = new leaflet_maps.Coord(pos[1], pos[0]);
  var popupOptions = {'closeButton': false,
                      'autoPan': false,
                      'offset' : [50,-50]};
  String popupText = createMouseOverPopup(vessel);
  var popup = new leaflet_maps.Popup(latlong, popupText, popupOptions);
  popup.addTo(leaflet_map);
}

paintToMap(v,zoom, callback){

  if(v['pos'] != null)
  {
    var ts_flex = new DateTime.now().millisecondsSinceEpoch;

    leaflet_maps.Icon icon;
   // für Schiffe zeichne...
    if (v['msgid'] < 4 ||v['msgid'] == 5)
    {
      var moving = (v['sog'] !=null && v['sog'] > 0.4 && v['sog']!=102.3) ; //nur Schiffe, die sich mit mind. 0,3 Knoten bewegen
      var shipStatics = (leaflet_map.getZoom() > 11) &&  (v['cog'] !=null ||(v['true_heading']!=null && v['true_heading']!=0.0 && v['true_heading'] !=511)) && (v['dim_port'] !=null && v['dim_stern']!=null) ;

      v['brng'] = calcAngle(v);
      var cos_angle=cos(v['brng']);
      var sin_angle=sin(v['brng']);
      List<leaflet_maps.Coord> vectorPoints = new List();
      leaflet_maps.Coord shipPoint = new leaflet_maps.Coord(v['pos'][1],v['pos'][0]);
      vectorPoints.add(shipPoint);

      if (moving) //nur Schiffe, die sich mit mind. 1 Knoten bewegen
      {
        var meterProSekunde = v['sog'] *0.51444;
        var vectorLength = meterProSekunde * 30; //meter, die in 30 sec zurückgelegt werden
        var targetPoint = destinationPoint(v['pos'][1], v['pos'][0], v['cog'], vectorLength);
        //var targetPoint = calcVector(v['pos'][0],v['pos'][1], vectorLength, sin_angle, cos_angle);//destinationPoint(this.lat, this.lon, this.cog, vectorLength);
        vectorPoints.add(targetPoint);
        var vectorWidth = (v['sog'] > 30?5:2); 
        v['vector'] = new leaflet_maps.Polyline(vectorPoints, {'color': 'red', 'weight': vectorWidth });
        //logMsg("vector created ${new Date.now().millisecondsSinceEpoch -ts_flex}");
        ts_flex= new DateTime.now().millisecondsSinceEpoch;
        v['vector'].addTo(leaflet_map, true);
        //logMsg("vector added ${new Date.now().millisecondsSinceEpoch -ts_flex}");
        ts_flex= new DateTime.now().millisecondsSinceEpoch;
        var animationPartsSize = vectorLength/(zoom); //in wieviele Teilstücke wird der vector zerlegt
        var animationInterval = 2000; //wie lang ist die Zeitspanne zwischen zwei Animationsschritten
        if (shipStatics)
        {
          v['polygon'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
            'autoStart':false,
            'animation':true,
            'distance': animationPartsSize,
            'interval': animationInterval,
            'dim_stern':v['dim_stern'],
            'dim_port': v['dim_port'],
            'dim_bow':v['dim_bow'],
            'dim_starboard': v['dim_starboard'],
            'brng':v['brng'],
            'color': "blue",
            'weight': 3,
            'fill':true,
            'fillColor':shipTypeColors[v['ship_type']],
            'fillOpacity':0.6,
            'clickable':false
          }, v['mmsi']);
          //logMsg("polygon created ${new Date.now().millisecondsSinceEpoch -ts_flex}");
          ts_flex= new DateTime.now().millisecondsSinceEpoch;
          v['polygon'].addTo(leaflet_map, true);
          //logMsg("polygon added ${new Date.now().millisecondsSinceEpoch -ts_flex}");
          ts_flex= new DateTime.now().millisecondsSinceEpoch;
        }

        v['triangle'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
          'autoStart': false,
          'animation':true,
          'distance': animationPartsSize,
          'interval':animationInterval,
          'brng':v['brng'],
          'zoom': leaflet_map.getZoom(),
          'color': "black",
          'weight': 1,
          'fill':true,
          'fillColor': shipTypeColors[v['ship_type']],
          'fillOpacity':0.8,
          'clickable':true
        }, v['mmsi']);

        //logMsg("triangle created ${new Date.now().millisecondsSinceEpoch -ts_flex}");
        ts_flex= new DateTime.now().millisecondsSinceEpoch;
        v['triangle'].addTo(leaflet_map, true);
        //logMsg("triangle added ${new Date.now().millisecondsSinceEpoch -ts_flex}");
        ts_flex= new DateTime.now().millisecondsSinceEpoch;
        }
          else //zeichne für nicht fahrende Schiffe einen Circlemarker und möglichst ein Polygon
          {
            if(shipStatics)
            {
              v['polygon'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
                'autoStart':false,
                'animation':false,
                'dim_stern':v['dim_stern'],
                'dim_port': v['dim_port'],
                'dim_bow':v['dim_bow'],
                'dim_starboard': v['dim_starboard'],
                'brng':v['brng'],
                'color': "blue",
                'weight': 3,
                'fill':true,
                'fillColor':shipTypeColors[v['ship_type']],
                'fillOpacity':0.6,
                'clickable':false
              }, v['mmsi']);
              //logMsg("polygon created ${new Date.now().millisecondsSinceEpoch -ts_flex}");
              ts_flex= new DateTime.now().millisecondsSinceEpoch;
              v['polygon'].addTo(leaflet_map, true);
              //logMsg("polygon added ${new Date.now().millisecondsSinceEpoch -ts_flex}");
              ts_flex= new DateTime.now().millisecondsSinceEpoch;            }
              Map circleOptions = {
                                 'radius':5,
                                 'fill':true,
                                 'fillColor':shipTypeColors[v['ship_type']],
                                 'fillOpacity':0.8,
                                 'color':"#000000",
                                 'opacity':0.4,
                                 'weight':2.5
            };
            v['marker'] = new leaflet_maps.CircleMarker(vectorPoints[0], circleOptions, v['mmsi']);
            //logMsg("circle created ${new Date.now().millisecondsSinceEpoch -ts_flex}");
            ts_flex= new DateTime.now().millisecondsSinceEpoch;

            v['marker'].addTo(leaflet_map, true);
            //logMsg("circle added ${new Date.now().millisecondsSinceEpoch -ts_flex}");
            ts_flex= new DateTime.now().millisecondsSinceEpoch;
            }
        }
        else //message ist keine position- oder voyage-message
        {
          Map iconOptions = chooseIconOptions(v);
          icon = new leaflet_maps.Icon(iconOptions['iconUrl'],iconOptions['iconSize']);
          v['marker'] = new leaflet_maps.Marker(v['pos'][1],v['pos'][0], v['name'],false);
          v['marker'].setIcon(icon);
          v['marker'].addTo(leaflet_map, true);
        }
        callback(v);
      }
    }

Map<String, leaflet_maps.Dimension> chooseIconOptions(obj){
       var iconUrl;
       var zoom = leaflet_map.getZoom();
       leaflet_maps.Dimension size;
       var popupAnchor;
       var iconAnchor;

        if(obj['msgid'] == 21)
        {
         iconUrl =  "../images/atons/aton_${obj['aton_type']}.png";
         size = new leaflet_maps.Dimension(zoom,zoom);
         return {'iconUrl': iconUrl, 'iconSize': size};
       }
       else if(obj['msgid'] == 4)
       {
         iconUrl =   "../images/baseStation.png";
         size = new leaflet_maps.Dimension(zoom-1,zoom-1);
         return {'iconUrl': iconUrl, 'iconSize': size};
       }
       else if (obj['msgid'] ==9)
       {
          iconUrl =   "../images/helicopter.png";
          size = new leaflet_maps.Dimension(3*zoom,3*zoom);
          return {'iconUrl': iconUrl, 'iconSize': size};
       }
}

String createMouseOverPopup(vessel){
  String mouseOverPopup ="<div class='mouseOverPopup'><table>";
  if(vessel['msgid'] == 21)
  {
    if(vessel['name']!=null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    }
    mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
    if(vessel['aton_type'] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${aton_types[vessel['aton_type']]}</b></nobr></td></tr>";
    }
  }
  else if(vessel['msgid'] == 4)
  {
    mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>AIS Base Station</b></nobr></td></tr>";
    if(vessel['name']) {
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    }
    mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
  }
  else if(vessel['msgid'] == 9)
  {
    mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>Helicopter SAR</b></nobr></td></tr>";
    if(vessel['name'])mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
    if(vessel['altitude'])mouseOverPopup = "${mouseOverPopup}<tr><td>Altitude: &nbsp;</td><td><nobr>${vessel['altitude'].toString()}</nobr></td></tr>";
  }
  else
  {
    if(vessel['name']!= null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    }
    if(vessel['imo']!= null && vessel['imo'] !="0") {
      mouseOverPopup = "${mouseOverPopup}<tr><td>IMO</td><td>${vessel['imo']}</b></nobr></td></tr>";
    }
      mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
    if(vessel['nav_status']!=null && vessel['nav_status'] < 15 && vessel['nav_status'] > -1) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>NavStatus: &nbsp;</td><td><nobr>${nav_stati[vessel['nav_status']]}</nobr></td></tr>";
    }
    if(vessel['sog']!= null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Speed: &nbsp;</td><td><nobr>${vessel['sog'].toString()}</nobr></td></tr>";
    }
    if(vessel['true_heading'] != null && vessel['true_heading'] != 511) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Heading: &nbsp;</td><td><nobr>${vessel['true_heading'].toString()}</nobr></td></tr>";
    }
    if(vessel['cog'] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Course: &nbsp;</td><td><nobr>${vessel['cog'].toString()}</nobr></td></tr>";
    }
    var time = new DateTime.fromMillisecondsSinceEpoch(vessel['time_received'],isUtc: false);
    var timeString = time.toString().substring(0, 16);
    mouseOverPopup = "${mouseOverPopup}<tr><td>TimeReceived: &nbsp;</td><td><nobr>${timeString}</nobr></td></tr>";
    if(vessel['dest'] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Dest</td><td>${vessel['dest']}</b></nobr></td></tr>";
    }
    if(vessel['draught'] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>draught</td><td>${(vessel['draught']/10).toString()}</b></nobr></td></tr>";
    }
    if(vessel['dim_bow'] != null && vessel['dim_port'] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>length, width</td><td>${(vessel['dim_stern']+vessel['dim_bow']).toString()},"
      "${(vessel['dim_starboard']+vessel['dim_port']).toString()}</b></nobr></td></tr>";
    }
    if (shipTypes[vessel['ship_type']] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>ship_type</td><td>${shipTypes[vessel['ship_type']]}</b></nobr></td></tr>";
    }
    //if(vessel['rot'] != null) mouseOverPopup = "${mouseOverPopup}<tr><td>Rotation</td><td>${vessel['rot'].toString()}</b></nobr></td></tr>";
  }
  mouseOverPopup = "${mouseOverPopup}</table></div>";
  return mouseOverPopup;
}
num calcAngle(vessel) {
  //benötigte Daten
  var hdg = vessel['true_heading'];
  var cog = vessel['cog'];
  var lon = vessel['pos'][0];
  var lat = vessel['pos'][1];
  var sog = vessel['sog'];
  var direction = 0;
  if (vessel['mmsi'] == 211855000)
  {
    direction = 299;
  }
  if (sog!=null && sog > 0.4 && cog < 360)
  {
    direction = cog;
  }
  else if (hdg!=null && hdg > 0.0 && hdg !=511 &&hdg < 360)
  {
    direction = hdg;
  }
  return (-direction *(PI / 180.0));
}

leaflet_maps.Coord calcVector(lon, lat, sog, sinus, cosinus){
  var dy_deg = -(sog * cosinus)/10000;
  var dx_deg = -(- sog * sinus)/cos((lat)*(PI/180.0))/10000;
  return new leaflet_maps.Coord(lat - dy_deg, lon - dx_deg);
}

leaflet_maps.Coord destinationPoint(lat, lng, cog, dist) {
   dist = dist / 6371000;  
   var brng = cog * (PI / 180);  
   var lat1 = lat * (PI / 180);
   var lon1 = lng * (PI / 180);
   var lat2 = asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(brng));
   var lon2 = lon1 + atan2(sin(brng) * sin(dist) * cos(lat1), cos(dist) - sin(lat1) * sin(lat2));
   if (lat2.isNaN || lon2.isNaN) return null;
   lat2 = lat2 *(180/PI);
   lon2 = lon2 *(180/PI);
   return new leaflet_maps.Coord(lat2, lon2);
}

initTypeArrays(){
    shipTypes[2] = 'Other Type';
    shipTypes[6] = 'Passenger Ships';
    shipTypes[7] = 'Cargo Ships';
    shipTypes[8] = 'Tankers';
    shipTypes[9] = 'Other Type';
    shipTypes[20] = 'Wing in ground (WIG)';
    shipTypes[29] = 'Wing in ground (WIG)';
    shipTypes[30] ='Fishing';
    shipTypes[31] ='Towing';
    shipTypes[32] ='Towing';
    shipTypes[33] ='Dredger';
    shipTypes[34] ='diving operations';
    shipTypes[35] ='military operations';
    shipTypes[36] = 'Sailing';
    shipTypes[37] = 'Pleasure craft';
    shipTypes[38] = 'Reserved';
    shipTypes[39] = 'Reserved';
    shipTypes[40] = 'High speed craft';
    shipTypes[49] = 'High speed craft';
    shipTypes[50] ='Pilot vessel';
    shipTypes[51] ='Search and rescue vessels';
    shipTypes[52] ='Tugs';
    shipTypes[53] ='Port tenders';
    shipTypes[54] ='anti-pollution vessels';
    shipTypes[55] ='Law enforcement vessels';
    shipTypes[56] ='Spare for local vessels';
    shipTypes[57] ='Spare for local vessels';
    shipTypes[58] ='Medical transports';
    shipTypes[59] = 'Ships according to RR';
    shipTypes[60] = 'Passenger Ships';
    shipTypes[61] = 'Passenger Ships';
    shipTypes[63] = 'Passenger Ships';
    shipTypes[65] = 'Passenger Ships';
    shipTypes[67] = 'Passenger Ships';
    shipTypes[69] = 'Passenger Ships';
    shipTypes[70] = 'Cargo Ships';
    shipTypes[71] = 'Cargo Ships';
    shipTypes[72] = 'Cargo Ships';
    shipTypes[73] = 'Cargo Ships';
    shipTypes[74] = 'Cargo Ships';
    shipTypes[77] = 'Cargo Ships';
    shipTypes[79] = 'Cargo Ships';
    shipTypes[80] = 'Tanker';
    shipTypes[81] = 'Tanker';
    shipTypes[82] = 'Tanker';
    shipTypes[83] = 'Tanker';
    shipTypes[84] = 'Tanker';
    shipTypes[89] = 'Tanker';
    shipTypes[90] = 'Other Type';
    shipTypes[91] = 'Other Type';
    shipTypes[97] = 'Other Type';
    shipTypes[99] = 'Other Type';
    
    
    
    shipTypeColors[2] ='#f9f9f9';
    shipTypeColors[20] ='#f9f9f9';
    shipTypeColors[29] ='#f9f9f9';
    shipTypeColors[30] ='#f99d7b'/*brown, Fishing*/;
    shipTypeColors[31] ='#4dfffe'/*lightblue, Towing*/;
    shipTypeColors[32] ='#4dfffe'/*lightblue, Towing*/;
    shipTypeColors[33] ='#f9f9f9'/*gray, Dredger*/;
    shipTypeColors[34] ='white'/*Engaged in diving operations*/;
    shipTypeColors[35] ='white'/*Engaged in military operations*/;
    shipTypeColors[36] ='#f900fe'/*violett, Sailing*/;
    shipTypeColors[37] ='#f900fe'/*violett, Pleasure craft*/;
    shipTypeColors[40] ='#f9f9f9'/*Highspeed*/;
    shipTypeColors[49] ='#f9f9f9'/*Highspeed*/;
    shipTypeColors[50] ='red'/*Pilot vessel*/;
    shipTypeColors[51] ='white' /*Search and rescue vessels*/;
    shipTypeColors[52] ='#4dfffe'/*lightblue, Tugs*/;
    shipTypeColors[53] ='#4dfffe'/*lightblue, Port tenders*/;
    shipTypeColors[54] ='white'/*anti-pollution vessels*/;
    shipTypeColors[55] ='white'/*Law enforcement vessels*/;
    shipTypeColors[56] ='#d2d2d2'/*not classified => used as default by vesseltracker*/;
    shipTypeColors[57] ='white'/*Spare for local vessels*/;
    shipTypeColors[58] ='white'/*Medical transports*/;
    shipTypeColors[59] ='white'/*Ships according to RR*/;
    shipTypeColors[6] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[60] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[61] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[63] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[65] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[67] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[69] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[7] = '#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[70] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[71] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[72] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[73] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[74] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[77] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[79] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[8] = '#f70016'/*red, Tankers*/;
    shipTypeColors[80] ='#f70016'/*Tanker*/;
    shipTypeColors[81] = '#f70016'/*red, Tankers*/;
    shipTypeColors[82] = '#f70016'/*red, Tankers*/;
    shipTypeColors[83] = '#f70016'/*red, Tankers*/;
    shipTypeColors[84] = '#f70016'/*red, Tankers*/;
    shipTypeColors[89] ='#f70016'/*red,Tankers*/;
    shipTypeColors[9] ='#d2d2d2'/*Other Type*/;
    shipTypeColors[90] ='#d2d2d2'/*Other Type*/;
    shipTypeColors[91] ='#d2d2d2'/*Other Type*/;
    shipTypeColors[97] ='#d2d2d2'/*Other Type*/;
    shipTypeColors[99] ='#d2d2d2'/*Other Type*/;

    nav_stati[0] ='under way us. engine';
    nav_stati[1] ='at anchor';
    nav_stati[2] = 'not under command';
    nav_stati[3] = 'restr. maneuverability';
    nav_stati[4] = 'constr. by draught';
    nav_stati[5] = 'moored';
    nav_stati[6] = 'aground';
    nav_stati[7] = 'engaged in fishing';
    nav_stati[8] = 'under way sailing';
    nav_stati[9] = 'future use';
    nav_stati[10] = 'future use';
    nav_stati[11] = 'future use';
    nav_stati[12] = 'future use';
    nav_stati[13] = 'future use';
    nav_stati[14] = 'AIS-SART (active)';
    nav_stati[15] = 'not defined';


    aton_types[0] ='notSpecified';
    aton_types[1] ='ReferencePoint';
    aton_types[2] = 'RACON';
    aton_types[3] = 'off-shoreStructure';
    aton_types[4] = 'futureUse';
    aton_types[5] = 'LightWithoutSectors';
    aton_types[6] = 'LightWithSectors';
    aton_types[7] = 'LeadingLightFront';
    aton_types[8] = 'LeadingLightRear';
    aton_types[9] = 'BeaconCardinalN';
    aton_types[10] = 'BeaconCardinalE';
    aton_types[11] = 'BeaconCardinalS';
    aton_types[12] = 'BeaconCardinalW';
    aton_types[13] = 'BeaconPorthand';
    aton_types[14] = 'BeaconStarboardhand';
    aton_types[15] = 'BeaconPreferredChannelPortHand';
    aton_types[16] = 'BeaconPreferredChannelStarboardHand';
    aton_types[17] = 'BeaconIsolatedDanger';
    aton_types[18] = 'BeacoSafeWater';
    aton_types[19] = 'BeaconSpecialMark';
    aton_types[20] = 'CardinalMarkN';
    aton_types[21] = 'CardinalMarkE';
    aton_types[22] = 'CardinalMarkS';
    aton_types[23] = 'CardinalMarkW';
    aton_types[24] = 'PortHandMark';
    aton_types[25] = 'StarboardHandMark';
    aton_types[26] = 'PreferredChannelPortHand';
    aton_types[27] = 'PreferredChannelStarboardHand';
    aton_types[28] = 'IsolatedDanger';
    aton_types[29] = 'SafeWater';
    aton_types[30] = 'SpecialMark';
    aton_types[31] = 'LightVessel/LANBY/Rigs';
 }