require 'rubygems'
require 'twitter'
require 'nokogiri'
require 'open-uri'
require 'fileutils'
require 'mechanize'
require 'watir'
require 'watir-webdriver'
require 'date'

# Get today's date and save it as a variable
$todaysdate = Time.now.strftime("%m-%d-%Y")

puts "Today is #{$todaysdate}."

## Create a directory to store today's files
unless File.directory?("files/#{$todaysdate}")
  FileUtils.mkdir_p("files/#{$todaysdate}")
  puts "SpillsBot created a directory to story today's files."
else puts "SpillsBot already created a directory to store today's files."
end

# Specify the driver path
chromedriver_path = "chromedriver.exe"
Selenium::WebDriver::Chrome.driver_path = chromedriver_path

# Configure Twitter settings
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
$rubyrobot = Twitter::REST::Client.new do |config|
  config.consumer_key        = ""
  config.consumer_secret     = ""
  config.access_token        = ""
  config.access_token_secret = ""
end
puts "Settings loaded. SpillsBot is ready to Tweet!"


def downloadreport(rtn,link)
  # Download PDF files of each spill report
  @filename = rtn
  @html = "http://public.dep.state.ma.us/wsc_viewer/#{link}"
    agent = Mechanize.new
    File.open("files/#{$todaysdate}/#{@filename}.pdf", 'w+b') do |file|
       file << agent.get_file(@html)
    end
    puts "Wrote a PDF file for spill report #{@filename}."
    sleep 10
end

def pdftotext(rtn)
  @filename = rtn
  %x(pdftotext.exe files/#{$todaysdate}/#{@filename}.pdf files/#{$todaysdate}/#{@filename}.txt)
  puts "Converted #{@filename}.pdf to a text file."
end


def parsetweet(rtn)
  # Open the text file
  @filename = rtn
  @text = File.read("files/#{$todaysdate}/#{@filename}.txt")
  puts "Opened #{@filename}.txt"

  # Read the log date
  @logdatefull = @text.scan(/1. Log Date:\n\n\d+\/\d\d\/\d\d\d\d\n\n/)[0]
  logdate1_markerstring = "1. Log Date:\n\n"
  logdate2_markerstring = "\n\n"
  @logdate = @logdatefull[/#{logdate1_markerstring}(.*?)#{logdate2_markerstring}/m, 1]
  @logdate.gsub!("/2016", "")
  if @logdate[0] == "0"
    @logdate.slice!(0)
  end

  # Read the log time
  # Old version: @logtimefull = @text.scan(/Log Time:\n\n\d\d:\d\d\n\n\S+ AM\n\n\S+ PM\n\n/)[0]
  @logtimefull = @text.scan(/Log Time:\n\n\d\d:\d\d\n\n\.*AM.*PM\n\n/)[0]
  logtime1_markerstring = "Log Time:\n\n"
  logtime2_markerstring = "\n\n"
  @logtime = @logtimefull[/#{logtime1_markerstring}(.*?)#{logtime2_markerstring}/m, 1]
  if @logtime[0] == "0"
    @logtime.slice!(0)
  end

  logampm1_markerstring = /Log Time:\n\n\d\d:\d\d\n\n/
  logampm2_markerstring = / AM/
  @logampm = @logtimefull[/#{logampm1_markerstring}(.*?)#{logampm2_markerstring}/m, 1]
  if @logampm.size == 6
    @logampm = "AM"
  else
    @logampm = "PM"
  end

  @logdatetime = "#{@logdate} #{@logtime}#{@logampm}"

  # Read the release location
  releaselocation1_markerstring = 'C. RELEASE OR THREAT OF RELEASE \(TOR\) /SITE LOCATION:\n\n'
  releaselocation2_markerstring = "D. RELEASE OR TOR INFORMATION:"
  @releaselocationchunk = @text[/#{releaselocation1_markerstring}(.*?)#{releaselocation2_markerstring}/m, 1]
  
  releasesitename1_markerstring = (/1. Location Aid\/Site Name: /)
  releasesitename2_markerstring = "\n\n2. Street Address:"
  @releasesitename = @releaselocationchunk[/#{releasesitename1_markerstring}(.*?)#{releasesitename2_markerstring}/m, 1]
  @releasesitename = @releasesitename.split.map(&:capitalize).join(' ')

  releaseaddress1_markerstring = "2. Street Address:"
  releaseaddress2_markerstring = /\d(\.)/
  @releaseaddress = @releaselocationchunk[/#{releaseaddress1_markerstring}(.*?)#{releaseaddress2_markerstring}/m, 1]
  @releaseaddress.gsub!("\n", "")
  @releaseaddress.strip!
  @releaseaddress = @releaseaddress.split.map(&:capitalize).join(' ')
  @releaseaddress.gsub!("Street", "St")
  @releaseaddress.gsub!("Road", "Rd")

  releasetown1_markerstring = "4. City/Town:\n\n"
  releasetown2_markerstring = /(\\n\\n)*\d(\.)/
  @releasetown = @releaselocationchunk[/#{releasetown1_markerstring}(.*?)#{releasetown2_markerstring}/m, 1]
  @releasetown = @releasetown.split.map(&:capitalize).join(' ')
  @releasetown = @releasetown.gsub!(/, .+/, "")

  releaselocationtypechunk1_markerstring = '6. Type of Location: \(check all that apply\) '
  releaselocationtypechunk2_markerstring = "D. RELEASE OR TOR INFORMATION:\n\n"
  @releaselocationtypechunk = @text[/#{releaselocationtypechunk1_markerstring}(.*?)#{releaselocationtypechunk2_markerstring}/m, 1]
  @releaselocationtypechunk.gsub!("\n\n", " ")
  @releaselocationtypechecks = @releaselocationtypechunk.scan(/\w\w\w\w\w\w [a-z][\.]/)
  @releaselocationtypechecks.each {|subarray|
  subarray.gsub!(/\w\w\w\w\w\w /, "")
  subarray.gsub!(".", "")
  }

  locationtypes = Hash.new
  locationtypes["a"] = "School"
  locationtypes["b"] = "Water body"
  locationtypes["c"] = "Right of Way"
  locationtypes["d"] = "Utility easement"
  locationtypes["e"] = "Roadway"
  locationtypes["f"] = "Municipal"
  locationtypes["g"] = "State"
  locationtypes["h"] = "Residential"
  locationtypes["i"] = "Open space"
  locationtypes["j"] = "Private"
  locationtypes["k"] = "Industrial"
  locationtypes["l"] = "Commercial"
  locationtypes["m"] = "Federal"
  locationtypes["n"] = "Other"

  @releaselocationtypechecks.map!{|subarray| subarray = locationtypes["#{subarray}"]}

  releaselocationtypedescribe1_markerstring = "Describe:"
  releaselocationtypedescribe2_markerstring = "\n\n"
  @releaselocationtypedescribe = @releaselocationchunk[/#{releaselocationtypedescribe1_markerstring}(.*?)#{releaselocationtypedescribe2_markerstring}/m, 1]

  if @releaselocationtypedescribe != ""
    @releaselocationtypechecks << @releaselocationtypedescribe
  end

  @releaselocationtype = @releaselocationtypechecks.join("/")

  # Record the oil/hazmat substance that was released
  materialreleasedchunk1_markerstring = '11. List below the Oils \(O\) or Hazardous Materials \(HM\) that exceed their Reportable Concentration \(RC\) or Reportable Quantity \(RQ\) by the greatest amount. '
  materialreleasedchunk2_markerstring = "12. Description of Release or Threat of Release"
  @materialreleasedchunk = @text[/#{materialreleasedchunk1_markerstring}(.*?)#{materialreleasedchunk2_markerstring}/m, 1]
  materialreleasedname1_markerstring = "Units RCs Exceeded, if Applicable\n\n"
  materialreleasedname2_markerstring = "\n\n"
  @materialreleasedname = @materialreleasedchunk[/#{materialreleasedname1_markerstring}(.*?)#{materialreleasedname2_markerstring}/m, 1]

  @tweet = "#{@logdatetime}\n#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}"

  if @tweet.length > 92
    @tweet.slice!(89..-1)
    @tweet << "..."
  end

  puts @tweet.inspect

end

def savejpg(rtn)
  # Save static image of the locator map
  @id = rtn
  @releaseaddresscleaned = @releaseaddress.gsub(" ","+")
  @center = "#{@releaseaddresscleaned},#{@releasetown},MA"
  agent = Mechanize.new

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=8&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_1_8zoom.jpg")
  sleep 10
  
  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=9&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_2_9zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=10&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_3_10zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=11&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_4_11zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=12&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_5_12zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=13&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_6_13zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=14&size=600x300&maptype=roadmap&sensor=false&language=&markers=color:red|label:none|#{@center}")
  agent.page.save("files/#{$todaysdate}/#{@id}_7_14zoom.jpg")
  sleep 10

  agent.get("http://maps.google.com/maps/api/staticmap?center=#{@center}&zoom=19&size=600x300&maptype=hybrid&sensor=false")
  agent.page.save("files/#{$todaysdate}/#{@id}_8_satellite.jpg")
  sleep 10
end

def labeljpg(rtn)
  @jpg = rtn
  %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_1_8zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_1_8zoom_labeled.jpg)

    %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_2_9zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_2_9zoom_labeled.jpg)

     %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_3_10zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_3_10zoom_labeled.jpg)

     %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_4_11zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_4_11zoom_labeled.jpg)

     %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_5_12zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_5_12zoom_labeled.jpg)

     %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_6_13zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_6_13zoom_labeled.jpg)

     %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_7_14zoom.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_7_14zoom_labeled.jpg)

    %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe files/#{$todaysdate}/#{@jpg}_8_satellite.jpg \
     -undercolor "#00000080" -fill white \
     -pointsize 24 -annotate +20+20 \
     "#{@releasesitename}\n#{@releaseaddress}, #{@releasetown}\n#{@materialreleasedname}" \
      files/#{$todaysdate}/#{@jpg}_8_satellite_labeled.jpg)
end

def makegif(rtn)
  @jpg = rtn
  %x(ImageMagick-6.9.3-2-portable-Q16-x86/convert.exe -delay 200 -loop 0 \
      "files/#{$todaysdate}/#{@jpg}_*_*_labeled.jpg" files/#{$todaysdate}/#{@jpg}_animation.gif)
end

def broadcast(rtn,link)
  @picture = rtn
  @link = "http://public.dep.state.ma.us/wsc_viewer/#{link}"
  $rubyrobot.update_with_media("#{@tweet}\n#{@link}", open("files/#{$todaysdate}/#{@picture}_animation.gif") )
  puts "SpillsBot has broadcast information about #{@picture} to the world!"
  sleep 10
end

# Open the DEP site, search and download an HTML file containing the newest spill reports
browser = Watir::Browser.new :chrome
browser.goto 'http://public.dep.state.ma.us/wsc_viewer/main.aspx'
browser.text_field(:name => 'dtpFrom_input').set $todaysdate
browser.text_field(:name => 'dtpTo_input').set $todaysdate
browser.checkbox(:name => 'chkListForms$0').set
browser.link(:text => 'Search').click
sleep 25

# Save the HTML file
File.open("files/#{$todaysdate}/spillhtml.html",'w') {|f| f.write browser.html }
puts "Downloaded HTML page of new spills."
browser.close

# Parse the links
@tablearray = []
@spillhtml = Nokogiri::HTML(open("files/#{$todaysdate}/spillhtml.html"))
@linktable = @spillhtml.css("//table[@id=G_UltraWebTab1xctl00xGrid]//tr")
@linktable.each{|item| @tablearray << item.css('td').map{|td| td.text.strip}}
@tablearray.delete_at(0)
@tablearray.each{|set|
  set.delete_at(6)
  set.delete_at(4)
  set.delete_at(3)
  set.delete_at(1)
  }

@links = @linktable.css("td[2] a").map { |link| link['href'] }

@counter = 0
@tablearray.each {|subarray|
  subarray.insert(1, @links[@counter])
  @counter += 1
}

## Generate a list of the files that have already been downloaded today
@pdfs = Dir["files/#{$todaysdate}/*.pdf"]
pdfname1_markerstring = "files/#{$todaysdate}/"
pdfname2_markerstring = ".pdf"
@pdfs.map!{|subarray|
  subarray = subarray[/#{pdfname1_markerstring}(.*?)#{pdfname2_markerstring}/m, 1]
}

@tablearray.delete_if {|subarray| @pdfs.include? subarray[0]}

puts "The list of new spills includes: #{@tablearray}"

@tablearray.each{|subarray|
  downloadreport(subarray[0],subarray[1])
  pdftotext(subarray[0])
  parsetweet(subarray[0])
  savejpg(subarray[0])
  labeljpg(subarray[0])
  makegif(subarray[0])
  broadcast(subarray[0],subarray[1])
}