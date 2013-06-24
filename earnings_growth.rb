require 'rubygems'
require 'nokogiri'
require 'json'
require 'open-uri'
require 'active_record' 

ActiveRecord::Base.establish_connection(  
:adapter  => "mysql",  
:host     => "localhost",  
:username => "root",
:password => "Not4You!",
:database => "piotroski"  
)  

class Tickers < ActiveRecord::Base  
end 

class FastGrowers < ActiveRecord::Base  
end 

all_tickers? = ARGV.delete "-a"
fix = ARGV.delete "-f"

if fix
  fininshed = FastGrowers.find("five_year_growth_rate > 20").map{|t| t.ticker}
else
  finished = all_tickers? ? '' : FastGrowers.select("ticker").map{|t| t.ticker}
end

def clean_numbers(text)
  if text[0] == "("
    text = text[1..-2].to_f * -1
  text
end

url = "http://financials.morningstar.com/ajax/ReportProcess4HtmlAjax.html?&t=#{ticker}&region=usa&culture=en-US&cur=USD&reportType=is&period=12&dataType=A&order=asc&columnYear=5&rounding=3&view=raw&r=356282&callback=jsonp1371870522408&_=1371870527498"

Tickers.where("ticker NOT IN (?)", finished).each do |t|
  ticker = t.ticker
  puts ticker
  response = open(url).read
  json = (response && response.length >= 2) ? JSON.parse(response[/{.*}/]) : nil
  doc = Nokogiri::HTML json['result'] rescue nil
  year_one_earnings  = clean_numbers(doc.css("#data_i84 > #Y_1").text rescue 1)
  year_five_earnings = clean_numbers(doc.css("#data_i84 > #Y_5").text rescue 0)
  growth_multiple = year_five_earnings/year_one_earnings
  growth_rate = growth_multiple ** (1.0/5.0)
  puts growth_rate if growth_rate >= 20
  FastGrowers.create_or_update(:id => t.id, :ticker => ticker, :five_year_growth_rate => growth_rate) 
end
