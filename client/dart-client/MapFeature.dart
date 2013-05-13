library LFeature;

import "dart:html";
import "dart:async";
import 'dart:json';

import 'packages/js/js.dart' as js;
import 'ais-html5.dart';
import 'LeafletMap.dart';

/*--------------------------------------------------------------------------------------*/
 /*-                                                                                    -*/
 /*-                       abstract class MapFeatures                                   -*/
 /*-                                                                                    -*/
 /*--------------------------------------------------------------------------------------*/

abstract class MapFeature{

  js.Proxy _mapFeature;
  List _callbacks = new List();
  bool animated = false;
  String popupContent = "";
  
  /*----------------------------------------------------*/
  /*-        MouseEventHandlers                        -*/
  /*----------------------------------------------------*/
  
  void addListeners(){
    onMouseoutHandler(e){
      LMap.closePopup();
    }
    onMouseoverHandler(e){
      var ll = e.latlng;
      ll =  new js.Proxy(js.context.L.LatLng ,ll.lat, ll.lng);
      var popupOptions = {'closeButton': false,
                        'autoPan': false,
                        'maxWidth': 150, 
                        'offset' : [50,-50]};
      var popup = new Popup(ll, popupContent, popupOptions);
      LMap.closePopup();
      LMap.openPopup(popup);
    }
    
    _callbacks.add(new js.Callback.many(onMouseoverHandler));
    _callbacks.add(new js.Callback.many(onMouseoutHandler));
    
    _mapFeature.on('mouseover', _callbacks[0]);
    _mapFeature.on('mouseout', _callbacks[1]);
  }
  
  /*-------------------------------------------------------*/
 
  void addToMap(bool animation, String popupText) {
    js.scoped(() {
      if(popupText.length > 0)
      {
        popupContent = popupText;
        addListeners();
      }
      LMap.featureLayerGroup.addLayer(_mapFeature);
      if (animation == true)
      {
        animated = true;
        _mapFeature.start();
      }
    });
  }

  void remove() {
    js.scoped(() {
      LMap.featureLayerGroup.removeLayer(_mapFeature);     
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
  
  AnimatedPolygon(List<Coord> vectorPoints, Map options) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var points =js.array([]);
      for(var x = 0;x < vectorPoints.length; x++)
      {
        var lat =  vectorPoints[x].latitude;
        var lng = vectorPoints[x].longitude;
        points.push(new js.Proxy(latlng,lat,lng ));
      }
      _mapFeature= new js.Proxy(js.context.L.AnimatedPolygon, points, js.map(options));
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
  CircleMarker(Coord vectorPoint, Map options) {
    js.scoped(() {
      var latlng = js.context.L.LatLng;
      var point = new js.Proxy(latlng,vectorPoint.latitude,vectorPoint.longitude );
      var circleOptions = js.map(options);
      _mapFeature= new js.Proxy(js.context.L.CircleMarker, point, circleOptions);
      js.retain(_mapFeature);
    });
  }
}