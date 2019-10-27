# Installation

```
cordova plugin add https://github.com/mike-nelson/cordova-carplay-android-auto.git
```

# Goal 

This plugin is intended to provide functionality to Cordova developers to be able to create an "audio" app for Apple CarPlay and Android Auto. These platforms both display audio track lists on the head unit, given track meta data supplied by the application, and support playback as an event sent back to the application.

This plugin was created for Speaking Email (https://www.speaking.email) by Mike Nelson of BEWEB LIMITED (https://www.beweb.co.nz)

# 27 Oct 2019 status 

This is work in progress. It is intended to be an "audio" app plugin for Apple CarPlay and Android Auto. So far the implementation is fully working for CarPlay. I have not yet looked at Android Auto, which I have got from the original plugin from yoyo770. Note the yoyo770 plugin is for "navigation" rather than "audio" apps, so it is quite different.

# Usage example

Set the media items meta data:

``` javascript
    var tracks = [];
    tracks.push({itemKey:"0", id:"M1",subtitle:"Test email number 1",title:"Paige Parker"});
    tracks.push({itemKey:"1", id:"M2",subtitle:"Email number 2",title:"Amy Walker"});
    tracks.push({itemKey:"2", id:"M4",subtitle:"Email number 4",title:"Poppy Rivera"});
    tracks.push({itemKey:"3", id:"M5",subtitle:"Email number 5",title:"Elizabeth Lee"});
    tracks.push({itemKey:"4", id:"container",subtitle:"This is a container",title:"Emails from cats",true}); 
    tracks.push({itemKey:"4:0", id:"M6",subtitle:"Meow",title:"Charlotte Rodriguez"}); 
    tracks.push({itemKey:"4:1", id:"M7",subtitle:"Meow 2",title:"Charlotte Rodriguez"}); 
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
 }
                
  ```

Here is a sample class to help with creating media items. You can create any number of media items at any level and assign them these properties. 

The ID is important, it is what is passed back in the callback when the user taps play on that item. There is no callback when the user taps a container.

According to the apple docs isPlayable and isContainer are independent but in reality it seems items can't be both. An item could be created with both false, if it is a status message for example.



``` javascript

/** 
 * @class 
 * @param {string} id 
 * @param {string} title 
 * @param {string} subtitle
 * @param {boolean} [isContainer]
 * @param {string} [iconImage]
 * */
function CarplayItem(indexKey,id,title,subtitle,isContainer,iconImage){
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.isContainer = isContainer;
    this.isPlayable = !isContainer;
    this.itemKey = indexKey;
    this.artworkUrl = iconImage;
    return this;
}

var topTabs = [];
topTabs.push(new CarplayItem("0","Menu","Menu","",true,"https://speaking.email/images/icons/home.png"));
topTabs.push(new CarplayItem("1","Inbox","Inbox","",true,"https://speaking.email/images/icons/inbox.png"));
topTabs.push(new CarplayItem("2","Action","Action","",true,"https://speaking.email/images/icons/hand-finger-pointing-down.png"));
window.plugins.carplayAndroidAutoPlugin.setMediaItems(topTabs);

  ```

To clear those you don't want anymore use either of these methods. 

``` javascript

// remove a single item (can be added as a batch along with any setting of items)
window.plugins.carplayAndroidAutoPlugin.setMediaItems([{isRemove:true, itemKey:"3:1:0"}]);

// remove all items starting with the given prefix
window.plugins.carplayAndroidAutoPlugin.removeMediaItems("0:1");

  ```

The plugin updates the 'now playing' info when the 'play' request comes through from CarPlay. It also updates the media item which is playing (shows an icon next to it). 

If you want to play another media item that is not via CarPlay (eg if moving onto the next one automatically) - then you should call `updateNowPlayingMetaData` to change the currently playing item to the correct one. You can also use this method to change the metadata - eg call frequently to update the elapsed time on the currently playing item, or set the image. 

If you are setting the metadata to a non-media-item (eg displaying a message) then you can set mediaItemID to an empty string. This will not change the currently playing media item icon. 

``` javascript

window.plugins.carplayAndroidAutoPlugin.updateNowPlayingMetaData(mediaItemID, title, subtitle, album, coverImage, duration, elapsed);

  ```

