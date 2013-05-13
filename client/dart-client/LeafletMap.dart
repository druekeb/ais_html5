library LMap;

import "dart:html";
import "dart:async";
import 'dart:json';

import 'packages/js/js.dart' as js;
import 'ais-html5.dart';
import 'MapFeature.dart';

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                                class LeafletMap                           -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class LeafletMap {
  js.Proxy map;
  js.Proxy featureLayerGroup;
  var boundsTimeout;
  var boundsTimeoutTimer;
  
  LeafletMap(String elementid, js.Proxy mapOptions, js.Proxy initOptions, js.Proxy tileLayerOptions){
    boundsTimeout = initOptions['boundsTimeout']*1000;
    js.scoped(() {
        map = new js.Proxy(js.context.L.Map, elementid, mapOptions);
        featureLayerGroup = new js.Proxy(js.context.L.LayerGroup);
        map.addLayer(featureLayerGroup);
        js.retain(featureLayerGroup);
        var osm = new js.Proxy(js.context.L.TileLayer,tileLayerOptions['tileURL'], tileLayerOptions);
        map.addLayer(osm);
        var mouseOptions = initOptions['mousePosition'];
        if( mouseOptions != false)
        {
          var mousePosition = new js.Proxy(js.context.L.Control.MousePosition, mouseOptions);
          mousePosition.addTo(map);
        }
        map.setView(new js.Proxy(js.context.L.LatLng, initOptions['lat'], initOptions['lon']),initOptions['zoom']);
        js.retain(map);
        map.on('moveend', new js.Callback.many(moveendHandler));
      });
     changeRegistration();
  }
  
   moveendHandler(e)
   {
     changeRegistration();
   }
  
  changeRegistration(){
    int zoom = getZoom();
    var boundsArray = getBounds().split(",");
    var _southWest = {"lng":double.parse(boundsArray[0]),"lat":double.parse(boundsArray[1])};
    var _northEast= {"lng":double.parse(boundsArray[2]),"lat":double.parse(boundsArray[3])};
    var bounds = {"_southWest": _southWest,"_northEast":_northEast};

    Map message = new Map();
    message['function'] = 'register';
    message['zoom'] =  zoom;
    message['bounds'] = bounds;
    socket.send(stringify(message));
    
    boundsTimeoutTimer = new Timer(new Duration(milliseconds:boundsTimeout),changeRegistration);  
  }
  
  String getBounds(){
    String bBox;
    js.scoped((){
      bBox = map.getBounds().toBBoxString();
    });
    return bBox;
  }

  int getZoom() {
    int zoom;
    js.scoped((){
      zoom = map.getZoom();
    });
    return zoom;
  }

  void setView(num latitude, num longitude, int zoom) {
    var _pos;
    js.scoped(() {
      _pos = new js.Proxy(js.context.L.LatLng, latitude, longitude);
      map.setView(_pos,12);
    });
  }

  removeFeatures(vessel){
    if (vessel.vector != null)
    {
      vessel.vector.remove();
    }
    if (vessel.polygon != null)
    {
      if (vessel.polygon.animated == true)
      {
        vessel.polygon.stopAnimation();
      }
      vessel.polygon.remove();
    }
    if (vessel.feature != null)
    {
      if (vessel.feature.animated == true)
      {
        vessel.feature.stopAnimation();
      }
      vessel.feature.remove();
    }
  }

  closePopup(){
    js.scoped((){
      map.closePopup();
    });
  }

  openPopup(Popup popup){
    js.scoped((){
      map.openPopup(popup._popup);
    });
  }
}

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                        class Coord                                                 -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class Coord {
  final num latitude;
  final num longitude;
  const Coord(this.latitude, this.longitude);
}

Coord getCoord() {
  js.scoped(() {
    var latlng = mapFeature.getLatLng();
    return new Coord(latlng.latitude, latlng.longitude);
  });
}

void setCoord(Coord coord) {
  js.scoped(() {
    var latlng = new js.Proxy(js.context.L.LatLng, coord.latitude, coord.longitude);
    mapFeature.setLatLng(latlng);
    mapFeature.update();
  });
}
/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                                class Popup                                        -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class Popup{
  js.Proxy _popup;

  Popup( js.Proxy latlng, String content, Map options) {
    js.scoped(() {
      var popupOptions = options;
      var offsetPoint = new js.Proxy(js.context.L.Point, popupOptions['offset'][0],popupOptions['offset'][1]);
      popupOptions['offset'] = offsetPoint;
      popupOptions = js.map(popupOptions);
      _popup= new js.Proxy(js.context.L.Popup, popupOptions);
      _popup.setLatLng(latlng);
      _popup.setContent(content);
      js.retain(_popup);
    });
  }
}

