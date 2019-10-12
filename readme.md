# Installation

cordova plugin add https://github.com/mike-nelson/cordova-carplay-android-auto.git

# Goal 

This plugin is intended to provide functionality to Cordova developers to be able to create an "audio" app for Apple CarPlay and Android Auto. These platforms both display audio track lists on the head unit, given track meta data supplied by the application, and support playback as an event sent back to the application.

# 13 Oct 2019 status 

This is work in progress. It is intended to be an "audio" app plugin for Apple CarPlay and Android Auto. So far the implementation is fully working for CarPlay, but limited to one level of tracks (ie does not support a hierarchy). I have not yet looked at Android Auto, which I have got from the original plugin from yoyo770. Note the yoyo770 plugin is for "navigation" rather than "audio" apps, so it is quite different.

# Usage example

Set the media items meta data:

``` javascript
    var tracks = [];
    tracks.push({id:"M1",subtitle:"Test email number 1",title:"Paige Parker"});
    tracks.push({id:"M2",subtitle:"Email number 2",title:"Amy Walker"});
    tracks.push({id:"M4",subtitle:"Email number 4",title:"Poppy Rivera"});
    tracks.push({id:"M5",subtitle:"Email number 5",title:"Elizabeth Lee"});
    tracks.push({id:"M6",subtitle:"Meow",title:"Charlotte Rodriguez"}); 
    window.plugins.carplayAndroidAutoPlugin.setMediaItems(tracks);
```

Set a handler for when a media items is tapped:

``` javascript
window.plugins.carplayAndroidAutoPlugin.registerHandler(function(result){
        if (result  && result.action){
        if (result.action=="handlePlayback"){
            var itemID = result.param;
            // do your own playback
         }
 }
                
  ```



