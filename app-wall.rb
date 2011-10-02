#!/usr/bin/ruby
require 'uri'
require 'webrick'
require 'optparse'
include WEBrick

options = {}

optparse = OptionParser.new do |opts|                                                                                                                                                                             
  opts.on('-u', '--username USERNAME', 'your App Store username') do |username|                                                                                                                                                
    options[:username] = username
  end                                                                                                                                                                                                             

  opts.on('-p', '--password PASSWORD', 'your App Store password') do |password|                                                                                                                          
    options[:password] = password                                                                                                                                                                                     
  end
end

begin                                                                                                                                                                                                             
  optparse.parse!                                                                                                                                                  
  mandatory = [:username, :password]                                                                                                                                                                   
  missing = mandatory.select{ |param| options[param].nil? }                                                                                                         
  if not missing.empty?                                                                                                                                           
    puts "Missing options: #{missing.join(', ')}"                                                                                                                 
    puts optparse                                                                                                                                                 
    exit                                                                                                                                                          
  end                                                                                                                                                            
rescue OptionParser::InvalidOption, OptionParser::MissingArgument                                                                                                        
  puts $!.to_s                                                     
  puts optparse                                                    
  exit                                                             
end                                                                

APPLE_ID = options[:username]
PASSWORD = options[:password]

# login with apple id and save cookie to disk
`curl -s -L --cookie-jar cookies.txt  -H "User-Agent: iTunes-iPhone/5.0 (4; 32GB)" "https://p24-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate?attempt=0&why=signIn&guid=foo&password=#{PASSWORD}&rmp=0&appleId=#{APPLE_ID}&createSession=true"`

# fetch purchased app ids
id_response = `curl -s --cookie cookies.txt -H "User-Agent: iTunes-iPhone/5.0 (4; 32GB)" "https://se.itunes.apple.com/WebObjects/MZStoreElements.woa/wa/purchases?guid=foo&mt=8"`
ids = id_response.match(/"contentIds":(.+?), "fetchContentUrl"/m)[1].gsub(/\s+/, "")

# fetch detailed data about ids
url_encoded_ids = URI.escape(ids)
data_response = `curl -s --cookie cookies.txt -H "User-Agent: iTunes-iPhone/5.0 (4; 32GB)" -d "ids=#{url_encoded_ids}&maxCount=10000" "https://se.itunes.apple.com/WebObjects/MZStoreElements.woa/wa/purchasesFragment?guid=foo&mt=8"`

# write json into html file
html = File.read('index.html')
html.gsub!(/this.appData = \{.+?\};/m, "this.appData = #{data_response};")

File.open('index.html', 'w') { |file| file.puts html }

# start local server
dir = Dir::pwd
port = 12000 + (dir.hash % 1000)
server = HTTPServer.new(:Port => port, :DocumentRoot => dir)
['INT', 'TERM'].each { |signal| trap(signal) { server.shutdown } }

fork {
  sleep 1
  `open http://#{Socket.gethostname}:#{port}`
}

server.start 