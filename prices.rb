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

begin
  print "Username: "
  username = $stdin.gets.chomp

  print "Password: "
  system "stty -echo"
  password = $stdin.gets.chomp
  system "stty echo"
rescue NoMethodError, Interrupt
  system "stty echo"
  exit
end

# login with apple id and save cookie to disk
login_response = `curl -s -L --cookie-jar cookies.txt  -H "User-Agent: iTunes-iPhone/5.0 (4; 32GB)" "https://p24-buy.itunes.apple.com/WebObjects/MZFinance.woa/wa/authenticate?attempt=0&why=signIn&guid=foo&password=#{password}&rmp=0&appleId=#{username}&createSession=true"`

if !login_response.match(/passwordToken/)
  puts ""
  puts "Invalid username or password."
  exit
end

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
puts ""

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
puts "Total Value of Apps: $" + prices.inject(:+).to_s
puts "Free Apps: " + (free_apps.to_f / ids_array.length * 100).round.to_s + "%"
puts "Paid Apps: " + (prices.length.to_f / ids_array.length * 100).round.to_s + "%"