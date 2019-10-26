
/** @class */
function CarplayAndroidAutoPlugin() {}

CarplayAndroidAutoPlugin.prototype.setMediaItems = function(mediaItems) {
  var options = JSON.stringify(mediaItems);
  cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'setMediaItems', [options]);
}

CarplayAndroidAutoPlugin.prototype.registerHandler = function(successCallback, errorCallback) {
  var options = {};
  cordova.exec(successCallback, errorCallback, 'CordovaCarplayPlugin', 'registerHandler', [options]);
}

CarplayAndroidAutoPlugin.prototype.finishedPlaying = function(successCallback, errorCallback) {
  var options = {};
  // a little delay as carplay sometimes show blank now playing otherwise
  window.setTimeout(function(){
    cordova.exec(successCallback, errorCallback, 'CordovaCarplayPlugin', 'finishedPlaying', [options]);
  }, 100);
}


// Installation constructor that binds the plugin to window
CarplayAndroidAutoPlugin.install = function() {
  if (!window.plugins) {
    window.plugins = {};
  }
  window.plugins.carplayAndroidAutoPlugin = new CarplayAndroidAutoPlugin();
  return window.plugins.carplayAndroidAutoPlugin;
};
cordova.addConstructor(CarplayAndroidAutoPlugin.install);

