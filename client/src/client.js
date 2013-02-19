$(document).ready(function() {
   var vessels = {};
    var navigationals = {};
    
       // Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
    var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];
  
    var zoom = getParam('zoom');
    zoom = zoom.length >0? zoom : 14;
    var lon = getParam('lon');
    lon = lon.length > 0? lon : 9.86;
    var lat = getParam('lat');
    lat = lat.length > 0? lat : 53.54;

    // if user is running mozilla then use it's built-in WebSocket
    var WebSocket = window.WebSocket || window.MozWebSocket;
   // var connection = new WebSocket('ws://127.0.0.1:8090');
    var connection = new WebSocket('ws://192.168.1.112:8090');
     
    connection.onopen = function () {
        // connection is opened and ready to use
        console.log("ws-connection is open");

        LM.init('map',{
        mapOptions:{closePopupOnClick:false},
        tileLayer: true,
        featureLayer: true,
        mousePositionControl: true,
        onClick: true,
        onMoveend: this,
        zoom: zoom,
        center: [lat, lon]
       });
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
           console.debug("BoundsEvent " +LM.getZoom()+" "+json.vessels.length+" "+(new Date().getTime() -connection.timeQuery));
           processVesselsInBounds(json.vessels);
       }
      else if (json.type == "vesselPosEvent")
      {
        // console.debug("PosEvent "+json.vessel.userid + " "+json.vessel.utc_sec +" "+ new Date().getTime());
        processVesselPosition(json.vessel);
      }
       else if (json.type == "safetyMessageEvent")
      {
        // console.debug("safetyMessageEvent: "+json.text);
      }
    };

      function processVesselsInBounds(jsonArray){
        for (var v in vessels)
        {
          LM.clearFeature(vessels[v]);
        }
        vessels = {};

       // male vessel-Marker, Polygone und speedVectoren in die karte
       
       for (var x in jsonArray)
        {
          var jsonObject = jsonArray[x];
          // var timeFlex  = new Date().getTime();
          if (jsonObject.msgid < 4 || jsonObject.msgid == 5)
          {
            var vessel = new Vessel(jsonArray[x]);
            vessel.createMapObjects(LM.getZoom(), function(){
              LM.paintVessel(vessel);
            });
            vessels[vessel.mmsi] = vessel;
          }
          else if (zoom > 6)
          {
            var staticObject = new Navigational(jsonObject);
            staticObject.createMapObjects(LM.getZoom(),function(){
              LM.paintMarker(staticObject);
            });
          }
        }
      // zeige eine Infobox über die aktuelle minimal-Geschwindigkeit angezeigter Schiffe
       if (LM.getZoom() < 13)
       {
          $('#zoomSpeed').html("vessels reporting > "+(zoomSpeedArray[LM.getZoom()])+" knots");
         $('#zoomSpeed').css('display', 'block');
       }
       else 
       {
         $('#zoomSpeed').css('display', 'none');
       }
    }

    //   function processNavigationalAids(jsonArray){

    //     navigationals = {};

    //    // male vessel-Marker, Polygone und speedVectoren in die karte
    //    for (var x in jsonArray)
    //     { 
    //       var timeFlex  = new Date().getTime();
    //       var navigational = new Navigational(jsonArray[x]);

    //       //gemeinsame eventHandler für mouseEvents 
    //       function onMouseout(e) {map.closePopup();}
    //       function onMouseover(e) {
    //         var latlng = e.target.latlng;
    //        var offsetPoint = new L.Point(-60,30);
    //         var popupContent = createMouseOverPopup();
    //         var popupOptions = {closeButton:false ,autoPan:false , maxWidth: 150, offset:offsetPoint};
    //         L.popup(popupOptions).setLatLng(latlng).setContent(popupContent).openOn(map);
    //       }
    //       navigational.paintToMap(function(marker){
    //         marker.addTo(featureLayer);
    //         marker.on('mouseover',onMouseover);
    //         marker.on('mouseout', onMouseout);
    //         navigationals[navigational.mmsi] = navigational;
    //     });
    //   }
    // }
     

      function processVesselPosition(jsonVessel){
        // console.debug("zeit seit absenden der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_captured));
        // console.debug("zeit seit Empfang der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_received));
        // console.debug("utc_sec: "+jsonVessel.utc_sec+" : "+new Date().getSeconds()+ " => "+(new Date().getSeconds() -jsonVessel.utc_sec));
        var vessel = vessels[jsonVessel.userid];
        if(vessel != undefined)
        {
          LM.clearFeature(vessel);
          vessel.updatePosition(jsonVessel);
        }
        else
        {
          vessel = new Vessel(jsonVessel);
        }
        var timeFlex  = new Date().getTime();
        vessel.createMapObjects(LM.getZoom(), function(){
            LM.paintVessel(vessel);
            vessels[vessel.mmsi] = vessel;
        });
    }

    function getParam(name){ 

        if (name == 'auth')
        {
           var authString =  [getHash(137454), 137454]; // Zeile entfernen, sobald die Authentifizierung in der jeweiligen Anwendung (Vesseltracker, Wateropt, ..) erfolgt
          console.debug("authstring "+authString);
          return authString;
        }  
        name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
        var regexS = "[\\?&]"+name+"=([^&#]*)";
        var regex = new RegExp( regexS );
        var results = regex.exec (window.location.href);

        if (results == null)return "";
        else return results[1];  
      }
});

