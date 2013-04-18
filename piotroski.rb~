v, $VERBOSE = $VERBOSE, nil

require 'rubygems'
require File.join(File.dirname(__FILE__), 'company_fundamentals.rb')
require 'active_record' 

$VERBOSE = v 

ActiveRecord::Base.establish_connection(  
:adapter  => "mysql",  
:host     => "localhost",  
:username => "root",
:password => "Not4You!",
:database => "piotroski"  
)  

class Tickers < ActiveRecord::Base  
end 

if __FILE__ == $0
  ticker = ARGV[0]
  d = ARGV.delete "-d"
  v = ARGV.delete "-v"
  q = ARGV.delete "-q"
  if ticker == 'all-tickers'

    (1..Tickers.count).to_a.each do |id|
      t = Tickers.find(id).ticker
      c = CompanyFundamentals.new(t, quarterly)
      puts t
      bm = c.book_to_market rescue 0
      bm = bm  == 1/0.0 ? nil : bm
      Tickers.update(id, :annual_score => begin c.piotroski_score rescue nil end, :book_to_market => bm)
    end
  
  else 

    ticker = 'AAPL' unless ticker
    c = CompanyFundamentals.new(ticker, quarterly)
    c.book_to_market(verbose)
    c.piotroski_score(debug)

  end
end
