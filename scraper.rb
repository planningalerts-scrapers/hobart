require "icon_scraper"

IconScraper.scrape_with_params(
  url: "https://apply.hobartcity.com.au",
  period: "last14days",
  types: ["PLN"]
) do |record|
  record["council_reference"].gsub!("PLN-", "")
  record["address"] = record["address"].gsub(",", "").split(" ").map(&:capitalize).join(" ")
  IconScraper.save(record)
end
