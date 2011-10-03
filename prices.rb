#!/usr/bin/ruby
require 'uri'
require 'optparse'
require 'rubygems'
begin
  require 'typhoeus'
  SLOW_VERSION = false
rescue LoadError
  SLOW_VERSION = true
end

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

# convert to array
ids_array = ids[1..-2].split(',').collect! {|n| n.to_i}

# fetch prices
PRICE_MATCH = /<div class="price">\$(.+?)<\/div>/
TITLE_MATCH = /<h1>(.+?)<\/h1>/

prices = []
free_apps = 0

if SLOW_VERSION
  # slow version
  ids_array.each do |id|
    response = `curl -s "http://itunes.apple.com/us/app/a/id#{id}?mt=8"`
    if response.match(PRICE_MATCH)
      title = response.match(TITLE_MATCH)[1]      
      price = response.match(PRICE_MATCH)[1].to_f      
      puts "#{title}: $#{price}"
      prices << price
    else
      free_apps += 1
    end
  end  
else  
# multithreaded action
  hydra = Typhoeus::Hydra.new(:max_concurrency => 50)

  ids_array.each do |id|
    req = Typhoeus::Request.new("http://itunes.apple.com/us/app/a/id#{id}?mt=8")
    req.on_complete do |response|        
      if response.body.match(PRICE_MATCH)
        title = response.body.match(TITLE_MATCH)[1]      
        price = response.body.match(PRICE_MATCH)[1].to_f      
        puts "#{title}: $#{price}"
        prices << price
      else
        free_apps += 1
      end
    end
    hydra.queue req
  end

  hydra.run
end


puts ""
puts "Total Spent: $" + prices.inject(:+).to_s
puts "Free Apps: " + (free_apps.to_f / ids_array.length * 100).round.to_s + "%"
puts "Paid Apps: " + (prices.length.to_f / ids_array.length * 100).round.to_s + "%"