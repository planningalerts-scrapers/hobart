require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'date'
require 'cgi'
require 'json'

# The council's app will only ever show 10 applications at a time,
# sorted alphabetically (regardless of requested sort order).
# By keeping the time window small (1 week) there will hopefully never be more than 10 applications to be consumed.
url = 'https://apply.hobartcity.com.au/Pages/XC.Track/SearchApplication.aspx?d=lastweek&k=LodgementDate&t=PLN'

# Some other example views that can be used:
# url = 'https://apply.hobartcity.com.au/Pages/xc.track/reportApplications.aspx?t=PLN&k=Locality&p=0&d=o&snapshot=y&s=Dynnyrne'
# url = 'https://apply.hobartcity.com.au/Pages/xc.track/reportApplications.aspx?id=PieListMap&t=PLN&k=Locality&p=0&d=o&snapshot=y&s=Battery+Point'

# The site rejects non-secure HTTP requests, but appears to have a broken SSL certificate(?).
doc = Nokogiri::HTML(open(url, :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

comment_url = 'mailto:hcc@hobartcity.com.au?Subject='

applications = doc.css('div.result').collect do |result|
  page_info = {}
  # page_info['address'] = result.css('a')[0].text.strip  # Addresses are stored inconsistently here. Use detail page.
  page_info['council_reference'] = result.css('a')[1].text.strip
  info_url = result.css('a')[0]['href']
  info_url.slice!('../..')
  info_url = 'https://apply.hobartcity.com.au' + info_url
  page_info['info_url'] = info_url
  s = result.text
  s = s.slice(s.index(' - ') + 3..s.length)
  a = s.split("\n")
  page_info['description'] = a[0].strip
  d = a[2].strip.split('/')
  page_info['date_received'] = d[2] + '-' + d[1] + '-' + d[0]
  page_info['date_scraped'] = Date.today.to_s
  page_info['comment_url'] = comment_url + CGI::escape("Planning Application Enquiry: " + page_info['council_reference'])

  # Now scrape the detail page for additional information and a more consistently formatted address.
  # (Adding this step slows the scraper significantly.)
  page = Nokogiri::HTML(open(page_info['info_url'], :ssl_verify_mode => OpenSSL::SSL::VERIFY_NONE))

  contact_div = page.at_css('div#b_ctl00_ctMain1_info_Officer')
  unless contact_div.nil?
    page_info['council_contact'] = contact_div.text.strip
  end

  location_div = page.at_css('div#b_ctl00_ctMain1_info_prop')
  unless location_div.nil?  # The location will always be provided though right?
    page_info['address'] = location_div.at_css('a').text
  end

  page_info
end

applications.each do |record|
  if (ScraperWikiMorph.select("* from data where `council_reference`='#{record['council_reference']}'").empty? rescue true)
    ScraperWiki.save_sqlite(['council_reference'], record)
    puts 'Saving record ' + record['council_reference']
  else
    puts 'Skipping already saved record ' + record['council_reference']
  end
end