$(document).ready(function() {
    var timeQuery;
    
     var vessels = {};
     var navigationals = {};
     
      // Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
      var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];

      var map = L.map('map').setView([53.541,9.913], 16);

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
           console.debug("BoundsEvent " +map.getZoom()+" "+json.vessels.length+" "+(new Date().getTime() -timeQuery));
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

      function changeRegistration()
      {
        var zoom = map.getZoom();
        if(zoom < 3)
        { 
          map.zoomTo(3);
          return;
        }
        // console.debug("zoomLevel="+map.getZoom());
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
          var vessel = new Vessel(jsonArray[x]);
          
          vessel.paintToMap(map.getZoom(), function(features, popupContent){
            for(x in features)
            {
              var feature = features[x];
              if (feature != undefined)
              {
                 //gemeinsame eventHandler für mouseEvents auf dreieckige Polygone und CircleMarker 
                 function onMouseout(e) {map.closePopup();}
                 function onMouseover(e) {
                        var latlng = e.latlng;
                        var offsetPoint = new L.Point(100,120);
                        var popupOptions = {closeButton:false ,autoPan:false , maxWidth: 150, offset:offsetPoint};
                        L.popup(popupOptions).setLatLng(latlng).setContent(popupContent).openOn(map);
                 }
                feature.on('mouseover',onMouseover);
                feature.on('mouseout', onMouseout);
                featureLayer.addLayer(feature);
                if(map.getZoom() > 12 && typeof feature.start ==='function')
                {
                 feature.start();
                }
              }
            }
            vessels[vessel.mmsi] = vessel;
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

      function processNavigationalAids(jsonArray){

        navigationals = {};

       // male vessel-Marker, Polygone und speedVectoren in die karte
       for (var x in jsonArray)
        { 
          var timeFlex  = new Date().getTime();
          var navigational = new Navigational(jsonArray[x]);

          //gemeinsame eventHandler für mouseEvents 
          function onMouseout(e) {map.closePopup();}
          function onMouseover(e) {
            var latlng = e.target.latlng;
           var offsetPoint = new L.Point(-60,30);
            var popupContent = createMouseOverPopup();
            var popupOptions = {closeButton:false ,autoPan:false , maxWidth: 150, offset:offsetPoint};
            L.popup(popupOptions).setLatLng(latlng).setContent(popupContent).openOn(map);
          }
          navigational.paintToMap(function(marker){
            marker.addTo(featureLayer);
            marker.on('mouseover',onMouseover);
            marker.on('mouseout', onMouseout);
            navigationals[navigational.mmsi] = navigational;
        });
      }
    }
     

      function processVesselPosition(jsonVessel){
        // console.debug("zeit seit absenden der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_captured));
        // console.debug("zeit seit Empfang der positionsmeldung: "+(new Date().getTime() - jsonVessel.time_received));
        // console.debug("utc_sec: "+jsonVessel.utc_sec+" : "+new Date().getSeconds()+ " => "+(new Date().getSeconds() -jsonVessel.utc_sec));
        var vessel = vessels[jsonVessel.userid];
        if(vessel != undefined)
        {
          removeVesselFromMap(vessel);
          vessel.updatePosition(jsonVessel);
        }
        else
        {
          vessel = new Vessel(jsonVessel);
        }
        var timeFlex  = new Date().getTime();
        vessel.paintToMap(map.getZoom(), function(features, popupContent){

            for(x in features)
            {
              var feature = features[x];
              if (feature != undefined)
              {
                 //gemeinsame eventHandler für mouseEvents auf dreieckige Polygone und CircleMarker 
                 function onMouseout(e) {map.closePopup();}
                 function onMouseover(e) {
                        var latlng = e.latlng;
                        var offsetPoint = new L.Point(100,120);
                        var popupOptions = {closeButton:false ,autoPan:false , maxWidth: 150, offset:offsetPoint};
                        L.popup(popupOptions).setLatLng(latlng).setContent(popupContent).openOn(map);
                 }
                feature.on('mouseover',onMouseover);
                feature.on('mouseout', onMouseout);
                featureLayer.addLayer(feature);
                if(map.getZoom() > 12 && typeof feature.start ==='function')
                {
                 feature.start();
                }
              }
            }
            vessels[vessel.mmsi] = vessel;
        });
    }

    function removeVesselFromMap(vessel)
    {
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
    }
});

