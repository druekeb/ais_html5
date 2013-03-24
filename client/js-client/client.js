$(document).ready(function() {
  var pageRefreshTimer;
   var vessels = {};
    // var navigationals = {};
    
       // Zoom 0, 1, 2, 3, 4, 5, 6, 7, 8, 9,10,11,12,13,14,15,16,17,18
    var zoomSpeedArray = [20,20,20,20,20,20,16,12,8,4,2,1,0.1,-1,-1,-1,-1,-1,-1];
  
    var zoom = getParam('zoom');
      zoom = zoom.length >0? zoom : 16;
      var lon = getParam('lon');
      lon = lon.length > 0? lon : 9.947;
      var lat = getParam('lat');
      lat = lat.length > 0? lat : 53.518;

  
    // if user is running mozilla then use it's built-in WebSocket
    var WebSocket = window.WebSocket || window.MozWebSocket;
    var connection = new WebSocket('ws://127.0.0.1:8090');
    //var connection = new WebSocket('ws://192.168.1.112:8090');
     
    connection.onopen = function () {
        // connection is opened and ready to use
        console.log("ws-connection is open");

        LM.init('map',{
        mapOptions:{
          closePopupOnClick:false,
          markerZoomAnimation: false,
          zoomAnimation: false,
          worldCopyJump: true,
          maxZoom: 18,
          minZoom: 3
        },
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
        var timeMessage = new Date().getTime();
        //console.debug("BoundsEvent " +LM.getZoom()+" "+json.vessels.length+" "+(timeMessage -connection.timeQuery));
         console.debug("boundsEvent "+createDate(timeMessage, true,true) + " " +json.vessels.length);
        processVesselsInBounds(json.vessels, timeMessage);
       }
      else if (json.type == "vesselPosEvent")
      {
        //console.debug("PosEvent "+json.vessel.userid + " "+json.vessel.utc_sec +" "+ new Date().getTime());
        processVesselPosition(json.vessel);
      }
       else if (json.type == "safetyMessageEvent")
      {
        // console.debug("safetyMessageEvent: "+json.text);
      }
    };

      function processVesselsInBounds(jsonArray, timeMessage){
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
            //console.debug("Latency Bounds "+ (new Date().getTime() - vessel.time_captured) + " "+createDate(vessel.time_captured, true));
          }
          // else if (zoom > 6)
          // {
          //   var staticObject = new Navigational(jsonObject);
          //   staticObject.createMapObjects(LM.getZoom(),function(){
          //     LM.paintMarker(staticObject);
          //   });
          // }
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
       //console.debug("painted " +Object.keys(vessels).length+ "  "+(new Date().getTime() -timeMessage));
    }

   
     

      function processVesselPosition(jsonVessel){
        var now = new Date().getTime();
        console.debug(createDate(now,true,true) +" LatencyPosRec "+ (now - jsonVessel.time_received)+" LatencyPosCap "+ (now - jsonVessel.time_captured) + " Rec-Cap "+ (jsonVessel.time_received-jsonVessel.time_captured));
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
         var timePainted = new Date().getTime();
        //console.debug(createDate(timePainted,true,true) +" PaintedPos "+ (timePainted -now));

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
        returnString += ":"+addDigi(seconds);
      }
      if (msec)
      {
        var milliseconds = date.getMilliseconds();
        returnString += ","+addDigiMilli(milliseconds);
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
    function addDigiMilli(curr_millisec){
    curr_millisec = curr_millisec + "";
      switch(curr_millisec.length)
      {
        case 1: curr_millisec = "00" + curr_millisec;
        break;
        case 2: curr_millisec = "0" + curr_millisec;
        break;
      }
      return curr_millisec;
    }
});

