          function Vessel(jsonObject){
            this.mmsi = jsonObject.userid? jsonObject.userid:jsonObject.mmsi; //notwendig, weil posEvents userid statt mmsi haben
            this.msgid = jsonObject.msgid;
            this.name = jsonObject.name;
            this.time_received = jsonObject.time_received;
            this.cog = jsonObject.cog;
            this.sog = jsonObject.sog;
            this.lat = jsonObject.pos[1]            
            this.lon = jsonObject.pos[0];
            this.imo = jsonObject.imo;
            this.true_heading = jsonObject.true_heading;
            this.dim_port = jsonObject.dim_port;
            this.dim_stern = jsonObject.dim_stern;
            this.dim_bow = jsonObject.dim_bow;
            this.dim_starboard = jsonObject.dim_starboard;
            this.ship_type = jsonObject.ship_type;
            this.nav_status = jsonObject.nav_status;
            this.dest = jsonObject.dest;
            this.draught = jsonObject.draught;

            
            this.updatePosition = function(jsonObject){
              this.lat = jsonObject.pos[1]            
              this.lon = jsonObject.pos[0];
              this.msgid = jsonObject.msgid;
              this.time_received = jsonObject.time_received;
              this.cog = jsonObject.cog;
              this.sog = jsonObject.sog;
              this.true_heading = jsonObject.true_heading;
            }

            this.paintToMap = function(zoom, callback){
              if(this.lat != null)
              {    
                var moving = (this.sog && this.sog > 0.4 && this.sog!=102.3) ; //nur Schiffe, die sich mit mind. 0,3 Knoten bewegen
                var shipStatics = (this.cog ||(this.true_heading &&  this.true_heading!=0.0 &&  this.true_heading !=511)) && (this.dim_port && this.dim_stern) ;
         
                var angle = calcAngle(this);
                var cos_angle=Math.cos(angle);
                var sin_angle=Math.sin(angle);
                var vectorPoints = [];
                var shipPoint = new L.LatLng(this.lat,this.lon);
                vectorPoints.push(shipPoint);
                if (moving) // zeichne für fahrende Schiffe einen Speedvector, ein Richtungsdreieck und möglichst ein Polygon
                {
                  vectorPoints.push(shipPoint);
                  vectorPoints.push(shipPoint);
                  var vectorLength = this.sog >30? this.sog/10: this.sog;
                  var targetPoint = calcVector(this.lon,this.lat, vectorLength, sin_angle, cos_angle);
                  vectorPoints.push(targetPoint);
                  var vectorWidth = (this.sog > 30?5:2); 
                  this.vector = L.polyline(vectorPoints, {color: 'red', weight: vectorWidth });
                
                  if (shipStatics)
                  {
                    this.polygon = new L.animatedPolygon(vectorPoints,{
                                                           autoStart:false,
                                                           distance: vectorLength/10,
                                                           interval: 200,
                                                           dim_stern: this.dim_stern,
                                                           dim_port: this.dim_port,
                                                           dim_bow: this.dim_bow,
                                                           dim_starboard: this.dim_starboard,
                                                           angle: angle,
                                                           color: "blue",
                                                           weight: 3,
                                                           fill:true,
                                                           fillColor:shipTypeColors[this.ship_type],
                                                           fillOpacity:0.6,
                                                           clickable:false,
                                                           animation:true
                    });
                  }

                  this.feature = L.animatedPolygon(vectorPoints,{
                                                          autoStart: false,
                                                          distance: vectorLength/10,
                                                          interval:200,
                                                          angle: angle,
                                                          zoom: zoom,
                                                          color: "black",
                                                          weight: 1,
                                                          fill:true,
                                                          fillColor:shipTypeColors[this.ship_type],
                                                          fillOpacity:0.8,
                                                          clickable:true,
                                                          animation:true
                  })
                }
                else //zeichne für nicht fahrende Schiffe einen Circlemarker und möglichst ein Polygon
                {
                  if(shipStatics)
                  {
                    this.polygon = L.animatedPolygon( vectorPoints,{
                                                           dim_stern: this.dim_stern,
                                                           dim_port: this.dim_port,
                                                           dim_bow: this.dim_bow,
                                                           dim_starboard: this.dim_starboard,
                                                           angle: angle,
                                                           color: "blue",
                                                           weight: 3,
                                                           fill:true,
                                                           fillColor:shipTypeColors[this.ship_type],
                                                           fillOpacity:0.6,
                                                           clickable:false,
                                                           animation:false
                    });
                  }
                  var circleOptions = {
                              radius:4,
                              fill:true,
                              fillColor:shipTypeColors[this.ship_type],
                              fillOpacity:0.8,
                              color:"#000000",
                              strokeOpacity:1,
                              strokeWidth:0.5
                  };
                   this.feature = L.circleMarker(vectorPoints[0], circleOptions);
                }
              }
          callback([this.vector,this.polygon, this.feature], getPopupContent(this));
        };

        function getPopupContent(vessel){
              var timeNow = new Date();
              var mouseOverPopup ="<div><table>";
              if(vessel.name) mouseOverPopup+="<tr><td colspan='2'><b>"+vessel.name+"</b></nobr></td></tr>";
              if(vessel.imo)mouseOverPopup+="<tr><td>IMO</td><td>"+(vessel.imo)+"</b></nobr></td></tr>  ";
              mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(vessel.mmsi)+"</nobr></td></tr>";
              if(vessel.nav_status && vessel.nav_status < 15 && vessel.nav_status > -1)
              {
                mouseOverPopup+="<tr><td>NavStatus: &nbsp;</td><td><nobr>"+ nav_stati[( vessel.nav_status)]+"</nobr></td></tr>";
              }
              if( vessel.sog)mouseOverPopup+="<tr><td>Speed: &nbsp;</td><td><nobr>"+( vessel.sog)+"</nobr></td></tr>";
              if( vessel.true_heading &&  vessel.true_heading != 511)
              {
                 mouseOverPopup+="<tr><td>Heading: &nbsp;</td><td><nobr>"+(vessel.true_heading)+"</nobr></td></tr>";
              }
              if(vessel.cog)mouseOverPopup+="<tr><td>Course: &nbsp;</td><td><nobr>"+(vessel.cog)+"</nobr></td></tr>";
             
              mouseOverPopup+="<tr><td>TimeReceived: &nbsp;</td><td><nobr>"+createDate(vessel.time_received)+"</nobr></td></tr>";
              if(vessel.dest) mouseOverPopup+="<tr><td>Dest</td><td>"+(vessel.dest)+"</b></nobr></td></tr>";
              if(vessel.draught) mouseOverPopup+="<tr><td>draught</td><td>"+(vessel.draught/10)+"</b></nobr></td></tr>";
              if(vessel.dim_bow && vessel.dim_port)mouseOverPopup+="<tr><td>width, length</td><td>"+(vessel.dim_starboard + vessel.dim_port)+", "+(vessel.dim_stern + vessel.dim_bow )+"</b></nobr></td></tr>";
              if(shipTypes[(vessel.ship_type)]) mouseOverPopup+="<tr><td>ship_type</td><td>"+ shipTypes[(vessel.ship_type)]+"</b></nobr></td></tr>";
              mouseOverPopup+="</table></div>";
              return mouseOverPopup;
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



function calcAngle (vessel) {
       //benötigte Daten
       var hdg = vessel.true_heading;
       var cog = vessel.cog;
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
       else if  ( hdg >0.0 && hdg !=511 && hdg < 360)
       {
         direction = hdg;
       }
       return (-direction *(Math.PI / 180.0));
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

 }