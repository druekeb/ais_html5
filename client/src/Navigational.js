 function Navigational(jsonObject){
            var mmsi = jsonObject.mmsi;
            var name = jsonObject.name;
            var aton_type = jsonObject.aton_type;
            var altitude = jsonObject.altitude;
            var msgid = jsonObject.msgid;
            var time_received = jsonObject.time_received;
            
            this.getPopupContent = function(){
              return createMouseOverPopup();
            }

      this.paintToMap = function(zoom, callback){
      	if(pos != null)
        {    
        	var markerIcon = chooseIcon(this); 
          var marker = L.marker([pos[1], pos[0]], {icon:markerIcon});
        }
        callback(marker);
      }

      function createMouseOverPopup(){
      var timeNow = new Date();
      mouseOverPopup ="<div class='mouseOverPopup'><table>";
      if(msgid == 21)
      {
        if(name)mouseOverPopup+="<tr><td colspan='2'><b>"+name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(mmsi)+"</nobr></td></tr>";
        if(aton_type)mouseOverPopup+="<tr><td colspan='2'><b>"+aton_types[aton_type]+"</b></nobr></td></tr>";
      }
      else if(msgid == 4)
      {
        mouseOverPopup += "<tr><td colspan='2'><b>AIS Base Station</b></nobr></td></tr>";
        if(name)mouseOverPopup+="<tr><td colspan='2'><b>"+name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(mmsi)+"</nobr></td></tr>";
      }
      else if(msgid == 9)
      {
        mouseOverPopup += "<tr><td colspan='2'><b>Helicopter SAR</b></nobr></td></tr>";
        if(name)mouseOverPopup+="<tr><td colspan='2'><b>"+name+"</b></nobr></td></tr>";
        mouseOverPopup+="<tr><td>MMSI: &nbsp;</td><td><nobr>"+(mmsi)+"</nobr></td></tr>";
         if(altitude)mouseOverPopup+="<tr><td>Altitude: &nbsp;</td><td><nobr>"+(altitude)+"</nobr></td></tr>";
      }
      mouseOverPopup+="</table></div>";
      return mouseOverPopup;
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
  }