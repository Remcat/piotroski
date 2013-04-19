require 'rubygems'
require 'nokogiri'
require 'open-uri'

class CompanyFundamentals
  def initialize(ticker, quarterly=false, debug=nil, verbose=nil)
    @ticker = ticker
    @quarterly = quarterly
    @debug = debug
    @verbose = debug || verbose

    google = "https://www.google.com/finance?q=NYSE%3A#{ticker}&fstype=iii" 
    goog_says = open(google) rescue nil

    google_finance_page = Nokogiri::HTML(goog_says)

    yahoo = "http://finance.yahoo.com/q?s=#{ticker.downcase}"
    yahoo_says = open(yahoo) rescue nil
    yahoo_finance_page = Nokogiri::HTML(yahoo_says)

    ycharts = "http://ycharts.com/companies/#{ticker.upcase}/price_to_book_value"
    ycharts_says = open(ycharts) rescue nil
    ycharts_page = Nokogiri::HTML(ycharts_says)

    timeframe = quarterly ? "interim" : "annual"

    @balance_sheet    = google_finance_page.css("#bal#{timeframe}div > #fs-table tr")
    @income_statement = google_finance_page.css("#inc#{timeframe}div > #fs-table tr")
    @cash_flow        = google_finance_page.css("#cas#{timeframe}div > #fs-table tr")
    @price            =  yahoo_finance_page.css("#yfs_l84_#{@ticker.downcase}").text.to_f rescue nil
    @price_to_book    =        ycharts_page.css("#pgNameVal").text.split[0].to_f rescue nil    
  end
    
  def statement(statement_section, pattern)
 
    tr = statement_section.detect { |tr|
      tr.css('td').any? { |td| td.text =~ pattern }
    }

    tr.css('td')[1..-1].map { |td| td.text.delete(",").to_f }
  end

  def calculate_so    
    unless @so_now
      shares_outstanding_columns = statement(@balance_sheet, /Total Common Shares Outstanding/)

      @so_now  = shares_outstanding_columns[0]
      @so_then = shares_outstanding_columns[1]
    end
  end

  def parse_book_value_statements    
    total_assets_columns = statement(@balance_sheet, /Total Assets/)

    @ta_now  = total_assets_columns[0]
    @ta_then = total_assets_columns[1]

    total_liabilities_columns = statement(@balance_sheet, /Total Liabilities/)

    @tl_now  = total_liabilities_columns[0]

    calculate_so
  end

  def book_to_market
    parse_book_value_statements
    book_value = (@ta_now - @tl_now)/@so_now
    my_bm = book_value/@price

    puts "book value is  : " + book_value.to_s if @verbose
    puts "price is       : " + @price.to_s if @verbose
    puts "book to market : " + my_bm.to_s if @verbose
    puts "ycharts bm     : " + (1/@price_to_book).to_s if @verbose

    my_bm
  end

  def parse_piotroski_statements
    net_income_columns = statement(@income_statement, /Net Income$/)
 
    @ni_now  = net_income_columns[0]
    @ni_then = net_income_columns[1]

    cash_flow_columns = statement(@cash_flow, /Cash from Operating Activities/)

    @cf_now  = cash_flow_columns[0]
    @cf_then = cash_flow_columns[1]

    total_assets_columns = statement(@balance_sheet, /Total Assets/)

    @ta_now  = total_assets_columns[0]
    @ta_then = total_assets_columns[1]

    total_liabilities_columns = statement(@balance_sheet, /Total Liabilities/)

    @tl_now  = total_liabilities_columns[0]
  
    long_term_debt_columns = statement(@balance_sheet, /Total Long Term Debt/)

    @lt_now  = long_term_debt_columns[0]
    @lt_then = long_term_debt_columns[1]

    current_assets_columns = statement(@balance_sheet, /Total Current Assets/)

    @ca_now  = current_assets_columns[0]
    @ca_then = current_assets_columns[1]

    current_liabilities_columns = statement(@balance_sheet, /Total Current Liabilities/)

    @cl_now  = current_liabilities_columns[0]
    @cl_then = current_liabilities_columns[1]

    gross_profit_columns = statement(@income_statement, /Gross Profit/)

    @gp_now  = gross_profit_columns[0]
    @gp_then = gross_profit_columns[1]

    revenue_columns = statement(@income_statement, /Total Revenue/)

    @rev_now  = revenue_columns[0]
    @rev_then = revenue_columns[1]

    calculate_so
  end

  def check_it(message, test)
    if @verbose
      puts message
    end
    if test
      ret = 1
      if @verbose
        puts 1
        puts "---"
      end
    elsif @verbose
      puts 0 
      puts "---"
    end
    ret || 0
  end

  def piotroski_score()
    parse_piotroski_statements

    sum = 0

    sum += check_it("Positive Net Income  : 1 point if ni_now >= 0", @ni_now >= 0)
    if @debug
      puts "ni_now : " + @ni_now.to_s
      puts "ni_then : " + @ni_then.to_s
      puts "---"
    end

    sum += check_it("Cash Flow Positive  : 1 point if cf_now >= 0", @cf_now >= 0)
    if @debug
      puts "cf_now : " + @cf_now.to_s
      puts "cf_then : " + @cf_then.to_s 
      puts "---"
    end

    
    sum += check_it("Net Income to Total Assets : 1 point if ni_now/ta_now >= ni_then/ta_then", @ni_now/@ta_now >= @ni_then/@ta_then)
    if @debug
      puts "ta_now : " + @ta_now.to_s
      puts "ta_then : " + @ta_then.to_s
      puts "---"
    end

    sum += check_it("Net Income and Cash Flow : 1 point if ni_now >= cf_now", @ni_now <= @cf_now )

    check_it("Debt to Assets : 1 point if lt_now/ta_now <= lt_then/ta_then", @lt_now/@ta_now <= @lt_then/@ta_then)
    if @debug
      puts "lt_now : " + @lt_now.to_s
      puts "lt_then : " + @lt_then.to_s
      puts "---"
    end
    
    safe_ca_to_cl_now  = @ca_now == 0 ? 0 : @ca_now/@cl_now
    safe_ca_to_cl_then = @ca_then == 0 ? 0 : @ca_then/@cl_then
    sum += check_it("Current Ratio : 1 point if ca_now/cl_now>ca_then/cl_then", safe_ca_to_cl_now >= safe_ca_to_cl_then)
    if @debug
      puts "ca_now : " + @ca_now.to_s
      puts "ca_then : " + @ca_then.to_s
      puts "cl_now : " + @cl_now.to_s
      puts "cl_then : " + @cl_then.to_s
      puts "---"
    end

    sum += check_it("Shares Outstanding : 1 point if so_now<=so_then", @so_now <= @so_then)
    if @debug
      puts "so_now : " + @so_now.to_s
      puts "so_then : " + @so_then.to_s
      puts "---" 
    end
    
    sum += check_it("Gross Margin : 1 point if gp_now/rev_now>gp_then/rev_then", @gp_now/@rev_now>@gp_then/@rev_then)
    if @debug
      puts "calculated_values : " + (@gp_now/@rev_now).to_s + " " + (@gp_then/@rev_then).to_s
      puts "gp_now : " + @gp_now.to_s
      puts "gp_then : " + @gp_then.to_s
      puts "rev_now : " + @rev_now.to_s
      puts "rev_then : " + @rev_then.to_s
      puts "---"
    end

    sum += check_it("Change in Revenue vs Change in Assets : 1 point if rev_then-rev_now>ta_then-ta_now", @rev_now-@rev_then>@ta_now-@ta_then)
    if @debug
      puts "ta_now : " + @ta_now.to_s
      puts "ta_then : " + @ta_then.to_s
    end
    puts "------------------------------------------------------------" unless @verbose
    puts "Total #{@quarterly ? "QUARTERLY" : "ANNUAL"} Score for ticker #{@ticker} : " + sum.to_s
    puts "------------------------------------------------------------" unless @verbose
    sum
  end
end
