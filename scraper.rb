require "icon_scraper"

IconScraper.scrape_with_params(
  url: "https://apply.hobartcity.com.au",
  period: "last14days",
  types: ["PLN"]
) do |record|
  IconScraper.save(record)
end
