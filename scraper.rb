require 'scraperwiki'
require 'mechanize'

case ENV['MORPH_PERIOD']
when 'thismonth'
  period = 'thismonth'
when 'lastmonth'
  period = 'lastmonth'
else
  period = 'thisweek'
end
puts "Getting '" + period + "' data, changable via MORPH_PERIOD environment";

url_base    = 'https://apply.hobartcity.com.au'
da_url      = url_base + '/Pages/XC.Track/SearchApplication.aspx?d=' + period + '&k=LodgementDate&t=PLN'
comment_url = 'mailto:coh@hobartcity.com.au'

# setup agent and turn off gzip as council web site returning 'encoded-content: gzip,gzip'
agent = Mechanize.new
agent.request_headers = { "Accept-Encoding" => "" }

# Accept terms
page = agent.get(url_base + '/Common/Common/terms.aspx')
form = page.forms.first
form["ctl00$ctMain$BtnAgree"] = "I Agree"
page = form.submit

# Scrape DA page
page = agent.get(da_url)
results = page.search('div.result')

results.each do |result|
  council_reference = result.search('a')[1].inner_text.strip

  address = result.search('span')[0].inner_text.strip
  address = address.gsub(/\s+/, ' ')

  description = result.search('div')[0].inner_text.strip
  description = description.split( /\r?\n/ )[0].split(' - ')[1]

  info_url    = result.search('a')[0]['href']
  info_url    = info_url.sub!('../..', '')
  info_url    = url_base + info_url

  date_received = result.search('div')[0].inner_text.strip
  date_received = date_received.split("Lodged:")[1].strip
  date_received = Date.parse(date_received).to_s

  record = {
    'council_reference' => council_reference,
    'address'           => address,
    'description'       => description,
    'info_url'          => info_url,
    'comment_url'       => comment_url + council_reference,
    'date_scraped'      => Date.today.to_s,
    'date_received'     => date_received
  }

  # Saving data
  if (ScraperWiki.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    puts "Saving record " + record['council_reference'] + ", " + record['address']
#     puts record
     ScraperWiki.save_sqlite(['council_reference'], record)
  else
    puts "Skipping already saved record " + record['council_reference']
  end
end
