require 'rubygems'
require 'nokogiri'
require 'open-uri'

class CompanyFundamentals
  def initialize(ticker, quarterly=false)
    @ticker = ticker

    google = "https://www.google.com/finance?q=NYSE%3A#{ticker}&fstype=iii" 
    goog_says = open(google) rescue nil

    google_finance_page = Nokogiri::HTML(goog_says)

    ycharts = "http://ycharts.com/companies/#{ticker.upcase}/price_to_book_value"
    ycharts_says = open(ycharts) rescue nil
    
    duration = quarterly ? "interim" : "annual"
    
    @balance_sheet = google_finance_page.css("#bal#{duration}div > #fs-table tr")
    @income_statement = google_finance_page.css("#inc#{duration}div > #fs-table tr")
    @cash_flow = google_finance_page.css("#cas#{duration}div > #fs-table tr")
    @price_to_book = Nokogiri::HTML(ycharts_says).css("#pgNameVal").text.split[0].to_f rescue nil
  end
    
  def statement(statement_section, pattern)
 
    tr = statement_section.detect { |tr|
      tr.css('td').any? { |td| td.text =~ pattern }
    }

    tr.css('td')[1..-1].map { |td| td.text.delete(",").to_f }
  end

  def parse_book_value_statements    
    total_assets_columns = statement(@balance_sheet, /Total Assets/)

    @ta_now  = total_assets_columns[0]
    @ta_then = total_assets_columns[1]

    total_liabilities_columns = statement(@balance_sheet, /Total Liabilities/)

    @tl_now  = total_liabilities_columns[0]
  end

  def book_to_market(verbose = nil)
    #parse_book_value_statements
    bm = 1/@price_to_book

    #puts "book value is  : " + book_value.to_s if verbose
    puts "price to book is : " + @price_to_book.to_s if verbose
    puts "book to market   : " + bm.to_s if verbose

    bm
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

    shares_outstanding_columns = statement(@balance_sheet, /Total Common Shares Outstanding/)

    @so_now  = shares_outstanding_columns[0]
    @so_then = shares_outstanding_columns[1]
  end

  def piotroski_score(debug=nil)
    parse_piotroski_statements

    sum = 0
  
    # first   : 1 point if ni_now >= 0
    puts "---"
    puts @ni_now >= 0  ? (sum+=1; 1) : 0
    puts "---"
#    if debug
#      puts net_income_columns.to_s
#      puts "ni_now : " + ni_now.to_s
#      puts "ni_then : " + ni_then.to_s
#      puts "---"
#    end
    # second  : 1 point if cf_now >= 0
    puts @cf_now >= 0 ? (sum+=1; 1)  : 0 
    puts "---"
#    if debug
#      puts cash_flow_columns.to_s
#      puts "cf_now : " + cf_now.to_s
#      puts "cf_then : " + cf_then.to_s 
#      puts "---"
#    end
    # third   : 1 point if ni_now/ta[2] >= ni[3]/ta[3]
    puts @ni_now/@ta_now >= @ni_then/@ta_then ? (sum+=1; 1)  : 0
    puts "---"
#    if debug
#      puts total_assets_columns.to_s
#      puts "ta_now : " + ta_now.to_s
#      puts "ta_then : " + ta_then.to_s
#      puts "---"
#    end
    # fourth  : 1 point if ni_now >= cf_now
    puts @ni_now <= @cf_now ? (sum+=1; 1)  : 0
    puts "---"
    # fifth   : 1 point if lt[2]/ta[2] <= lt[3]/ta[3]
    puts @lt_now/@ta_now <= @lt_then/@ta_then ? (sum+=1; 1)  : 0
    puts "---"
#    if debug
#      puts long_term_debt_columns.to_s
#      puts "lt_now : " + lt_now.to_s
#      puts "lt_then : " + lt_then.to_s
#      puts "---"
#    end
    # sixth   : 1 point if ca[2]/cl[2]>ca[3]/cl[3]
    safe_ca_to_cl_now  = @ca_now == 0 ? 0 : @ca_now/@cl_now
    safe_ca_to_cl_then = @ca_then == 0 ? 0 : @ca_then/@cl_then
    puts safe_ca_to_cl_now >= safe_ca_to_cl_then ? (sum+=1; 1) : 0
    puts "---"
#    if debug
#      puts current_assets_columns.to_s
#      puts "ca_now : " + ca_now.to_s
#      puts "ca_then : " + ca_then.to_s
#      puts current_liabilities_columns.to_s
#      puts "cl_now : " + cl_now.to_s
#      puts "cl_then : " + cl_then.to_s
#      puts "---"
#    end
    # seventh : 1 point if so[2]<=so[3]
    puts @so_now <= @so_then ? (sum+=1; 1) : 0
    puts "---"
#    if debug
#      puts shares_outstanding_columns.to_s
#      puts "so_now : " + so_now.to_s
#      puts "so_then : " + so_then.to_s
#      puts "---"
#    end
    puts "eighth (Gross Margin) : 1 point if gp_now/rev_now>gp_then/rev_then" if debug
    puts @gp_now/@rev_now>@gp_then/@rev_then ? (sum+=1; 1)  : @gp_now/@rev_now == @gp_then/@rev_then ? (sum+=0.5; 0.5) : 0
    puts "---"
#    if debug
#      puts "calculated_values : " + (gp_now/rev_now).to_s + " " + (gp_then/rev_then).to_s
#      puts gross_profit_columns.to_s
#      puts "gp_now : " + gp_now.to_s
#      puts "gp_then : " + gp_then.to_s
#      puts revenue_columns.to_s
#      puts "rev_now : " + rev_now.to_s
#      puts "rev_then : " + rev_then.to_s
#      puts "---"
#    end
    # ninth   : 1 point if rev[3]-rev[2]>ta[3]-ta[2]
    puts @rev_now-@rev_then>@ta_now-@ta_then ? (sum+=1; 1)  : 0
    puts "---"
#    if debug
#      puts total_assets_columns.to_s
#      puts "ta_now : " + ta_now.to_s
#      puts "ta_then : " + ta_then.to_s
#    end
    puts "Total ANNUAL Score for ticker #{@ticker} : " + sum.to_s if debug
    sum
  end
end

