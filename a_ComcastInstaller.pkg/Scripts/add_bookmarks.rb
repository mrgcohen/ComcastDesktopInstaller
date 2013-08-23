#!/usr/bin/ruby
# a script to add some bookmarks, loaded from an xml file

require "rexml/document"
require "json"
require "plist"
require "fileutils"




##################
# helper functions
##################

def write_number_as_two_digits(fixnum)
  str = ""
  if (fixnum < 10)
    str = "0"+fixnum.to_s
  else
    str = fixnum.to_s
  end
  return str
end


##################
# Begin Script
##################

puts "\n\n\n----------------------------\n"
puts "Begin add_bookmarks ruby script "+Time.now.to_s
puts "version "+`cat version`
puts "----------------------------\n"
originalDirectory = File.dirname(File.expand_path($0))

puts "script running from "+originalDirectory+"\n\n"

abs_path_to_utils = originalDirectory
if (ARGV[0] != nil)
  abs_path_to_utils = ARGV[0]
end

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



# load an xml file of the bookmarks
# 
prefsXml = File.new("comcast_prefs.xml")
doc = REXML::Document.new(prefsXml)

bookmarksArray = []

homepage = REXML::Text.read_with_substitution(doc.get_elements("document/homepage/url")[0].get_text().to_s())
# homepage is special, and requires an appended parameter to representing the install date
now = Time.now
homepage = homepage + "&cid=insDate"+write_number_as_two_digits(now.month)+write_number_as_two_digits(now.day)+now.year.to_s
searchProviderName = REXML::Text.read_with_substitution(doc.get_elements("document/searchProvider/title")[0].get_text().to_s())
searchProviderUrl = REXML::Text.read_with_substitution(doc.get_elements("document/searchProvider/searchUrl")[0].get_text().to_s())
searchProviderHomepage = REXML::Text.read_with_substitution(doc.get_elements("document/searchProvider/homepageUrl")[0].get_text().to_s())

BOOKMARK_FOLDER_NAME = "XFINITY"

Dir.chdir() do
  doc.get_elements("document/desktopShortcut").each { |shortcutNode|
    titleString = shortcutNode.get_elements("title")[0].get_text().to_s()
    urlString = REXML::Text.read_with_substitution(shortcutNode.get_elements("url")[0].get_text().to_s())
    iconString = shortcutNode.get_elements("icon")[0].get_text().to_s()
    f = File.new("Desktop/#{titleString}.url","w")
    f.write("[InternetShortcut]\nURL="+urlString+"\n")
    f.close
    puts `"#{abs_path_to_utils}/setfileicon" "#{abs_path_to_utils}/#{iconString}" "#{f.path}"`
    puts `"#{abs_path_to_utils}/setfile" -a E "#{f.path}"`
  }
end

successURL = doc.get_elements("document/successURL")[0].get_text().to_s()
f = File.new(abs_path_to_utils+"/successurl","w")
f.write(successURL)


prefsXml.close


# build an array of all the bookmark objects
doc.elements.each("document/bookmark") {|element| 
  bookmark = {}
  bookmark["title"] = REXML::Text.read_with_substitution(element.get_elements("title")[0].get_text().to_s())
  bookmark["url"] = REXML::Text.read_with_substitution(element.get_elements("url")[0].get_text().to_s())
  bookmarksArray.push(bookmark)
}

# debug:
# 
puts "\nhomepage - "+homepage
puts "\nsearch: "+searchProviderName+" - "+searchProviderUrl
bookmarksArray.each {|bookmark|
  puts "\n"
  puts bookmark["title"]+" - "+bookmark["url"]
}

##############
# Chrome
##############

#relative to ~/
CHROME_PREFERENCE_LOCATION = "Library/Application Support/Google/Chrome/Default/Preferences"
CHROME_BOOKMARK_LOCATION = "Library/Application Support/Google/Chrome/Default/Bookmarks"


print "\n\nBegin Chrome Operations\n"
# load the bookmarks json file
Dir.chdir() do
  if (File.exist?CHROME_BOOKMARK_LOCATION)
    bm_file = File.new(CHROME_BOOKMARK_LOCATION, "r")
    parsedChromeBookmarks = JSON.parse(bm_file.readlines.to_s)
    bm_file.close
    folder = {}
    folder["name"] = BOOKMARK_FOLDER_NAME
    folder["type"] = "folder"
    folder["children"] = []
    bookmarksArray.each { |bookmark|
      bm = {}
      bm["name"] = bookmark["title"]
      bm["type"] = "url"
      bm["url"] = bookmark["url"]
      folder["children"].push(bm)
    }
    #search through the existing and see if there's already a "Comcast Xfinity" folder
    a = parsedChromeBookmarks["roots"]["bookmark_bar"]["children"]
    i = a.length-1
    while i > -1
      if a[i]["name"] == BOOKMARK_FOLDER_NAME
        a.delete_at(i)
      end
      i -= 1
    end
    
    parsedChromeBookmarks["roots"]["bookmark_bar"]["children"].unshift(folder)
    bm_file = File.new(CHROME_BOOKMARK_LOCATION,"w")
    bm_file.write(JSON.pretty_generate(parsedChromeBookmarks))
    bm_file.close
  else
    puts "cannot find chrome bookmarks file"
  end
  if (File.exist?CHROME_PREFERENCE_LOCATION)
    pref_file = File.new(CHROME_PREFERENCE_LOCATION,"r")
    parsedPrefs = JSON.parse(pref_file.readlines.to_s)
    pref_file.close
    #homepage
    parsedPrefs["homepage"] = homepage
    
    # #search provider (doesn't seem to work)
    # sn = {
    #   "enabled"=>true,
    #   "encodings"=>"",
    #   "icon_url"=>"",
    #   "instant_url"=>"",
    #   "keyword"=>"comcast",
    #   "name"=>"comcast.net",
    #   "prepopulate_id"=>"0",
    #   "search_url"=>searchProviderUrl+"{searchTerms}",
    #   "suggest_url"=>""
    # }
    # parsedPrefs["default_search_provider"] = sn
    
    
    pref_file = File.new(CHROME_PREFERENCE_LOCATION,"w")
    pref_file.write(JSON.pretty_generate(parsedPrefs))
    pref_file.close
  else 
    puts "cannot find chrome preferences files"
  end
end

##############
# Safari
##############

SAFARI_BOOKMARKS_LOCATION = "Library/Safari/Bookmarks.plist"
SAFARI_PREFERENCES_LOCATION = "Library/Preferences/com.apple.Safari.plist"
SAFARI_CONFIGURATION_LOCATION = "Library/Safari/Configurations.plist.signed"

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

##############
# Firefox
##############

FIREFOX_PROFILES_LOCATION = "Library/Application Support/Firefox/Profiles/"
FIREFOX_SEARCH_PLUGIN_LOCATION = "/Applications/Firefox.app/Contents/MacOS/searchplugins/"

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



print "\n----------------------------\n"
print "script add_bookmarks completed successfully\n\n\n"


