var LM = (function(){

	var map, featureLayer, tileLayer, zoom, socket, boundsTimeout, boundsTimeoutTimer;
	
  function init(divName, mapOptions, tileLayerOptions, options){
    map =  L.map(divName, mapOptions);
    map.setView(options.center, options.zoom);
    featureLayer = L.layerGroup().addTo(map);
    if (tileLayerOptions )
    {
      tileLayer =  new L.tileLayer(tileLayerOptions.osmUrl, {attribution: tileLayerOptions.osmAttribution});
      tileLayer.addTo(map);
    }
    if(options.mousePositionControl)
    {
      L.control.mousePosition().addTo(map);
    }
    if (options.onMoveend)
    {
      socket = options.onMoveend;
      map.on('moveend', changeRegistration);
    }
    if (options.boundsTimeout)
    {
      boundsTimeout = options.boundsTimeout *1000;
    }
    changeRegistration();
  }

  function changeRegistration(){
      var message = {};
      message.function = "register"
      message.zoom = map.getZoom();
      message.bounds = map.getBounds();
      socket.timeQuery = new Date().getTime();
      socket.send(JSON.stringify(message));
      if (boundsTimeoutTimer) clearTimeout(boundsTimeoutTimer);
      boundsTimeoutTimer = setTimeout(changeRegistration,boundsTimeout); 
  } 
	   
  function getMap(){
    return map;
  }

  function getZoom(){
    return map.getZoom();
  }

  function addToMap(feature, animation, popupContent){
    if (typeof feature === 'undefined') return;
    if(popupContent.length > 0)
    {
      function onMouseover(e) {
        var popupOptions, latlng;
        popupOptions = {closeButton:false ,autoPan:false , minWidth: 200, maxWidth: 200, offset:new L.Point(120,-20)};
        L.popup(popupOptions).setLatLng(e.latlng).setContent(popupContent).openOn(map);
      }

      function onMouseout(e) {
        LM.getMap().closePopup();
      }      
      
      feature.on('mouseover',onMouseover);
      feature.on('mouseout', onMouseout);
    }
    featureLayer.addLayer(feature);
    if (animation == true)
    {
      feature.start();
    }
  } 
       
  function removeFeatures(vessel){
    if (typeof vessel.vector !="undefined")
    {
       featureLayer.removeLayer(vessel.vector);
    }
    if (typeof vessel.polygon !="undefined")
    {
       if (typeof vessel.polygon.stop ==='function')
       {
           vessel.polygon.stop();
       }
       featureLayer.removeLayer(vessel.polygon);
    }
    if (typeof vessel.feature !="undefined")
    {
      if (typeof vessel.feature.stop ==='function')
      {
         vessel.feature.stop();
      }
      featureLayer.removeLayer(vessel.feature);
    }
  }
  /* return puplic API */
  return {
		init: init,
		getMap: getMap,
    getZoom: getZoom,
    addToMap: addToMap,
    removeFeatures: removeFeatures
  }
})();

	