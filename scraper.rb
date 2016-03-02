require 'scraperwiki'
require 'mechanize'
require 'cgi'

comment_url = 'mailto:hcc@hobartcity.com.au?Subject='

agent = Mechanize.new
agent.agent.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

agent.get('https://apply.hobartcity.com.au/Common/Common/terms.aspx')
form = agent.page.form_with(:id => 'aspnetForm')
button = form.button_with(:name => 'ctl00$ctMain$BtnAgree')

# Prevent "unsupported content-encoding: gzip,gzip" error.
agent.content_encoding_hooks << lambda { |httpagent, uri, response, body_io|
  response['Content-Encoding'] = 'gzip'
}

agent.submit(form, button)

# Now we can get to the page with the data.
page = agent.get('https://apply.hobartcity.com.au/CurrentlyAdvertised')

applications = page.search('.result').collect do |result|
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
  detail_page = agent.get(page_info['info_url'])

  contact_div = detail_page.at_css('div#b_ctl00_ctMain_info_Officer')
  unless contact_div.nil?
    page_info['council_contact'] = contact_div.text.gsub(/\s+/, ' ').strip  # Remove carriage returns.
  end

  location_div = detail_page.at_css('div#b_ctl00_ctMain_info_prop')
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