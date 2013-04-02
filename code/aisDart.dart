library caller;

import 'dart:html';
import 'dart:json';
import 'dart:math';

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


void main() {
  initMap();
  initTypeArrays();
  initWebSocket();
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
}

logMsg(String msg){
    window.console.log(msg);
}

void initWebSocket([int retrySeconds = 2]) {
  bool encounteredError = false;
  
  logMsg("Connecting to Web socket");
  socket = new WebSocket('ws://127.0.0.1:8090');
  
  socket.on.open.add((e) {
    logMsg('Connected');
    changeRegistration();
  });
  
  socket.on.close.add((e) {
    logMsg('web socket closed, retrying in $retrySeconds seconds');
    if (!encounteredError) {
      window.setTimeout(() => initWebSocket(retrySeconds*2), 1000*retrySeconds);
    }
    encounteredError = true;
  });
  
  socket.on.error.add((e) {
    logMsg("Error connecting to ws");
    if (!encounteredError) {
      window.setTimeout(() => initWebSocket(retrySeconds*2), 1000*retrySeconds);
    }
    encounteredError = true;
  });
  
  socket.on.message.add((MessageEvent e) {
    logMsg('received message ${e.data}');
    Map json = JSON.parse(e.data);
    if (json['type'] == "vesselsInBoundsEvent")
    {
      logMsg("vesselsInBoundsEvent: ${json['vessels'].length}");
      processVesselsInBounds(json['vessels']);
    }
    if (json['type'] == "vesselPosEvent")
    {
      logMsg("vesselsPositionEvent: ${json['vessel']}");
      processVesselPositionEvent(json['vessel']);
    }
  });
}

changeRegistration()
{
  var zoom = leaflet_map.getZoom();
  if(zoom < 3)
  { 
    leaflet_map.zoomTo(3);
    return;
  }
  zoom.toString();
  window.console.debug("zoomLevel= $zoom");
  var boundsArray = leaflet_map.getBounds();
  var _southWest = {"lat":boundsArray[0],"lng":boundsArray[1]};
  var _northEast= {"lat":boundsArray[2],"lng":boundsArray[3]};
  var bounds = {"_southWest": _southWest,"_northEast":_northEast};

  Map message = new Map();
  message['function'] = 'register';
  message['zoom'] =  zoom;
  message['bounds'] = bounds;

  socket.send(JSON.stringify(message));
} 

processVesselsInBounds(jsonArray){
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
    paintToMap(x, (vesselWithMapObjects){
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
    });
  }
//   zeige eine Infobox über die aktuelle minimal-Geschwindigkeit angezeigter Schiffe
  if (currentZoom > 13)
  {
    query('#zoomSpeed').text ="vessels reporting > ${ zoomSpeedArray[currentZoom]} knots";
    query('#zoomSpeed').style.display =  'block';
  }
  else 
  {
    query('#zoomSpeed').style.display =  'none';
  }
}

processVesselPositionEvent(json){
  //update or create vessel
  var vessel =vessels[json['userid'].toString()];
  if (vessel == null)
  {
    vessel = {};
    vessel['mmsi'] = json['userid'];
  }
  vessel['msgid'] =  json['msgid'];
  vessel['time_received'] = json['time_received'];
  vessel['cog'] = json['cog'] /10;
  vessel['sog'] = json['sog'] /10;
  vessel['pos'] = json['pos'];
  vessel['true_heading'] = json['true_heading'];
  if (vessel['vector'] != null)
  {
    logMsg("remove Vector");
    vessel['vector'].remove(leaflet_map, true);
    vessel.remove('vector');
  }
  if (vessel['polygon'] != null)
  {
    logMsg("remove Polygon");
    vessel['polygon'].stopAnimation();
    vessel['polygon'].remove(leaflet_map, true);
    vessel.remove('polygon');
  }
  if (vessel['triangle'] != null)
  {
    logMsg("remove Triangle");
    vessel['triangle'].stopAnimation();
    vessel['triangle'].remove(leaflet_map, true);
    vessel.remove('triangle');
  }
    paintToMap(vessel, (vesselWithMapObjects){
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
  });
}

onClickHandler( e, mmsi){
  print("clickEvent on ${e.type} for ship ${mmsi}");
}
onMouseoutHandler(e){
  print("mouseoutEvent on ${e.type}");
  //leaflet_map.closePopup();
}
onMouseoverHandler(e, mmsi){
  print("mouseOverEvent on ${e} for ship ${mmsi}");
  var vessel = vessels["${mmsi}"];
  var pos = vessel['pos'];
  var latlong = new leaflet_maps.Coord(pos[1], pos[0]);
  var popupOptions = {'closeButton': false,
                      'autoPan': false,
                      'offset' : [0,40]}; 
  String popupText = createMouseOverPopup(vessel);
  var popup = new leaflet_maps.Popup(latlong, popupText, popupOptions);
  popup.addTo(leaflet_map);
}

paintToMap(v, callback){
  if(v['pos'] != null)
  {    
    if(!v.containsKey('ship_type'))v['ship_type']=56;
    leaflet_maps.Icon icon;
   // für Schiffe zeichne... 
    if (v['msgid'] < 4 ||v['msgid'] == 5)
    {
      var moving = (v['sog'] !=null && v['sog'] > 0.4 && v['sog']!=102.3) ; //nur Schiffe, die sich mit mind. 0,3 Knoten bewegen
      var shipStatics = (leaflet_map.getZoom() > 11) &&  (v['cog'] !=null ||(v['true_heading']!=null && v['true_heading']!=0.0 && v['true_heading'] !=511)) && (v['dim_port'] !=null && v['dim_stern']!=null) ;
      
      v['angle'] = calcAngle(v);
      var cos_angle=cos(v['angle']);
      var sin_angle=sin(v['angle']);
  
      var vectorLength;
      if(v['sog'] >30) vectorLength = v['sog']/10; else vectorLength = v['sog'];
      var vectorWidth;
      if(v['sog'] >30){ vectorWidth = 5; } else { vectorWidth = 2;}
    
      List<leaflet_maps.Coord> vectorPoints = new List();
      leaflet_maps.Coord shipPoint = new leaflet_maps.Coord(v['pos'][1],v['pos'][0]);
      vectorPoints.add(shipPoint);
      
      if (moving) //nur Schiffe, die sich mit mind. 1 Knoten bewegen
      {
        vectorPoints.add(shipPoint);
        vectorPoints.add(shipPoint);
        var targetPoint = calcVector(v['pos'][0],v['pos'][1], vectorLength, sin_angle, cos_angle);
        vectorPoints.add(targetPoint);
        v['vector'] = new leaflet_maps.Polyline(vectorPoints, {'color': 'red', 'weight': vectorWidth });
        v['vector'].addTo(leaflet_map, true);
        if (shipStatics)
        {
          v['polygon'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
            'autoStart':false,
            'animation':true,
            'distance': vectorLength/10,
            'interval': 200,
            'dim_stern':v['dim_stern'],
            'dim_port': v['dim_port'],
            'dim_bow':v['dim_bow'],
            'dim_starboard': v['dim_starboard'],
            'angle': v['angle'],
            'color': "blue",
            'weight': 3,
            'fill':true,
            'fillColor':shipTypeColors[v['ship_type']],
            'fillOpacity':0.6,
            'clickable':false
          }, v['mmsi']);
          v['polygon'].addTo(leaflet_map, true); 
        }

        v['triangle'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
          'autoStart': false,
          'animation':true,
          'distance': vectorLength/10,
          'interval':200,
          'angle': v['angle'],
          'zoom': leaflet_map.getZoom(),
          'color': "black",
          'weight': 1,
          'fill':true,
          'fillColor': shipTypeColors[v['ship_type']],
          'fillOpacity':0.8,
          'clickable':true
        }, v['mmsi']);
        v['triangle'].addTo(leaflet_map, true);
          }
          else //zeichne für nicht fahrende Schiffe einen Circlemarker und möglichst ein Polygon
          {
            if(shipStatics)
            {
              v['polygon'] = new leaflet_maps.AnimatedPolygon(vectorPoints,{
                'autoStart':false,
                'animation':false,
                'distance': vectorLength/10,
                'interval': 200,
                'dim_stern':v['dim_stern'],
                'dim_port': v['dim_port'],
                'dim_bow':v['dim_bow'],
                'dim_starboard': v['dim_starboard'],
                'angle': v['angle'],
                'color': "blue",
                'weight': 3,
                'fill':true,
                'fillColor':shipTypeColors[v['ship_type']],
                'fillOpacity':0.6,
                'clickable':false
              }, v['mmsi']);
              v['polygon'].addTo(leaflet_map, true); 
            }
            Map circleOptions = {
                                 'radius':4,
                                 'fill':true,
                                 'fillColor':shipTypeColors[v['ship_type']],
                                 'fillOpacity':0.8,
                                 'color':"#000000",
                                 'strokeOpacity':1,
                                 'strokeWidth':0.5
            };
            v['marker'] = new leaflet_maps.CircleMarker(vectorPoints[0], circleOptions, v['mmsi']);
            v['marker'].addTo(leaflet_map, true); 
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
         iconUrl =  "images/atons/aton_${obj['aton_type']}.png";
         size = new leaflet_maps.Dimension(zoom,zoom);
         return {'iconUrl': iconUrl, 'iconSize': size};
       }
       else if(obj['msgid'] == 4)
       {
         iconUrl =   "images/baseStation.png";
         size = new leaflet_maps.Dimension(zoom-1,zoom-1);
         return {'iconUrl': iconUrl, 'iconSize': size};
       }
       else if (obj['msgid'] ==9)
       {
          iconUrl =   "images/helicopter.png";
          size = new leaflet_maps.Dimension(3*zoom,3*zoom);
          return {'iconUrl': iconUrl, 'iconSize': size};
       }
       else
       {
          iconUrl =  "http://images.vesseltracker.com/images/googlemaps/icon_lastpos.png";
          size = new leaflet_maps.Dimension(6+2*log(zoom),6+2*log(zoom));
          return {'iconUrl': iconUrl, 'iconSize': size};
      }
}

String createMouseOverPopup(vessel){
  String mouseOverPopup ="<div class='mouseOverPopup'><table>";
  if(vessel['msgid'] == 21)
  {
    if(vessel['name']!=null)
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
    if(vessel['aton_type'] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${aton_types[vessel['aton_type']]}</b></nobr></td></tr>";
  }
  else if(vessel['msgid'] == 4)
  {
    mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>AIS Base Station</b></nobr></td></tr>";
    if(vessel['name'])
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
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
    if(vessel['name']!= null)
      mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${vessel['name']}</b></nobr></td></tr>";
    if(vessel['imo']!= null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>IMO</td><td>${vessel['imo']}</b></nobr></td></tr>";
      mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${vessel['mmsi'].toString()}</nobr></td></tr>";
    if(vessel['nav_status']!=null && vessel['nav_status'] < 15 && vessel['nav_status'] > -1)
      mouseOverPopup = "${mouseOverPopup}<tr><td>NavStatus: &nbsp;</td><td><nobr>${nav_stati[vessel['nav_status']]}</nobr></td></tr>";
    if(vessel['sog']!= null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>Speed: &nbsp;</td><td><nobr>${vessel['sog'].toString()}</nobr></td></tr>";
    if(vessel['true_heading'] != null && vessel['true_heading'] != 511)
      mouseOverPopup = "${mouseOverPopup}<tr><td>Heading: &nbsp;</td><td><nobr>${vessel['true_heading'].toString()}</nobr></td></tr>";
    if(vessel['cog'] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>Course: &nbsp;</td><td><nobr>${vessel['cog'].toString()}</nobr></td></tr>";
      mouseOverPopup = "${mouseOverPopup}<tr><td>TimeReceived: &nbsp;</td><td><nobr>"
      "${new Date.fromMillisecondsSinceEpoch(vessel['time_received'],isUtc: true).toString()}</nobr></td></tr>";
    if(vessel['dest'] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>Dest</td><td>${vessel['dest']}</b></nobr></td></tr>";
    if(vessel['draught'] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>draught</td><td>${(vessel['draught']/10).toString()}</b></nobr></td></tr>";
    if(vessel['dim_bow'] != null && vessel['dim_port'] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>length, width</td><td>${(vessel['dim_stern']+vessel['dim_bow']).toString()},"
      "${(vessel['dim_starboard']+vessel['dim_port']).toString()}</b></nobr></td></tr>";
    if (shipTypes[vessel['ship_type']] != null)
      mouseOverPopup = "${mouseOverPopup}<tr><td>ship_type</td><td>${shipTypes[vessel['ship_type']]}</b></nobr></td></tr>";
    if(vessel['rot'] != null) mouseOverPopup = "${mouseOverPopup}<tr><td>Rotation</td><td>${vessel['rot'].toString()}</b></nobr></td></tr>";
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


initTypeArrays(){

    shipTypes[6] = 'Passenger Ships';
    shipTypes[7] = 'Cargo Ships';
    shipTypes[8]= 'Tankers';
    shipTypes[30] ='Fishing';
    shipTypes[31] ='Towing';
    shipTypes[32] ='Towing';
    shipTypes[33] ='Dredger';
    shipTypes[34] ='Engaged in diving operations';
    shipTypes[35] ='Engaged in military operations';
    shipTypes[36] = 'Sailing';
    shipTypes[37] = 'Pleasure craft';
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
    shipTypeColors[69] ='#2d00fe'/*blue, Passenger Ships*/;
    shipTypeColors[7] = '#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[70] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[79] ='#95f190'/*lightgreen, Cargo Ships*/;
    shipTypeColors[8] = '#f70016'/*red, Tankers*/;
    shipTypeColors[80] ='#f70016'/*Tanker*/;
    shipTypeColors[89] ='#f70016'/*red,Tankers*/;
    shipTypeColors[9] ='#d2d2d2'/*Other Type*/;
    shipTypeColors[90] ='#d2d2d2'/*Other Type*/;
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

/*TODO      // Listen for safetyMessageEvent
      socket.on('safetyMessageEvent', function (data) {
         var json = JSON.parse(data);
         console.debug(json);
      });


        // Listen for vesselsInBoundsEvent
      socket.on('vesselsInBoundsEvent', function (data) {
 TODO:       $(".leaflet-zoom-animated").children().stop();

          if (map.getZoom() > 12)
          {
            if (vesselWithMapObjects.triangle && typeof vesselWithMapObjects.triangle.start ==='function' && map.getZoom() > 9)
            {
              vesselWithMapObjects.triangle.start();
            }
            if(vesselWithMapObjects.polygon && typeof vesselWithMapObjects.polygon.start ==='function')
            {
              vesselWithMapObjects.polygon.start();
            }
          }
        });
        }
        // zeige eine Infobox über die aktuelle minimal-Geschwindigkeit angezeigter Schiffe
         if (map.getZoom() < 13)
         {
            $('#zoomSpeed').html("vessels reporting > "+(zoomSpeedArray[map.getZoom()])+" knots");
           $('#zoomSpeed').css('display', 'block');
         }
         else 
         {
           $('#zoomSpeed').css('display', 'none');
         }
     });


    function paintToMap(v, callback){
      if(v.pos != null)
      {
        //gemeinsame eventHandler für mouseEvents auf Marker und 
        function onMouseover(e) {
          var popupOptions, latlng;
          if(e.latlng)
          {
            popupOptions = {closeButton:false ,autoPan:false , maxWidth: 180, offset:new L.Point(-100,120)};
            latlng = e.latlng;            
          }
          else
          {
            popupOptions = {closeButton:false ,autoPan:false , maxWidth:180, offset:new L.Point(-60,30)};
            latlng = e.target._latlng;
          }
          L.popup(popupOptions).setLatLng(latlng).setContent(createMouseOverPopup(v)).openOn(map);
        } 

        function onMouseout(e) {map.closePopup();}

        v.ship_type = v.ship_type?v.ship_type:56;

        // für Schiffe zeichne... 
        if(v.msgid < 4 || v.msgid == 5)
        {
          var moving = (v.sog && v.sog > 0.4 && v.sog!=102.3) ; //nur Schiffe, die sich mit mind. 0,3 Knoten bewegen
          var shipStatics = (map.getZoom() > 11) &&  (v.cog ||(v.true_heading && v.true_heading!=0.0 && v.true_heading !=511)) && (v.dim_port && v.dim_stern) ;
   
          v.angle = calcAngle(v);
          var cos_angle=Math.cos(v.angle);
          var sin_angle=Math.sin(v.angle);
          var vectorPoints = [];
          var shipPoint = new L.LatLng(v.pos[1],v.pos[0]);
          vectorPoints.push(shipPoint);
          if (moving) // zeichne für fahrende Schiffe einen Speedvector, ein Richtungsdreieck und möglichst ein Polygon
          {
            vectorPoints.push(shipPoint);
            vectorPoints.push(shipPoint);
            var vectorLength = v.sog >30?v.sog/10:v.sog;
            var targetPoint = calcVector(v.pos[0],v.pos[1], vectorLength, sin_angle, cos_angle);
            vectorPoints.push(targetPoint);
            var vectorWidth = (v.sog > 30?5:2); 
            v.vector = L.polyline(vectorPoints, {color: 'red', weight: vectorWidth });
            v.vector.addTo(featureLayer);
          
            if (shipStatics)
            {
              v.polygon = new L.animatedPolygon(vectorPoints,{
                                                     autoStart:false,
                                                     distance: vectorLength/10,
                                                     interval: 200,
                                                     dim_stern:v.dim_stern,
                                                     dim_port: v.dim_port,
                                                     dim_bow:v.dim_bow,
                                                     dim_starboard: v.dim_starboard,
                                                     angle: v.angle,
                                                     color: "blue",
                                                     weight: 3,
                                                     fill:true,
                                                     fillColor:shipTypeColors[v.ship_type],
                                                     fillOpacity:0.6,
                                                     clickable:false,
                                                     animation:true
              });
              v.polygon.addTo(featureLayer); 
            }

            v.triangle = L.animatedPolygon(vectorPoints,{
                                                    autoStart: false,
                                                    distance: vectorLength/10,
                                                    interval:200,
                                                    angle: v.angle,
                                                    zoom: map.getZoom(),
                                                    color: "black",
                                                    weight: 1,
                                                    fill:true,
                                                    fillColor:shipTypeColors[v.ship_type],
                                                    fillOpacity:0.8,
                                                    clickable:true
            })
            v.triangle.addTo(featureLayer);
            v.triangle.on('mouseover', onMouseover);
            v.triangle.on('mouseout', onMouseout);
          }
          else //zeichne für nicht fahrende Schiffe einen Circlemarker und möglichst ein Polygon
          {
            if(shipStatics)
            {
              v.polygon = L.animatedPolygon( vectorPoints,{
                                                     dim_stern:v.dim_stern,
                                                     dim_port: v.dim_port,
                                                     dim_bow:v.dim_bow,
                                                     dim_starboard: v.dim_starboard,
                                                     angle: v.angle,
                                                     color: "blue",
                                                     weight: 3,
                                                     fill:true,
                                                     fillColor:shipTypeColors[v.ship_type],
                                                     fillOpacity:0.6,
                                                     clickable:false,
                                                     animation:false
              });
              v.polygon.addTo(featureLayer); 
            }
            var circleOptions = {
                        radius:4,
                        fill:true,
                        fillColor:shipTypeColors[v.ship_type],
                        fillOpacity:0.8,
                        color:"#000000",
                        strokeOpacity:1,
                        strokeWidth:0.5
            };
           v.marker = L.circleMarker(vectorPoints[0], circleOptions);
            v.marker.addTo(featureLayer);
            v.marker.on('mouseover',onMouseover);
            v.marker.on('mouseout', onMouseout);
          }
        }
        else //für Seezeichen, Helicopter und AIS Base Stations zeichne Marker mit Icons
        {
           var markerIcon = chooseIcon(v); 
           v.marker = L.marker([v.pos[1], v.pos[0]], {icon:markerIcon});
           v.marker.addTo(featureLayer);
           v.marker.on('mouseover',onMouseover);
           v.marker.on('mouseout', onMouseout);
        }
        callback(v);
      }
    }

  

   

     


*/