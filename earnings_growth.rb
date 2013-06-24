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
finished = FastGrowers.select("ticker").map{|t| t.ticker}

Tickers.where("ticker NOT IN (?)", finished).each do |t|
  ticker = t.ticker
  puts ticker
  url = "http://financials.morningstar.com/ajax/ReportProcess4HtmlAjax.html?&t=#{ticker}&region=usa&culture=en-US&cur=USD&reportType=is&period=12&dataType=A&order=asc&columnYear=5&rounding=3&view=raw&r=356282&callback=jsonp1371870522408&_=1371870527498"
  response = open(url).read
  json = (response && response.length >= 2) ? JSON.parse(response[/{.*}/]) : nil
  doc = Nokogiri::HTML json['result'] rescue nil
  year_one_earnings = doc.css("#data_i84 > #Y_1").text.to_f rescue 1
  year_five_earnings = doc.css("#data_i84 > #Y_5").text.to_f rescue 0
  growth_multiple = year_five_earnings/year_one_earnings
  growth_rate = growth_multiple ** (1.0/5.0)
  puts growth_rate if growth_rate >= 20
  FastGrowers.create(:ticker => ticker, :five_year_growth_rate => growth_rate) 
end
