$(document).ready(function() {
    var timeQuery;
    
     var vessels = {};
     
      // Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
      var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];

      var map = L.map('map').setView([53.545,9.96], 16);

      L.tileLayer('http://{s}.tiles.vesseltracker.com/vesseltracker/{z}/{x}/{y}.png', {
            attribution:  'Map-Data <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-By-SA</a> by <a href="http://openstreetmap.org/">OpenStreetMap</a> contributors',
            maxZoom: 18,
            minZoom:3
          }).addTo(map);
      var featureLayer = L.layerGroup().addTo(map);
      
      map.on('moveend', changeRegistration);
      
      L.control.mousePosition().addTo(map);


    // if user is running mozilla then use it's built-in WebSocket
    var WebSocket = window.WebSocket || window.MozWebSocket;

    var connection = new WebSocket('ws://127.0.0.1:8090');

    connection.onopen = function () {
        // connection is opened and ready to use
        console.log("ws-connection is open");
        changeRegistration();
    };

    connection.onerror = function (error) {
        // an error occurred when sending/receiving data
          console.log("an error occurred when sending/receiving data");
    };

    connection.onmessage = function (message) {
       // try to decode json (I assume that each message from server is json)
        try
        {
          var json = JSON.parse(message.data);
        } catch (e) {
            console.log('This doesn\'t look like a valid JSON: ', message.data);
            return;
        }
      if (json.type == "vesselsInBoundsEvent")
      {
            console.debug(map.getZoom()+"|"+json.vessels.length+"|"+(new Date().getTime() -timeQuery));
            processVesselsInBounds(json.vessels);
       }
      if (json.type == "vesselPosEvent")
      {
        processVesselPosition(json.vessel);
      }
       if (json.type == "safetyMessageEvent")
      {
        console.debug("safetyMessageEvent: "+json.text);
      }
    };

      function changeRegistration()
      {
        var zoom = map.getZoom();
        if(zoom < 3)
        { 
          map.zoomTo(3);
          return;
        }
        console.debug("zoomLevel="+map.getZoom());
        var bounds = map.getBounds();
        var message = {};
        message.function = "register"
        message.zoom = map.getZoom();
        message.bounds = map.getBounds();
        timeQuery = new Date().getTime();
        connection.send(JSON.stringify(message));
      } 

      function processVesselsInBounds(jsonArray){

        $(".leaflet-zoom-animated").children().stop();
        
        featureLayer.clearLayers();
        vessels = {};

       // male vessel-Marker, Polygone und speedVectoren in die karte
       for (var x in jsonArray)
        { 
          var timeFlex  = new Date().getTime();
          paintToMap(jsonArray[x], function(vesselWithMapObjects){
          vessels[jsonArray[x].mmsi] = vesselWithMapObjects;
         // console.debug("painted ready after "+(new Date().getTime() -timeFlex));
          if (map.getZoom() > 12)
          {
            if (vesselWithMapObjects.feature && typeof vesselWithMapObjects.feature.start ==='function' && map.getZoom() > 9)
            {
              vesselWithMapObjects.feature.start();
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
      }

      function processVesselPosition(jsonVessel){
        // console.debug("zeit seit absenden der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_captured));
        // console.debug("zeit seit Empfang der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_received));
        // console.debug("utc_sec: "+jsonVessel.utc_sec+" : "+new Date().getSeconds()+ " => "+(new Date().getSeconds() -jsonVessel.utc_sec));

          var vessel = vessels[jsonVessel.userid]?vessels[jsonVessel.userid]:{};
          vessel.mmsi = jsonVessel.userid;
          vessel.msgid = jsonVessel.msgid;
          vessel.time_received = jsonVessel.time_received;
          vessel.cog = jsonVessel.cog/10;
          vessel.sog = jsonVessel.sog/10;
          vessel.pos = jsonVessel.pos;
          vessel.true_heading = jsonVessel.true_heading;
        
          if (typeof vessel.vector !="undefined")
          { 
             featureLayer.removeLayer(vessel.vector);
            delete vessel.vector;
          }
          if (typeof vessel.polygon !="undefined")
          {
            if (typeof vessel.polygon.stop ==='function')
            {
                 vessel.polygon.stop();
            }
              featureLayer.removeLayer(vessel.polygon);
              delete vessel.polygon;
          }
          if (typeof vessel.feature !="undefined")
          {
            if (typeof vessel.feature.stop ==='function')
             {
                vessel.feature.stop();
            }
            featureLayer.removeLayer(vessel.feature);
            delete vessel.feature;
          }
          var timeFlex  = new Date().getTime();
          paintToMap(vessel, function(vesselWithMapObjects){
          vessels[jsonVessel.userid] = vesselWithMapObjects;
           // console.debug("painted ready after "+(new Date().getTime() -timeFlex));
          if (map.getZoom() > 12)
          {
            if (vesselWithMapObjects.feature && typeof vesselWithMapObjects.feature.start ==='function')
            {
              vesselWithMapObjects.feature.start();
            }
            if(vesselWithMapObjects.polygon && typeof vesselWithMapObjects.polygon.start ==='function')
            {
              vesselWithMapObjects.polygon.start();
            }
          }
        });
      }

    function paintToMap(v, callback){
      if(v.pos != null)
      {    
        //gemeinsame eventHandler für mouseEvents auf dreieckige Polygone und CircleMarker 
        function onMouseout(e) {map.closePopup();}
        function onMouseover(e) {
          var popupOptions, latlng;
          if(e.latlng)
          {
            popupOptions = {closeButton:false ,autoPan:false , maxWidth: 150, offset:new L.Point(-100,120)};
            latlng = e.latlng;            
          }
          else
          {
            popupOptions = {closeButton:false ,autoPan:false , maxWidth:150, offset:new L.Point(-60,30)};
            latlng = e.target._latlng;
          }
          L.popup(popupOptions).setLatLng(latlng).setContent(createMouseOverPopup(v)).openOn(map);
        }

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

            v.feature = L.animatedPolygon(vectorPoints,{
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
                                                    clickable:true,
                                                    animation:true
            })
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
             v.feature = L.circleMarker(vectorPoints[0], circleOptions);
          }
          v.feature.addTo(featureLayer);
          v.feature.on('mouseover',onMouseover);
          v.feature.on('mouseout', onMouseout);
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

    function createShipPoints(vessel) {
      //benötigte Daten
      var left = vessel.dim_starboard;
      var front = vessel.dim_bow;
      var len = (vessel.dim_bow + vessel.dim_stern);
      var lon = vessel.pos[0];
      var lat = vessel.pos[1];
      var wid = (vessel.dim_port +vessel.dim_starboard);
      var cos_angle=Math.cos(vessel.angle);
      var sin_angle=Math.sin(vessel.angle);
      //ermittle aud den Daten die 5 Punkte des Polygons
      var shippoints = [];
      //front left
      var dx = -left;
      var dy = front-(len/10.0);  
      shippoints.push(calcPoint(lon,lat, dx, dy,sin_angle,cos_angle));
      //rear left
      dx = -left;
      dy = -(len-front);
      shippoints.push(calcPoint(lon,lat, dx,dy,sin_angle,cos_angle));
      //rear right
      dx =  wid - left;
      dy = -(len-front);
      shippoints.push(calcPoint(lon,lat, dx,dy,sin_angle,cos_angle));
      //front right
      dx = wid - left;
      dy = front-(len/10.0);
      shippoints.push(calcPoint(lon,lat,dx,dy,sin_angle,cos_angle));  
      //front center
      dx = wid/2.0-left;
      dy = front;
      shippoints.push(calcPoint(lon,lat,dx,dy,sin_angle,cos_angle));
      return shippoints;
     }

   function calcAngle(vessel) {
       //benötigte Daten
       var hdg = vessel.true_heading;
       var cog = vessel.cog;
       var lon = vessel.pos[0];
       var lat = vessel.pos[1];
       var sog = vessel.sog;
       var direction = 0;
       if (vessel.mmsi == 211855000)
       {
        direction = 299;
       }
       if (sog && sog > 0.4 && cog < 360)
       {
          direction = cog;
       }
       else if  ( hdg >0.0 && hdg !=511 &&hdg < 360)
       {
         direction = hdg;
       }
       return (-direction *(Math.PI / 180.0));
   }

  function calcVector(lon, lat, sog, sin, cos){
    var dy_deg = -(sog * cos)/10000;
    var dx_deg = -(- sog * sin)/Math.cos((lat)*(Math.PI/180.0))/10000;
    return new L.LatLng(lat - dy_deg, lon - dx_deg);
    }

    function calcPoint(lon, lat, dx, dy, sin_angle, cos_angle){
    var dy_deg = -((dx*sin_angle + dy*cos_angle)/(1852.0))/60.0;
    var dx_deg = -(((dx*cos_angle - dy*sin_angle)/(1852.0))/60.0)/Math.cos(lat * (Math.PI /180.0));
    return new L.LatLng(lat - dy_deg, lon - dx_deg);
    }

function createMouseOverPopup(vessel){
      var timeNow = new Date();
      mouseOverPopup ="<div><table>";
      if(vessel.msgid == 21)
      {
        if(vessel.name)mouseOverPopup+="<tr><td colspan='2'><b>"+vessel.name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(vessel.mmsi)+"</nobr></td></tr>";
        if(vessel.aton_type)mouseOverPopup+="<tr><td colspan='2'><b>"+aton_types[vessel.aton_type]+"</b></nobr></td></tr>";
      }
      else if(vessel.msgid == 4)
      {
        mouseOverPopup += "<tr><td colspan='2'><b>AIS Base Station</b></nobr></td></tr>";
        if(vessel.name)mouseOverPopup+="<tr><td colspan='2'><b>"+vessel.name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(vessel.mmsi)+"</nobr></td></tr>";
      }
      else if(vessel.msgid == 9)
      {
        mouseOverPopup += "<tr><td colspan='2'><b>Helicopter SAR</b></nobr></td></tr>";
        if(vessel.name)mouseOverPopup+="<tr><td colspan='2'><b>"+vessel.name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(vessel.mmsi)+"</nobr></td></tr>";
         if(vessel.altitude)mouseOverPopup+="<tr><td>Altitude: &nbsp;</td><td><nobr>"+(vessel.altitude)+"</nobr></td></tr>";
      }
      else
      {
        if(vessel.name)mouseOverPopup+="<tr><td colspan='2'><b>"+vessel.name+"</b></nobr></td></tr>";
        if(vessel.imo)mouseOverPopup+="<tr><td>IMO</td><td>"+(vessel.imo)+"</b></nobr></td></tr>  ";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(vessel.mmsi)+"</nobr></td></tr>";
        if(vessel.nav_status && vessel.nav_status < 15 && vessel.nav_status > -1)
        {
          mouseOverPopup+="<tr><td>NavStatus: &nbsp;</td><td><nobr>"+ nav_stati[(vessel.nav_status)]+"</nobr></td></tr>";
        }
        if(vessel.sog)mouseOverPopup+="<tr><td>Speed: &nbsp;</td><td><nobr>"+(vessel.sog)+"</nobr></td></tr>";
        if(vessel.true_heading && vessel.true_heading != 511)
        {
           mouseOverPopup+="<tr><td>Heading: &nbsp;</td><td><nobr>"+(vessel.true_heading)+"</nobr></td></tr>";
        }
        if(vessel.cog)mouseOverPopup+="<tr><td>Course: &nbsp;</td><td><nobr>"+(vessel.cog)+"</nobr></td></tr>";
       
        mouseOverPopup+="<tr><td>TimeReceived: &nbsp;</td><td><nobr>"+createDate(vessel.time_received)+"</nobr></td></tr>";
        if(vessel.dest)mouseOverPopup+="<tr><td>Dest</td><td>"+(vessel.dest)+"</b></nobr></td></tr>";
        if(vessel.draught)mouseOverPopup+="<tr><td>draught</td><td>"+(vessel.draught/10)+"</b></nobr></td></tr>";
        if(vessel.dim_bow && vessel.dim_port)mouseOverPopup+="<tr><td>width, length</td><td>"+(vessel.dim_starboard +vessel.dim_port)+", "+(vessel.dim_stern + vessel.dim_bow )+"</b></nobr></td></tr>";
        if(shipTypes[(vessel.ship_type)]) mouseOverPopup+="<tr><td>ship_type</td><td>"+ shipTypes[(vessel.ship_type)]+"</b></nobr></td></tr>";
        if(vessel.rot) mouseOverPopup +="<tr><td>Rotation</td><td>"+(vessel.rot)+"</b></nobr></td></tr>";
      }
      mouseOverPopup+="</table></div>";
      return mouseOverPopup;
    }

    function createDate(ts, sec, msec){
      var returnString;
      var date= new Date();
          date.setTime(ts);

      var month = date.getMonth()+1;
      var day = date.getDate();
      returnString = day +"."+month+" ";

      var hour = date.getHours();
      var min= date.getMinutes();
      returnString += addDigi(hour)+":"+addDigi(min);
      if (sec)
      {
        var seconds = date.getSeconds();
        returnString += " "+addDigi(seconds);
      }
      if (msec)
      {
        var milliseconds = date.getMilliseconds();
        returnString += " "+addDigi(milliseconds);
      }
      return returnString;
    }

    function addDigi(curr_min){
    curr_min = curr_min + "";
      if (curr_min.length == 1)
      {
        curr_min = "0" + curr_min;
    }
      return curr_min;
    }

     function chooseIcon(obj){
       var iconUrl;
       var zoom = map.getZoom();
       var size;
       var popupAnchor;
       var iconAnchor;

        if(obj.msgid == 21)
        {
         iconUrl =  "../images/atons/aton_"+obj.aton_type+".png";
         size = [zoom,zoom];
         return new L.Icon({iconUrl: iconUrl, iconSize: size});
       }
       else if(obj.msgid == 4)
       {
         iconUrl =   "../images/baseStation.png";
         size = [zoom-1,zoom-1];
         return new L.Icon({iconUrl: iconUrl, iconSize: size});
       }
       else if (obj.msgid ==9)
       {
          iconUrl =   "../images/helicopter.png";
          size = [3*zoom,3*zoom];
          return new L.Icon({iconUrl: iconUrl, iconSize: size});
       }
       else
       {
          iconUrl =  "http://images.vesseltracker.com/images/googlemaps/icon_lastpos.png";
          size = [6+2*Math.log(zoom),6+2*Math.log(zoom)];
          return new L.Icon({iconUrl: iconUrl, iconSize: size});
        }
      }
});

var shipTypes = {
                  6:'Passenger Ships',
                  7: 'Cargo Ships',
                  8: 'Tankers',
                  30:'Fishing',
                  31:'Towing',
                  32:'Towing',
                  33:'Dredger',
                  34:'Engaged in diving operations',
                  35:'Engaged in military operations',
                  36: 'Sailing',
                  37: 'Pleasure craft',
                  50:'Pilot vessel',
                  51:'Search and rescue vessels',
                  52:'Tugs',53:'Port tenders',
                  54:'anti-pollution vessels',
                  55:'Law enforcement vessels',
                  56:'Spare for local vessels',
                  57:'Spare for local vessels',
                  58:'Medical transports',
                  59:'Ships according to RR'
                };

var shipTypeColors = {
                  20:'#f9f9f9',
                  29:'#f9f9f9',
                  30:'#f99d7b'/*brown, Fishing*/,
                  31:'#4dfffe'/*lightblue, Towing*/,
                  32:'#4dfffe'/*lightblue, Towing*/,
                  33:'#f9f9f9'/*gray, Dredger*/,
                  34:'white'/*Engaged in diving operations*/,
                  35:'white'/*Engaged in military operations*/,
                  36:'#f900fe'/*violett, Sailing*/,
                  37:'#f900fe'/*violett, Pleasure craft*/,
                  40:'#f9f9f9'/*Highspeed*/,
                  49:'#f9f9f9'/*Highspeed*/,  
                  50:'red'/*Pilot vessel*/,
                  51:'white' /*Search and rescue vessels*/,
                  52:'#4dfffe'/*lightblue, Tugs*/,
                  53:'#4dfffe'/*lightblue, Port tenders*/,
                  54:'white'/*anti-pollution vessels*/,
                  55:'white'/*Law enforcement vessels*/,
                  56:'#d2d2d2'/*not classified => used as default by vesseltracker*/,
                  57:'white'/*Spare for local vessels*/,
                  58:'white'/*Medical transports*/,
                  59:'white'/*Ships according to RR*/,
                  6:'#2d00fe'/*blue, Passenger Ships*/,
                  60:'#2d00fe'/*blue, Passenger Ships*/,
                  69:'#2d00fe'/*blue, Passenger Ships*/,
                  7: '#95f190'/*lightgreen, Cargo Ships*/,
                  70:'#95f190'/*lightgreen, Cargo Ships*/,
                  79:'#95f190'/*lightgreen, Cargo Ships*/,
                  8: '#f70016'/*red, Tankers*/,
                  80:'#f70016'/*Tanker*/,
                  89:'#f70016'/*red,Tankers*/,
                  9:'#d2d2d2'/*Other Type*/,
                  90:'#d2d2d2'/*Other Type*/,
                  99:'#d2d2d2'/*Other Type*/
}
var nav_stati = {
                  0:'under way us. engine',
                  1:'at anchor',
                  2: 'not under command',
                  3: 'restr. maneuverability',
                  4: 'constr. by draught',
                  5: 'moored',
                  6: 'aground',
                  7: 'engaged in fishing',
                  8: 'under way sailing',
                  9: 'future use',
                  10: 'future use',
                  11: 'future use',
                  12: 'future use',
                  13: 'future use',
                  14: 'AIS-SART (active)',
                  15: 'not defined' 
                }

var aton_types = {
                  0:'notSpecified',
                  1:'ReferencePoint',
                  2: 'RACON',
                  3: 'off-shoreStructure',
                  4: 'futureUse',
                  5: 'LightWithoutSectors',
                  6: 'LightWithSectors',
                  7: 'LeadingLightFront',
                  8: 'LeadingLightRear',
                  9: 'BeaconCardinalN',
                  10: 'BeaconCardinalE',
                  11: 'BeaconCardinalS',
                  12: 'BeaconCardinalW',
                  13: 'BeaconPorthand', 
                  14: 'BeaconStarboardhand',
                  15: 'BeaconPreferredChannelPortHand',
                  16: 'BeaconPreferredChannelStarboardHand',
                  17: 'BeaconIsolatedDanger',
                  18: 'BeacoSafeWater',
                  19: 'BeaconSpecialMark',
                  20: 'CardinalMarkN',
                  21: 'CardinalMarkE',
                  22: 'CardinalMarkS',
                  23: 'CardinalMarkW',
                  24: 'PortHandMark',
                  25: 'StarboardHandMark',
                  26: 'PreferredChannelPortHand',
                  27: 'PreferredChannelStarboardHand',
                  28: 'IsolatedDanger',
                  29: 'SafeWater',
                  30: 'SpecialMark',
                  31: 'LightVessel/LANBY/Rigs'
                }
