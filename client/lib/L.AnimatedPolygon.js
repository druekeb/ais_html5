/*
* L.AnimatedPolygon is used for moving shipPolygons between two positionEvents*/

L.AnimatedPolygon = L.Polygon.extend({
  options: {
    distance: 3, // meters (Length of chunks)
    interval: 50, //ms 
    autoStart: false, //animate on add
    onEnd: function(){}, // callback function on onEnd-Event
    clickable: true, //click-Event on Polygon
    animation:true, //make Polygon animatable
    zoom:undefined //to adapt triangle Polygons to zoomlevel
  },

  initialize: function (latlngs, options) {
    // Chunk up the lines into options.distance bits
    this._points = this._chunk(latlngs);
    var initialPolygon;
    if (options.zoom)
    {
      initialPolygon = createTriangle(latlngs[0],options);
    }
    else  initialPolygon = createShipPoints(latlngs[0],options);
    L.Polygon.prototype.initialize.call(this,initialPolygon, options);
  },

  // Breaks the line up into tiny chunks (see options) 
  _chunk: function(latlngs) {
    var i,
        len = latlngs.length,
        chunkedLatLngs = [];

    for (i=1;i<len;i++) {
      var cur = latlngs[i-1],
          next = latlngs[i],
          dist = cur.distanceTo(next),
          factor = this.options.distance / dist,
          dLat = factor * (next.lat - cur.lat),
          dLng = factor * (next.lng - cur.lng);

      if (dist > this.options.distance) {
        while (dist > this.options.distance) {
          cur = new L.LatLng(cur.lat + dLat, cur.lng + dLng);
          dist = cur.distanceTo(next);
          chunkedLatLngs.push(cur);
        }
      } else {
        chunkedLatLngs.push(cur);
      }
    }
    return chunkedLatLngs;
  },

  onAdd: function (map) {
    L.Polygon.prototype.onAdd.call(this, map);
    if (this.options.autoStart) {
      this.start();
    }
  },

  animate: function() {
    if(!this.options.animation) return;
    var self = this,
        len = this._points.length,
        speed = this.options.interval;
    // Normalize the transition speed from vertex to vertex
    if (this._i < len) {
      speed = this._points[this._i-1].distanceTo(this._points[this._i]) / this.options.distance * this.options.interval;
    }
    // Only if CSS3 transitions are supported
    if (L.DomUtil.TRANSITION) {
      if (this._container) { this._container.style[L.DomUtil.TRANSITION] = ('all ' + speed + 'ms linear'); }
      if (this._shadow) { this._shadow.style[L.DomUtil.TRANSITION] = 'all ' + speed + 'ms linear'; }
    }

    // Move to the next vertex
    if (this.options.zoom)
    {
      this.setLatLngs(createTriangle(this._points[this._i-1], this.options));
    }
    else
    {
      this.setLatLngs(createShipPoints(this._points[this._i-1], this.options));
    }
    this._i++;

    // Queue up the animation to the next vertex
    this._tid = setTimeout(function(){
      if (self._i === len) {
        self.options.onEnd.apply(self, Array.prototype.slice.call(arguments));
        self.stop();
      } else {
        self.animate();
      }
    }, speed);
  },

  // Start the animation
  start: function() {
    if (!this._i) {
      this._i = 1;
    }
    this.animate();
  },

  // Stop the animation in place
  stop: function() {
    if (this._tid) {
      clearTimeout(this._tid);
    }
  }
});

const METERS_PER_DEGREE = 111120;

function createTriangle(pos, options){
  //necessary data
  var lon = pos.lng;
  var lat = pos.lat;
  var shippoints = [];
  //calculate the 3 points of the triangle
  var dist = Math.pow (2, options.zoom);
  var frontPoint = destVincenty(lat,lon, options.direction, 1500000 / dist); 
  shippoints.push(frontPoint);
  var leftPoint = destVincenty(lat,lon,(options.direction + 90), 300000 / dist); 
  shippoints.push(leftPoint);
  var rightPoint = destVincenty(lat,lon,(options.direction -90), 300000 / dist); 
  shippoints.push(rightPoint);
  return shippoints;
}

function createShipPoints(pos, options) {
    //necessary data
    var lon = pos.lng;
    var lat = pos.lat;
    var left = options.dim_starboard;
    var front = options.dim_bow;
    var len = (options.dim_bow + options.dim_stern);
    var wid = (options.dim_port +options.dim_starboard);
    //calculate the 5 points of the ships polygon
    var shippoints = [];
    //front left
    var dx = -left;
    var dy = front-(len/10.0);  
    shippoints.push(calcPoint(lon,lat, dx, dy,-options.direction));
    //rear left
    dx = -left;
    dy = -(len-front);
    shippoints.push(calcPoint(lon,lat, dx,dy,-options.direction));
    //rear right
    dx =  wid - left;
    dy = -(len-front);
    shippoints.push(calcPoint(lon,lat, dx,dy,-options.direction));
    //front right
    dx = wid - left;
    dy = front-(len/10.0);
    shippoints.push(calcPoint(lon,lat,dx,dy,-options.direction));  
    //front center
    dx = wid/2.0-left;
    dy = front;
    shippoints.push(calcPoint(lon,lat,dx,dy,-options.direction));
    return shippoints;
   }
 

  function calcPoint(lon, lat, dx, dy, direction){
    var brng = direction * (Math.PI / 180);
    var dy_deg = -(dx*Math.sin(brng) + dy*Math.cos(brng))/METERS_PER_DEGREE;
    var dx_deg = -((dx*Math.cos(brng) - dy*Math.sin(brng))/METERS_PER_DEGREE)/Math.cos(lat * (Math.PI /180.0));
    return new L.LatLng(lat - dy_deg, lon - dx_deg);
  }

