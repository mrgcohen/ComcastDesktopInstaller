ComcastDesktopInstaller
=======================

## Comcast Desktop Installer

Take a closer look to check what they are really doing when the install them. 

## What are they really doing

I don't like running random packages like this one on my machine.  Here's what it's doing.

1. Adds these bookmarks to your browser toolbar
2. Changes homepage for chrome, safari, and firefox


__Xml Of the Urls that Get Added__
https://github.com/mrgcohen/ComcastDesktopInstaller/blob/master/a_ComcastInstaller.pkg/Scripts/comcast_prefs.xml

__Script that adds bookmarks and changes homepage__
https://github.com/mrgcohen/ComcastDesktopInstaller/blob/master/a_ComcastInstaller.pkg/Scripts/add_bookmarks.rb

## Safari Code

### Code that determines preferences locations
```ruby
SAFARI_BOOKMARKS_LOCATION = "Library/Safari/Bookmarks.plist"
SAFARI_PREFERENCES_LOCATION = "Library/Preferences/com.apple.Safari.plist"
SAFARI_CONFIGURATION_LOCATION = "Library/Safari/Configurations.plist.signed"
```

### Code that handles creating preferences for safari

```ruby 
Dir.chdir() do
  ##
  ## Bookmarks
  ##
  if (File.exist?(SAFARI_BOOKMARKS_LOCATION))
    if (system 'plutil -convert xml1 '+SAFARI_BOOKMARKS_LOCATION)
      # bm_file = File.new(SAFARI_BOOKMARKS_LOCATION,"r")
      parsedBm = Plist::parse_xml(SAFARI_BOOKMARKS_LOCATION)
      barFolder = nil
      parsedBm["Children"].each { |folder|  
        if (folder["Title"] == "BookmarksBar")
          barFolder = folder
          break
        end
      }
      if barFolder != nil
        if barFolder["Children"] == nil
          barFolder["Children"] = []
        end
        puts "Items on BookmarksBar: "+barFolder["Children"].length.to_s
        # search for an existing "Comcast Xfinity" folder
        i = barFolder["Children"].length-1
        while i > -1
          if barFolder["Children"][i]["Title"] == BOOKMARK_FOLDER_NAME
            barFolder["Children"].delete_at(i)
          end
          i -= 1
        end
        
        puts "Adding Folder..."
        comcastBookmarksArray = []
        bookmarksArray.each { |bookmark|
              uri = {
                "title"=>bookmark["title"]
              }
              bm = {
                "URIDictionary"   =>  uri,
                "URLString"       =>  bookmark["url"],
                "WebBookmarkType" =>  "WebBookmarkTypeLeaf"
              }
              comcastBookmarksArray.push(bm)
            }
        
        comcastFolder = {
          "Title"           =>  BOOKMARK_FOLDER_NAME,
          "WebBookmarkType" =>  "WebBookmarkTypeList",
          "Children"        => comcastBookmarksArray
        }
      barFolder["Children"].push(comcastFolder)
      bm_file = File.new(SAFARI_BOOKMARKS_LOCATION, "w")
      bm_file.write(Plist::Emit.dump(parsedBm))
      bm_file.close
      end
      if (system 'plutil -convert binary1 '+SAFARI_BOOKMARKS_LOCATION)
        puts "successfully saved changes to Safari bookmarks"
      else
        puts "error saving changes to safari bookmarks!"
      end
    else
      puts "Failed to convert Bookmarks.plist with status: "+$?.to_s
    end
  else
    puts "could not find Safari bookmarks plist file at "+SAFARI_BOOKMARKS_LOCATION
  end
```

### Here they set the homepage

```ruby  
  ##
  ## Homepage
  ##
  if (File.exist?(SAFARI_PREFERENCES_LOCATION))
    if (system 'plutil -convert xml1 '+SAFARI_PREFERENCES_LOCATION)
      parsedPrefs = Plist::parse_xml(SAFARI_PREFERENCES_LOCATION)
      puts "homepage currently set to - "+parsedPrefs["HomePage"].to_s
      puts "\treplacing with Comcast homepage"
      parsedPrefs["HomePage"] = homepage
      pref_file = File.new(SAFARI_PREFERENCES_LOCATION,"w")
      pref_file.write(Plist::Emit.dump(parsedPrefs))
      pref_file.close
      if (system 'plutil -convert binary1 '+SAFARI_PREFERENCES_LOCATION)
        puts "successfully saved Safari preferences plist file"
      else
        puts "error saving changes to safari preferences"
      end
    else
      puts "could not convert Safari preferences to xml"
    end
  else
    puts "could not find Safari preferences file at "+SAFARI_PREFERENCES_LOCATION
  end
```
  
  ### Then they try to set the search provider, fortunately they fail  :)
  
```ruby
##
## Search Provider - doesn't work :-(
##
# if (File.exist?(SAFARI_CONFIGURATION_LOCATION))
#     parsedConfigs = Plist::parse_xml(SAFARI_CONFIGURATION_LOCATION)
#     alreadyHasComcast = false
#     puts "supports the following search providers:"
#     parsedConfigs["SearchProviders"]["SearchProviderList"].each { |provider|
#       puts provider["ShortName"]
#       if (provider["ScriptingName"] == "Comcast")
#         alreadyHasComcast = true
#       end
#     }
#     if (!alreadyHasComcast)
#       comcastNode = {
#         "HomePageURLs"  =>  [searchProviderHomepage],
#         "HostSuffixes"  =>  [".comcast.net"],
#         "PathPrefixes"  =>  ["/search"],
#         "ScriptingName" =>  "Comcast",
#         "ShortName"     =>  "Comcast",
#         "SearchUrlTemplate" => searchProviderUrl+"{searchTerms}" 
#       }
#       parsedConfigs["SearchProviders"]["SearchProviderList"].push(comcastNode)
#       configFile = File.new(SAFARI_CONFIGURATION_LOCATION,"w")
#       configFile.write(Plist::Emit.dump(parsedConfigs))
#       configFile.close
#     end
#   else
#     puts "could not find Safari configuration file at "+SAFARI_CONFIGURATION_LOCATION
#   end
end
```
