library leaflet_maps;

import "dart:html";
import "dart:async";
import 'packages/js/js.dart' as js;
import 'aisDart.dart' as caller;
import 'dart:json';

abstract class LeafletMap {
  String _elementid;
  String _width;
  String _height;
  js.Proxy _map;
  js.Proxy _featureLayerGroup;
  js.Proxy _popup;
  int  _zoom;
  

  LeafletMap(String elementid, {String width, String height}) {
    _elementid = elementid;
    if(width != null) {
      _width = width;
    }
    if(height != null) {
      _height = height;
    } else {
      _height = "300px";
    }
  }

  void setView(num latitude, num longitude, int zoom);

  int getZoom();

  String getBounds();

  void loadMap();

  void openPopup(js.Proxy popup);

  void closePopup();
}

class OpenStreetMap extends LeafletMap {
  List<js.Callback> callbackList = new List<js.Callback>();
  int initialZoom;
  num initialLat;
  num initialLon;
  var boundsTimeout;

  OpenStreetMap(String elementid, List mapOptions, {String width, String height}) : super(elementid, width: width, height: height){ //critical to call super constructor
    initialZoom = mapOptions[1];
    initialLat = mapOptions[0].latitude;
    initialLon = mapOptions[0].longitude;
  }
  void loadMap() {
    var tileURL = 'http://{s}.tiles.vesseltracker.com/vesseltracker/{z}/{x}/{y}.png';
    var osmAttrib = 'Map-Data <a href="http://creativecommons.org/licenses/by-sa/2.0/">CC-By-SA</a> by <a href="http://openstreetmap.org/">OpenStreetMap</a> contributors target="_blank">MapQuest</a>, <a href="http://www.openstreetmap.org/" target="_blank">OpenStreetMap</a> and contributors, <a href="http://creativecommons.org/licenses/by-sa/2.0/" target="_blank">CC-BY-SA</a>';
    var subDomains = ['otile1','otile2','otile3','otile4'];
    js.scoped(() {
        var mapOptions = js.map({
          'closePopupOnClick':false,
          'markerZoomAnimation': false,
          'zoomAnimation': false,
          'worldCopyJump': true,
          'maxZoom': 18,
          'minZoom': 3});
        var tileLayerOptions = js.map({
          'attribution': osmAttrib, 
          'subdomains': subDomains
          });
        _map = new js.Proxy(js.context.L.Map, _elementid,mapOptions);
        _featureLayerGroup = new js.Proxy(js.context.L.LayerGroup);
        _map.addLayer(_featureLayerGroup);
        js.retain(_featureLayerGroup);
        var osm = new js.Proxy(js.context.L.TileLayer,tileURL, tileLayerOptions);
        _map.addLayer(osm);
        var mouseOptions = js.map({'numDigits': 5  });
        var mousePosition = new js.Proxy(js.context.L.Control.MousePosition, mouseOptions);
        mousePosition.addTo(_map);
        _map.setView(new js.Proxy(js.context.L.LatLng, initialLat, initialLon),initialZoom);
        js.retain(_map);
        _map.on('moveend', new js.Callback.many(moveendHandler));
      });
    changeRegistration();
  }
  
  moveendHandler(e)
  {
    changeRegistration();
  }
  
  changeRegistration()
  {
    int zoom = getZoom();
    if(zoom < 3)
    {
      zoom = 3;
      setZoom(zoom);
      return;
    }
    var boundsArray = getBounds().split(",");
    var _southWest = {"lng":double.parse(boundsArray[0]),"lat":double.parse(boundsArray[1])};
    var _northEast= {"lng":double.parse(boundsArray[2]),"lat":double.parse(boundsArray[3])};
    var bounds = {"_southWest": _southWest,"_northEast":_northEast};

    Map message = new Map();
    message['function'] = 'register';
    message['zoom'] =  zoom;
    message['bounds'] = bounds;
    caller.timeFlex = new DateTime.now().millisecondsSinceEpoch;
    caller.socket.send(stringify(message));
    if(!callbackList.isEmpty)
    {
      for(final x in callbackList){
        x.dispose();
        }
     callbackList.clear();
    }
//    boundsTimeout = new Timer(new Duration(milliseconds:120000),changeRegistration);  
   //boundsTimeout = new Timer(new Duration(milliseconds:30000), zoomOut);  
 }
  
  String getBounds(){
    String bBox;
    js.scoped((){
      bBox = _map.getBounds().toBBoxString();
    });
    return bBox;
  }

  zoomOut(){
    setZoom(getZoom() -1);
  }

  int getZoom() {
    int zoom;
    js.scoped((){
      zoom = _map.getZoom();
    });
    return zoom;
  }
  
  setZoom(zoom){
    js.scoped((){
      _map.setZoom(zoom);
    });
  }

  void setView(num latitude, num longitude, int zoom) {
    var _pos;
    js.scoped(() {
      _pos = new js.Proxy(js.context.L.LatLng, latitude, longitude);
      _map.setView(_pos,12);
    });
  }

  clearFeatureLayer()
  {
    js.scoped((){
      _featureLayerGroup.clearLayers();
    });
  }

  closePopup(){
    js.scoped((){
    _map.closePopup();
    });
  }

  openPopup(js.Proxy popup){
    js.scoped((){
    _map.openPopup(popup);
    _popup = popup;
    });
  }
}

class Popup{
  js.Proxy _popup;

  Popup(Coord popupOrigin, String content, Map options) {
    js.scoped(() {
      var popupOptions = options;
      var offsetPoint = new js.Proxy(js.context.L.Point, popupOptions['offset'][0],options['offset'][1]);
      var latlng = js.context.L.LatLng;
      var origin = new js.Proxy(latlng, popupOrigin.latitude, popupOrigin.longitude );
      popupOptions['offset'] = offsetPoint;
      popupOptions = js.map(popupOptions);
      _popup= new js.Proxy(js.context.L.Popup, popupOptions);
      _popup.setLatLng(origin);
      _popup.setContent(content);
      js.retain(_popup);
    });
  }

  void addTo(LeafletMap map) {
    map.closePopup();
    map.openPopup(_popup);
  }
}

abstract class MapFeature{

  js.Proxy _mapFeature;
  List callbacks = new List();


  void addListeners(mmsi)
  {
    onClickHandler(e)=> caller.onClickHandler(e, mmsi);
    onMouseoutHandler(e)=>caller.onMouseoutHandler(e);
    onMouseoverHandler(e) =>caller.onMouseoverHandler(e, mmsi);
    
    callbacks.add(new js.Callback.many(onClickHandler));
    callbacks.add(new js.Callback.many(onMouseoverHandler));
    callbacks.add(new js.Callback.many(onMouseoutHandler));
    
    _mapFeature.on('click', callbacks[0]);
    _mapFeature.on('mouseover', callbacks[1]);
    _mapFeature.on('mouseout', callbacks[2]);
  }

  void addTo(OpenStreetMap map, bool featureLayer) {
    js.scoped(() {
      if(featureLayer)
      {
        map._featureLayerGroup.addLayer(_mapFeature);
      }
      else
      {
        _mapFeature.addTo(map._map);
      }
      map.callbackList.addAll(callbacks);
    });
  }

  void remove(LeafletMap map, bool featureLayer) {
    js.scoped(() {
     
      if(featureLayer)
      {
        map._featureLayerGroup.removeLayer(_mapFeature);
      }
      else
      {
        map._map.remove(_mapFeature);
      }
    });
  }
}

class Polyline extends MapFeature{

  Polyline(List<Coord> vectorPoints, Map options) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var points =js.array([]);
      for(var x = 0;x < vectorPoints.length; x++)
      {
        var lat =  vectorPoints[x].latitude;
        var lng = vectorPoints[x].longitude;
        points.push(new js.Proxy(latlng,lat,lng ));
      }
      var lineOptions = js.map(options);
      _mapFeature= new js.Proxy(js.context.L.Polyline, points, lineOptions);
      js.retain(_mapFeature);
    });
  }
}

class AnimatedPolygon extends MapFeature{

  AnimatedPolygon(List<Coord> vectorPoints, Map options, int vmmsi) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var points =js.array([]);
      for(var x = 0;x < vectorPoints.length; x++)
      {
        var lat =  vectorPoints[x].latitude;
        var lng = vectorPoints[x].longitude;
        points.push(new js.Proxy(latlng,lat,lng ));
      }
      var triangleOptions = js.map(options);
      _mapFeature= new js.Proxy(js.context.L.animatedPolygon, points, triangleOptions);
      addListeners(vmmsi);
      js.retain(_mapFeature);
    });
  }

  startAnimation(){
    js.scoped(() {
      _mapFeature.start();
    });
  }

  stopAnimation(){
    js.scoped(() {
      _mapFeature.stop();
    });
  }
}

class CircleMarker extends MapFeature{
  CircleMarker(Coord vectorPoint, Map options, int vMmsi) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var point = new js.Proxy(latlng,vectorPoint.latitude,vectorPoint.longitude );
      var circleOptions = js.map(options);
      _mapFeature= new js.Proxy(js.context.L.CircleMarker, point, circleOptions);
      addListeners(vMmsi);
      js.retain(_mapFeature);
    });
  }
  clearLayers(){
    js.scoped((){
     // _animatedPolygon.clearLayers();
    });
  }
}
class Marker extends MapFeature{

  Marker(num latitude, num longitude, [String tooltip, bool draggable]) {

    js.scoped(() {
      var pos = new js.Proxy(js.context.L.LatLng, latitude, longitude);
      Map options = new Map();
      if(tooltip != null) {
        options['title'] = tooltip;
      }
      if(draggable != null) {
        options['draggable'] = draggable;
      }
      _mapFeature = new js.Proxy (js.context.L.Marker, pos, js.map(options));
      js.retain(_mapFeature);
    });
  }

  void addTo(LeafletMap map, bool featureLayer) {
    js.scoped(() {
      if(featureLayer )
      {
        map._featureLayerGroup.addLayer(_mapFeature);
      }
      else
      {
        _mapFeature.addTo(map);
      }
    });
  }

  Coord getCoord() {
    js.scoped(() {
      var latlng = _mapFeature.getLatLng();

      return new Coord(latlng.latitude, latlng.longitude);
    });
  }

  void setCoord(Coord coord) {
    js.scoped(() {
      var latlng = new js.Proxy(js.context.L.LatLng, coord.latitude, coord.longitude);

      _mapFeature.setLatLng(latlng);
      _mapFeature.update();
    });
  }

  void setIcon(Icon icon) {
    js.scoped(() {
      var size = new js.Proxy(js.context.L.Point, icon.dimension.width, icon.dimension.height);
      var js_icon = new js.Proxy(js.context.L.Icon, js.map({'iconUrl':icon.imageURL, 'iconSize': size}));

      _mapFeature.setIcon(js_icon);
    });
  }

  void setZIndexOffset(num offset) {
    js.scoped(() {
      _mapFeature.setZIndexOffset(offset);
    });
  }

  void setOpacity(num opacity) {
    js.scoped(() {
      _mapFeature.setOpacity(opacity);
    });
  }

  void bindPopup(Popup popup) {
  }
}

class Coord {
  final num latitude;
  final num longitude;

  const Coord(this.latitude, this.longitude);
}

class Icon {
  final String imageURL;
  final Dimension dimension;

  const Icon(this.imageURL, this.dimension);
}

class Dimension {
  final num width;
  final num height;

  const Dimension(this.width, this.height);
}