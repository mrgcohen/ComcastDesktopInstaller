ComcastDesktopInstaller
=======================

## Comcast Desktop Installer

Take a closer look to check what they are really doing when the install them. 

## What are they really doing

I don't like running random packages like this one on my machine.  Here's what it's doing.

1. Adds these bookmarks to your browser toolbar
2. Changes homepage for safari, and firefox
3. Switches search provider on firefox


__Xml Of the Urls that Get Added__
https://github.com/mrgcohen/ComcastDesktopInstaller/blob/master/a_ComcastInstaller.pkg/Scripts/comcast_prefs.xml

__Script that adds bookmarks and changes homepage__
https://github.com/mrgcohen/ComcastDesktopInstaller/blob/master/a_ComcastInstaller.pkg/Scripts/add_bookmarks.rb

## Creation of bookmarks from xml
```ruby
# build an array of all the bookmark objects
doc.elements.each("document/bookmark") {|element| 
  bookmark = {}
  bookmark["title"] = REXML::Text.read_with_substitution(element.get_elements("title")[0].get_text().to_s())
  bookmark["url"] = REXML::Text.read_with_substitution(element.get_elements("url")[0].get_text().to_s())
  bookmarksArray.push(bookmark)
}
```

## Try to kill browsers before install 

(and why you see message to close browsers)

```ruby
##
## Kill existing browser processes
##
safariPID = `ps ux -w -w | awk '/Safari.app/ && !/awk/ {print $2}'`
puts "safari PID = "+safariPID
if (safariPID != "" && safariPID != nil)
  puts "killing Safari"
  `kill #{safariPID.to_s}`
  `sleep 2`
end

firefoxPID = `ps ux -w -w | awk '/Firefox.app/ && !/awk/ {print $2}'`
puts "firefox PID = "+firefoxPID
if (firefoxPID != "" && firefoxPID != nil)
  puts "killing Firefox"
  `kill #{firefoxPID.to_s}`
  `sleep 2`
end

chromePIDs = `ps ux -w -w | awk '/Chrome.app/ && !/awk/ {print $2}'`
chromeOpened = false
puts "chrome PID = "+chromePIDs
chromePIDArray = chromePIDs.split("\n")
chromePIDArray.each { |pid|
  if (pid != "" && pid != nil)
    puts "killing chrome process "+pid
    `kill #{pid.to_s}`
    chromeOpened=true
  end
}
if chromeOpened
  `sleep 2`
end
```

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
__*fail = commented out__
  
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

## Firefox 

### First they get the config locations

```ruby
FIREFOX_PROFILES_LOCATION = "Library/Application Support/Firefox/Profiles/"
FIREFOX_SEARCH_PLUGIN_LOCATION = "/Applications/Firefox.app/Contents/MacOS/searchplugins/"
```

### Then they write a function to add settings to your firefox profile

Here they pass in the bookmarks to set, homepage, and search among other arguments. This method modifies a Firefox sqlite db that is used. 

```ruby
## add all our settings to this profile
def add_settings_to_ff_profile(profile_name, bookmarksArray, homepage, abs_path_to_utils, supportSearch)
  puts File.expand_path($0)
  
  Dir.chdir() do
    puts File.expand_path($0)
    # this just tests to make sure we have all the bookmarks stuff in place for this profile
    # (i.e. making sure we've used firefox under this profile)
    db_location = FIREFOX_PROFILES_LOCATION+"/"+profile_name+"/places.sqlite"
    sqlite3_location = abs_path_to_utils+"/sqlite3"
    roots = `'#{sqlite3_location}' '#{db_location}' 'SELECT * FROM moz_bookmarks_roots'`
    if ($?.to_i == 0)
      puts roots
      toolbar_folder_id = `'#{sqlite3_location}' '#{db_location}' 'SELECT folder_id FROM "moz_bookmarks_roots" WHERE root_name="toolbar"'`
      puts "toolbar folder id = "+toolbar_folder_id
      # TODO: check for the Comcast Xfinity folder
      comcast_folder_id = `'#{sqlite3_location}' '#{db_location}' 'SELECT id FROM "moz_bookmarks" WHERE title="#{BOOKMARK_FOLDER_NAME}"'`
      if (comcast_folder_id != nil && comcast_folder_id!="")
        puts "Xfinity bookmark folder exists"
      else
        # make the bookmark folder
        puts `'#{sqlite3_location}' '#{db_location}' 'INSERT INTO moz_bookmarks (type, parent, title) VALUES(2,#{toolbar_folder_id},"#{BOOKMARK_FOLDER_NAME}")'`
        comcast_folder_id = `'#{sqlite3_location}' '#{db_location}' 'SELECT id FROM "moz_bookmarks" WHERE title="#{BOOKMARK_FOLDER_NAME}"'`
        puts "created Xfinity folder, id="+comcast_folder_id
        # insert each bookmark into the moz_places table, get its id, add it as a bookmark
        bookmarksArray.each { |bookmark|
          puts "\n___________\nbookmark "+bookmark["title"]
          puts `'#{sqlite3_location}' '#{db_location}' 'INSERT INTO moz_places (url, title, hidden, typed) VALUES("#{bookmark["url"]}","#{bookmark["title"]}",0,0)'`
          place_id = `'#{sqlite3_location}' '#{db_location}' 'SELECT id FROM moz_places WHERE url="#{bookmark["url"]}"'`
          puts "id in places db="+place_id
          puts `'#{sqlite3_location}' '#{db_location}' 'INSERT INTO moz_bookmarks (type, fk, parent, position, title) VALUES(1,#{place_id},#{comcast_folder_id},0,"#{bookmark["title"]}")'`
        }
      end
    else
      puts "Error opening places database!"
      # return here because we won't be able to install the extension either
      return nil
    end
    
    # now add a homepage preference in user.js
    #preflocation = FIREFOX_PROFILES_LOCATION+"/"+profile_name+"/user.js"
    #prefs = File.new(preflocation, "a")
    #prefs.write("\nuser_pref(\"browser.startup.homepage\", \"#{homepage}\");")
    #if supportSearch
    #  prefs.write("\nuser_pref(\"browser.search.selectedEngine\", \"Xfinity\");\nuser_pref(\"browser.search.suggest.enabled\", false);")
    #end
    #prefs.close
    # 
    # 
    # 
```

#### Here they chnage the homepage and search
    
```ruby
    # Scan through the prefs.js file to change the homepage and, if applicable, the selected search.
    preflocation = FIREFOX_PROFILES_LOCATION+"/"+profile_name+"/prefs.js"
    prefs = File.new(preflocation, "r")
    newPrefs = ""
    didChange = prefs == nil
    didFindSearchPref = false
    handledCurrentLine = false
    prefs.each_line("\n") { |line|
      a = line.scan(/user_pref\([ ]*"browser.startup.homepage",[ ]*"(.*)"[ ]*\);/)
      if (a.length > 0 && !a[0].to_s.eql?(homepage))
        puts "found line, homepage is set to "+a[0].to_s
        newPrefs += "user_pref(\"browser.startup.homepage\", \""+homepage+"\");\n"
        handledCurrentLine = true
        didChange = true
      end
      if (supportSearch && !handledCurrentLine)
        a = line.scan(/user_pref\([ ]*"browser.search.selectedEngine",[ ]*"(.*)"[ ]*\);/)
        if (a.length > 0)
          if (!a[0].to_s.eql?("Xfinity"))
            puts "search is set incorrectly to "+a[0].to_s+", changing the line"
            newPrefs += "user_pref(\"browser.search.selectedEngine\", \"Xfinity\");\n"
            didChange = true
            handledCurrentLine = true
          end
          didFindSearchPref = true
        end
      end
      if (!handledCurrentLine)
        newPrefs += line
      end
      handledCurrentLine = false
    }
    prefs.close
    if (supportSearch && !didFindSearchPref)
      puts "didn't find a search preference at all"
      newPrefs += "user_pref(\"browser.search.selectedEngine\", \"Xfinity\");\n"
      didChange = true
    end
    
    if didChange
      puts "prefs changed"
      File.rename(preflocation, preflocation+".old")
      prefs = File.new(preflocation, "a")
      prefs.write(newPrefs)
      prefs.close
    end
    
    
    # if requested, delete the search database (and its backup file), which will force FF to recreate when it starts up
    if supportSearch
    #  puts "removing search database so that FF will have to rebuild"
    #  puts "rm -rf #{FIREFOX_PROFILES_LOCATION}/#{profile_name}/search.sqlite"
      `rm -rf '#{FIREFOX_PROFILES_LOCATION}/#{profile_name}/search.sqlite'`
      `rm -rf '#{FIREFOX_PROFILES_LOCATION}/#{profile_name}/search.json'`
    end
    
    
  end
  
end

```

#### Run the script above

```ruby
puts "--------\nBegin Firefox Operations"

couldInstallSearch = false
# Copy the search plugin xml file into the search plugins folder if we can find it
if (File.exists?(FIREFOX_SEARCH_PLUGIN_LOCATION))
  `cp '#{abs_path_to_utils}/firefox_search_plugin.xml' '#{FIREFOX_SEARCH_PLUGIN_LOCATION}/comcast.xml'`
  couldInstallSearch = true
else
  couldInstallSearch = false
  puts 'cannot find firefox application folder. perhaps the user has installed it in a non-standard location. unable to install search plugins'
end

Dir.chdir() do
  ff_profile_list = `ls '#{FIREFOX_PROFILES_LOCATION}'`.split("\n")
  ff_profile_list.each { |profile_folder|
    Dir.chdir() do
      ## This check is necessary because Firefox seems to throw random non-folders in the
      ## profile directory (when profiles have spaces in the names)
      puts "couldInstallSearch="+couldInstallSearch.to_s
      if (File.directory?(FIREFOX_PROFILES_LOCATION+profile_folder))
        puts "\n--------\nprofile folder: "+profile_folder+"\n--------"
        add_settings_to_ff_profile(profile_folder, bookmarksArray,homepage,abs_path_to_utils,couldInstallSearch)
      else
        puts 'seems this profile is not a directory '+profile_folder
      end
    end

  }
end
```

