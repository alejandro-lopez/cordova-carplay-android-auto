
/** @class */
function CarplayAndroidAutoPlugin() {
  return this;
}

CarplayAndroidAutoPlugin.prototype.setMediaItems = function(mediaItems) {
  var options = JSON.stringify(mediaItems);
  cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'setMediaItems', [options]);
}

CarplayAndroidAutoPlugin.prototype.removeMediaItems = function(indexPathPrefix) {
  cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'removeMediaItems', [indexPathPrefix]);
}

CarplayAndroidAutoPlugin.prototype.registerHandler = function(successCallback, errorCallback) {
  var options = {};
  cordova.exec(successCallback, errorCallback, 'CordovaCarplayPlugin', 'registerHandler', [options]);
}

/**
 * @param {string} mediaItemID
 * @param {string} title
 * @param {string} subtitle
 * @param {string} album
 * @param {string} coverImage
 * @param {number} duration
 * @param {number} elapsed
 */
CarplayAndroidAutoPlugin.prototype.updateNowPlayingMetaData = function(mediaItemID, title, subtitle, album, coverImage, duration, elapsed) {
  cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'updateNowPlayingMetaData', [title, subtitle, album, coverImage, duration || 0, elapsed || 0, mediaItemID]);
}

// /** hides 'now playing' screen on carplay, keeping the current metadata, allowing it to be shown again with the same metadata */
// CarplayAndroidAutoPlugin.prototype.hideNowPlayingScreen = function() {
//   cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'hideNowPlayingScreen', []);
// }

// /** shows 'now playing' screen on carplay, restoring the current metadata after it was hidden */
// CarplayAndroidAutoPlugin.prototype.hideNowPlayingScreen = function() {
//   cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'hideNowPlayingScreen', []);
// }

CarplayAndroidAutoPlugin.prototype.finishedPlaying = function() {
  var options = {};
  // a little delay as carplay sometimes show blank now playing otherwise
  window.setTimeout(function(){
    cordova.exec(function(){}, function(){}, 'CordovaCarplayPlugin', 'finishedPlaying', [options]);
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

