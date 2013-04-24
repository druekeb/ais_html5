library Vessel;
import 'LeafletMap.dart' as LM;
import 'ais-html5.dart';
import 'dart:math';

class Vessel{
  var pos;
  num mmsi, msgid, ship_type, nav_status;
  String name, imo, dest;
  num cog, sog, true_heading, dim_port, dim_stern, dim_bow, dim_starboard, draught, brng;
  int time_received, time_captured;
  LM.Polyline vector;
  LM.AnimatedPolygon polygon, triangle;
  LM.CircleMarker marker;
  const MINIMUM_SPEED = 0.4;
  
  Vessel(jsonObject){
    mmsi = (jsonObject['userid'] !=null) ? jsonObject['userid']:jsonObject['mmsi']; //notwendig, weil posEvents userid statt mmsi haben
    msgid = jsonObject['msgid'];
    name = jsonObject['name'];
    time_received = jsonObject['time_received'];
    cog = jsonObject['cog'];
    sog = jsonObject['sog'];
    pos = jsonObject['pos'];
//    lat = jsonObject['pos[1]'];            
//    lon = jsonObject['pos[0]'];
    imo = jsonObject['imo'];
    true_heading = jsonObject['true_heading'];
    dim_port = jsonObject['dim_port'];
    dim_stern = jsonObject['dim_stern'];
    dim_bow = jsonObject['dim_bow'];
    dim_starboard = jsonObject['dim_starboard'];
    ship_type = jsonObject['ship_type'];
    nav_status = jsonObject['nav_status'];
    dest = jsonObject['dest'];
    draught = jsonObject['draught'];
    time_captured = jsonObject['time_captured'];
  }
  updatePosition(json){
    msgid =  json['msgid'];
    time_received = json['time_received'];
    cog = json['cog']/10;
    sog = json['sog']/10;
    pos = json['pos'];
    true_heading = json['true_heading'];
  }
  
  paintToMap(zoom, callback){

    if(pos != null)
    {
      // for vessels paint...
      if (msgid < 4 ||msgid == 5)
      {
        var moving = (sog !=null && sog >= MINIMUM_SPEED && sog!=102.3) ; 
        var shipStatics = (leaflet_map.getZoom() > 11) &&  (cog !=null ||(true_heading!=null && true_heading!=0.0 && true_heading !=511)) && (dim_port !=null && dim_stern!=null) ;

        brng = calcAngle();
        var cos_angle = cos(brng);
        var sin_angle = sin(brng);
        List<LM.Coord> vectorPoints = new List();
        LM.Coord shipPoint = new LM.Coord(pos[1],pos[0]);
        vectorPoints.add(shipPoint);

        if (moving) //only vessel, that move with a minimum speed of MINIMUM_SPEED
        {
          var meterProSekunde = sog *0.51444;
          var vectorLength = meterProSekunde * 30; //meter, die in 30 sec zurückgelegt werden
          var targetPoint = destinationPoint(pos[1], pos[0], cog, vectorLength);
          //var targetPoint = calcVector(pos[0],pos[1], vectorLength, sin_angle, cos_angle);//destinationPoint(this.lat, this.lon, this.cog, vectorLength);
          vectorPoints.add(targetPoint);
          var vectorWidth = (sog > 30?5:2); 
          vector = new LM.Polyline(vectorPoints, {'color': 'red', 'weight': vectorWidth });
          vector.addTo(leaflet_map, true);
          var animationPartsSize = vectorLength/(zoom*20); //in wieviele Teilstücke wird der vector zerlegt
          var animationInterval = 500; //wie lang ist die Zeitspanne zwischen zwei Animationsschritten
          if (shipStatics)
          {
            polygon = new LM.AnimatedPolygon(vectorPoints,{
              'autoStart':false,
              'animation':true,
              'distance': animationPartsSize,
              'interval': animationInterval,
              'dim_stern':dim_stern,
              'dim_port': dim_port,
              'dim_bow':dim_bow,
              'dim_starboard': dim_starboard,
              'brng':brng,
              'color': "blue",
              'weight': 3,
              'fill':true,
              'fillColor':shipTypeColors[ship_type],
              'fillOpacity':0.6,
              'clickable':false
            }, mmsi);
            polygon.addTo(leaflet_map, true);
          }

          triangle = new LM.AnimatedPolygon(vectorPoints,{
            'autoStart': false,
            'animation':true,
            'distance': animationPartsSize,
            'interval':animationInterval,
            'brng':brng,
            'zoom': leaflet_map.getZoom(),
            'color': "black",
            'weight': 1,
            'fill':true,
            'fillColor': shipTypeColors[ship_type],
            'fillOpacity':0.8,
            'clickable':true
             }, mmsi);
        triangle.addTo(leaflet_map, true);
        }/* paint for non moving vessels a Polygon and a circlemarker*/
        else 
        {
          if(shipStatics)
          {
            polygon = new LM.AnimatedPolygon(vectorPoints,{
                'autoStart':false,
                'animation':false,
                'dim_stern':dim_stern,
                'dim_port': dim_port,
                'dim_bow':dim_bow,
                'dim_starboard': dim_starboard,
                'brng':brng,
                'color': "blue",
                'weight': 3,
                'fill':true,
                'fillColor':shipTypeColors[ship_type],
                'fillOpacity':0.6,
                'clickable':false
              }, mmsi);
            polygon.addTo(leaflet_map, true);
          }
          Map circleOptions = {
                           'radius':5,
                           'fill':true,
                           'fillColor':shipTypeColors[ship_type],
                           'fillOpacity':0.8,
                           'color':"#000000",
                           'opacity':0.4,
                           'weight':2.5
                           };
          marker = new LM.CircleMarker(vectorPoints[0], circleOptions, mmsi);
          marker.addTo(leaflet_map, true);
        }
      }
    }
  callback();
}
  String createMouseOverPopup(){
    String mouseOverPopup ="<div class='mouseOverPopup'><table>";
    if(name != null) {
        mouseOverPopup = "${mouseOverPopup}<tr><td colspan='2'><b>${name}</b></nobr></td></tr>";
      }
      if(imo != null && imo !="0") {
        mouseOverPopup = "${mouseOverPopup}<tr><td>IMO</td><td>${imo}</b></nobr></td></tr>";
      }
      mouseOverPopup = "${mouseOverPopup}<tr><td>MMSI: &nbsp;</td><td><nobr>${mmsi.toString()}</nobr></td></tr>";
    if(nav_status!=null && nav_status < 15 && nav_status > -1) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>NavStatus: &nbsp;</td><td><nobr>${nav_stati[nav_status]}</nobr></td></tr>";
    }
    if(sog!= null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Speed: &nbsp;</td><td><nobr>${sog.toString()}</nobr></td></tr>";
    }
    if(true_heading != null && true_heading != 511) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Heading: &nbsp;</td><td><nobr>${true_heading.toString()}</nobr></td></tr>";
    }
    if(cog != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Course: &nbsp;</td><td><nobr>${cog.toString()}</nobr></td></tr>";
    }
    var time = new DateTime.fromMillisecondsSinceEpoch(time_received,isUtc: false);
    var timeString = time.toString().substring(0, 16);
    mouseOverPopup = "${mouseOverPopup}<tr><td>TimeReceived: &nbsp;</td><td><nobr>${timeString}</nobr></td></tr>";
    if(dest != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>Dest</td><td>${dest}</b></nobr></td></tr>";
    }
    if(draught != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>draught</td><td>${(draught/10).toString()}</b></nobr></td></tr>";
    }
    if(dim_bow != null && dim_port != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>length, width</td><td>${(dim_stern+dim_bow).toString()},"
      "${(dim_starboard+dim_port).toString()}</b></nobr></td></tr>";
    }
    if (shipTypes[ship_type] != null) {
      mouseOverPopup = "${mouseOverPopup}<tr><td>ship_type</td><td>${shipTypes[ship_type]}</b></nobr></td></tr>";
    }
    mouseOverPopup = "${mouseOverPopup}</table></div>";
    return mouseOverPopup;
  }
  
  num calcAngle() {
    var direction = 0;
    if (mmsi == 211855000) //Cap San Diego
    {
      direction = 299;
    }
    if (sog!=null && sog > 0.4 && cog < 360)
    {
      direction = cog;
    }
    else if (true_heading!=null && true_heading > 0.0 && true_heading !=511 && true_heading < 360)
    {
      direction = true_heading;
    }
    return (-direction *(PI / 180.0));
  }

//  LM.Coord calcVector(lon, lat, sog, sinus, cosinus){
//    var dy_deg = -(sog * cosinus)/10000;
//    var dx_deg = -(- sog * sinus)/cos((lat)*(PI/180.0))/10000;
//    return new LM.Coord(lat - dy_deg, lon - dx_deg);
//  }

  LM.Coord destinationPoint(lat, lng, cog, dist) {
    dist = dist / 6371000;  
    var brng = cog * (PI / 180);  
    var lat1 = lat * (PI / 180);
    var lon1 = lng * (PI / 180);
    var lat2 = asin(sin(lat1) * cos(dist) + cos(lat1) * sin(dist) * cos(brng));
    var lon2 = lon1 + atan2(sin(brng) * sin(dist) * cos(lat1), cos(dist) - sin(lat1) * sin(lat2));
    if (lat2.isNaN || lon2.isNaN) return null;
    lat2 = lat2 *(180/PI);
    lon2 = lon2 *(180/PI);
    return new LM.Coord(lat2, lon2);
  }
}


Map<int, String> shipTypes = new Map<int, String>();
Map<int,String> shipTypeColors = new Map<int,String>();
Map<int,String> nav_stati = new Map<int,String>();

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
}