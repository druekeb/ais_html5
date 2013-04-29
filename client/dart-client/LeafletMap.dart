library LMap;

import "dart:html";
import "dart:async";
import 'dart:json';

import 'packages/js/js.dart' as js;
import 'ais-html5.dart';

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                                abstract class LeafletMap                           -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

abstract class LeafletMap {
  String _elementid;
  String _width;
  String _height;
  js.Proxy _map;
  js.Proxy _featureLayerGroup;
  js.Proxy _popup;
  
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

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                     concrete derived class OpenStreetMap                           -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class OpenStreetMap extends LeafletMap {
  List<js.Callback> callbackList = new List<js.Callback>();
  num initialZoom;
  num initialLat;
  num initialLon;
  var boundsTimeout;
  var boundsTimeoutTimer;

  /* Constructor */
  OpenStreetMap(String elementid, List mapOptions, {String width, String height}) : super(elementid, width: width, height: height){ //critical to call super constructor
    initialLat = mapOptions[0].latitude;
    initialLon = mapOptions[0].longitude;
    initialZoom = mapOptions[1];
    boundsTimeout = mapOptions[2]* 1000;
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
    if(!callbackList.isEmpty)
    {
      for(final x in callbackList){
        x.dispose();
        }
     callbackList.clear();
    }
    boundsTimeoutTimer = new Timer(new Duration(milliseconds:boundsTimeout),changeRegistration);  
  }
  
  String getBounds(){
    String bBox;
    js.scoped((){
      bBox = _map.getBounds().toBBoxString();
    });
    return bBox;
  }

  int getZoom() {
    int zoom;
    js.scoped((){
      zoom = _map.getZoom();
    });
    return zoom;
  }

  void setView(num latitude, num longitude, int zoom) {
    var _pos;
    js.scoped(() {
      _pos = new js.Proxy(js.context.L.LatLng, latitude, longitude);
      _map.setView(_pos,12);
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


 /*--------------------------------------------------------------------------------------*/
 /*-                                                                                    -*/
 /*-                       abstract class MapFeatures                                   -*/
 /*-                                                                                    -*/
 /*--------------------------------------------------------------------------------------*/

abstract class MapFeature{

  js.Proxy _mapFeature;
  List callbacks = new List();
  bool animated = false;
  String popupContent = "";
  
  /*----------------------------------------------------*/
  /*-        MouseEventHandlers                        -*/
  /*----------------------------------------------------*/
  clickHandler( e){
    LMap.closePopup();
  }

  mouseoutHandler(e){
    LMap.closePopup();
  }

  mouseoverHandler(ll){
    var popupOptions = {'closeButton': false,
                        'autoPan': false,
                        'maxWidth': 150, 
                        'offset' : [50,-50]};
    var popup = new Popup(ll, popupContent, popupOptions);
    popup.addToMap();
  }
  
  void addListeners()
  {
    onClickHandler(e){
      clickHandler(e);
    }
    onMouseoutHandler(e){
      mouseoutHandler(e);
    }
    onMouseoverHandler(e){
      var ll = e.latlng;
      ll =  new js.Proxy(js.context.L.LatLng ,ll.lat, ll.lng);
      mouseoverHandler(ll);
    }
    
    callbacks.add(new js.Callback.many(onClickHandler));
    callbacks.add(new js.Callback.many(onMouseoverHandler));
    callbacks.add(new js.Callback.many(onMouseoutHandler));
    
    _mapFeature.on('click', callbacks[0]);
    _mapFeature.on('mouseover', callbacks[1]);
    _mapFeature.on('mouseout', callbacks[2]);
  }
  
  /*-------------------------------------------------------*/
 
  void addToMap(bool animation, String pContent) {
    js.scoped(() {
      if(pContent.length > 0)
      {
        popupContent = pContent;
        addListeners();
      }
      LMap._featureLayerGroup.addLayer(_mapFeature);
      //LMap.callbackList.addAll(callbacks);
      if (animation == true)
      {
        animated = true;
        _mapFeature.start();
      }
    });
  }

  void remove() {
    js.scoped(() {
        LMap._featureLayerGroup.removeLayer(_mapFeature);     
    });
  }
}

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                     concrete derived class Polyline                                -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

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

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                     concrete derived class AnimatedPolygon                         -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class AnimatedPolygon extends MapFeature{
  
  AnimatedPolygon(List<Coord> vectorPoints, Map opts, int vmmsi) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var points =js.array([]);
      for(var x = 0;x < vectorPoints.length; x++)
      {
        var lat =  vectorPoints[x].latitude;
        var lng = vectorPoints[x].longitude;
        points.push(new js.Proxy(latlng,lat,lng ));
      }
      _mapFeature= new js.Proxy(js.context.L.AnimatedPolygon, points, js.map(opts));
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

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                     concrete derived class CircleMarker                            -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class CircleMarker extends MapFeature{
  CircleMarker(Coord vectorPoint, Map options, int vMmsi) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var point = new js.Proxy(latlng,vectorPoint.latitude,vectorPoint.longitude );
      var circleOptions = js.map(options);
      _mapFeature= new js.Proxy(js.context.L.CircleMarker, point, circleOptions);
      js.retain(_mapFeature);
    });
  }
}

/*--------------------------------------------------------------------------------------*/
/*-                                                                                    -*/
/*-                                class Popup                                        -*/
/*-                                                                                    -*/
/*--------------------------------------------------------------------------------------*/

class Popup{
  js.Proxy _popup;

  Popup( js.Proxy ll, String content, Map options) {
    js.scoped(() {
      var popupOptions = options;
      var offsetPoint = new js.Proxy(js.context.L.Point, popupOptions['offset'][0],options['offset'][1]);
      //var origin = new js.Proxy(latlng, e.getLatLng() );
      popupOptions['offset'] = offsetPoint;
      popupOptions = js.map(popupOptions);
      _popup= new js.Proxy(js.context.L.Popup, popupOptions);
      _popup.setLatLng(ll);
      _popup.setContent(content);
      js.retain(_popup);
    });
  }

  void addToMap() {
    LMap.closePopup();
    LMap.openPopup(_popup);
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

/*--------------------------------------------------------------------------------------*/