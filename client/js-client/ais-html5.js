$(document).ready(function() {
    
  /* Array that defines for every zoomlevel the minimun speed of a displayed vessel:
                Zoomlevel 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18 */
  var ZOOM_SPEED_ARRAY = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];
  var WEBSOCKET_SERVER_LOCATION = '192.168.1.214';
  var WEBSOCKET_SERVER_PORT = 8090;
  var BOUNDS_TIMEOUT = 300;
  var vessels = {};
      
  var initialZoom = getParam('zoom');
  initialZoom = initialZoom.length >0? initialZoom : 17;
  var initialLon = getParam('lon');
  initialLon = initialLon.length > 0? initialLon : 9.947;
  var initialLat = getParam('lat');
  initialLat = initialLat.length > 0? initialLat : 53.518;

  var WebSocket = window.WebSocket;
  var connection = new WebSocket('ws://'+WEBSOCKET_SERVER_LOCATION+":"+WEBSOCKET_SERVER_PORT);
    
  connection.onopen = function () {
        /* connection is opened and ready to use */
        console.log("ws-connection is open");
          var initOptions = {
            lat:initialLat,
            lon:initialLon,
            zoom:initialZoom,
            boundsTimeout:BOUNDS_TIMEOUT,
            mousePosition: {numDigits: 5  },
            onMoveend:this
          };
          var mapOptions = {
            closePopupOnClick:true,
            markerZoomAnimation: false,
            zoomAnimation: false,
            worldCopyJump: true,
            maxZoom: 18,
            minZoom: 3
          };
          var tileLayerOptions = {
            tileURL: 'http://{s}.tiles.vesseltracker.com/vesseltracker/{z}/{x}/{y}.png',
            attribution: 'Map-Data <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-By-SA</a> by <a href="http://openstreetmap.org/">OpenStreetMap</a> contributors target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>',
            subdomains: ['t1','t2','t3']
          } 
         LMap.init('map',initOptions, mapOptions, tileLayerOptions);
  };

  connection.onerror = function (error) {
        // an error occurred when sending/receiving data
          console.log("an error occurred when sending/receiving data: ");
  };

  connection.onmessage = function (message) {
    try /* try to decode JSON - message */
    {
      var json = JSON.parse(message.data);
    } catch (e) {
      console.log('This doesn\'t look like a valid JSON: ', message.data);
      return;
    }
    if (json.type == "vesselsInBoundsEvent")
    {
      processVesselsInBounds(json.vessels);
    }
    else if (json.type == "vesselPosEvent")
    {
      processVesselPosition(json.vessel);
    }
  };

  function processVesselsInBounds(jsonArray){
    var currentZoom = LMap.getZoom();
    for (var v in vessels)
    {
      LMap.removeFeatures(vessels[v]);
    }
    vessels = {};
    /* create new Vessel with Objects (Polygons, Circles) and paint to Map */
    for (var x in jsonArray)
    {
      var jsonObject = jsonArray[x];
      var vessel = new Vessel(jsonArray[x]);
      vessel.paintToMap(currentZoom, function(){
          vessels[vessel.mmsi] = vessel;
      });
    }
    /* show Infobox with the current minimum speed a vessel must have to be displayed */
    if (currentZoom < getFirstNegative(ZOOM_SPEED_ARRAY))
    {
      $('#zoomSpeed').html("vessels reporting > "+(ZOOM_SPEED_ARRAY[LMap.getZoom()])+" knots");
      $('#zoomSpeed').css('display', 'block');
    }
    else 
    {
      $('#zoomSpeed').css('display', 'none');
    }
  }

  function processVesselPosition(jsonVessel){
    var vessel = vessels[jsonVessel.userid];
    if(vessel != undefined)
    {
      LMap.removeFeatures(vessel);
      vessel.updatePosition(jsonVessel);
    }
    else
    {
      vessel = new Vessel(jsonVessel);
    }
    vessel.paintToMap(LMap.getZoom(), function(){
        vessels[vessel.mmsi] = vessel;
      });
  }

/* Help functions -------------------------------------------------------------------------------------*/   

  function getParam(name){ 
        name = name.replace(/[\[]/,"\\\[").replace(/[\]]/,"\\\]");
        var regexS = "[\\?&]"+name+"=([^&#]*)";
        var regex = new RegExp( regexS );
        var results = regex.exec (window.location.href);

        if (results == null)return "";
        else return results[1];  
  }

  function getFirstNegative(sZA){
      for (var x = 0; x < sZA.length;x++)
      { 
        if (sZA[x] < 0)
        return x;
      }
  }
});

