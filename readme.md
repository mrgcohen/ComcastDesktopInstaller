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

### Safari Preferences that are changed

```ruby
SAFARI_BOOKMARKS_LOCATION = "Library/Safari/Bookmarks.plist"
SAFARI_PREFERENCES_LOCATION = "Library/Preferences/com.apple.Safari.plist"
SAFARI_CONFIGURATION_LOCATION = "Library/Safari/Configurations.plist.signed"
```

### Homepage change code

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
