require 'selenium-webdriver'
require 'nokogiri'
require 'uri'
require 'csv'

class YCombinatorScraper
  def initialize(n, filters = {})
    @n = n
    @filters = filters
    @company_details = []
  end

  def scrape_companies
    base_url = "https://www.ycombinator.com/companies"

    query_params = URI.encode_www_form(@filters)
    url = "#{base_url}?#{query_params}"

    options = Selenium::WebDriver::Chrome::Options.new(args: ['headless'])
    driver = Selenium::WebDriver.for(:chrome, options: options)

    begin
      driver.get(url)
      sleep 2

      doc = Nokogiri::HTML(driver.page_source)
      companies = doc.css('._section_86jzd_146 ._company_86jzd_338')

      companies.each do |company|
        data = scrape_attributes(company)
        detail_url = 'https://www.ycombinator.com/' + company.at_css('a')[:href]
        driver.get(detail_url)
        sleep 2
        details_doc = Nokogiri::HTML(driver.page_source)
        data['company_url'] = details_doc.css('.ycdc2 div section div.my-8.mb-4 div a.mb-2').text.strip
        data['founders'] = extract_founders(details_doc)

        @company_details.push(data)
        break if @company_details.size >= @n
      end

      generate_csv(@company_details)
    ensure
      driver.quit
    end
  end

  private

  def scrape_attributes(company)
    {
      name: company.at_css('._coName_86jzd_453')&.text,
      location: company.at_css('._coLocation_86jzd_469')&.text,
      short_description: company.at_css('._coDescription_86jzd_478')&.text,
      yc_batch: company.at_css('._pillWrapper_86jzd_33 ._pill_86jzd_33')&.text
    }
  end

  def extract_founders(details_doc)
    details_doc.css('div.mx-auto.max-w-ycdc-page div.shrink-0 div.flex').map do |founder|
      {
        name: founder.css('div')[1].css('span')[0].text,
        linked_in: founder.css('div')[1].css('span a')&.first&.[](:href)
      }
    end
  end

  def generate_csv(data)
    csv_file_path = "y_combinator_scraper.csv"
    puts "Generating CSV file at: #{csv_file_path}"
    CSV.open(csv_file_path, "wb") do |csv|
      csv << ["Name", "Location", "Short Description", "YC Batch", "Company URL", "Founders"]
      data.each do |company|
        founders = company['founders'].map { |founder| "#{founder[:name]} (LinkedIn: #{founder[:linked_in]})" }.join("; ")
        csv << [
          company[:name],
          company[:location],
          company[:short_description],
          company[:yc_batch],
          company['company_url'],
          founders
        ]
      end
    end
    puts "CSV file generated successfully."
  end
end

filters = {
  batch: "W21",
  industry: "Healthcare",
  # regions:'Canada',
  # tags: 'B2B'
  # team_size: "1-10",
  # highlight_women: true,
  # highlight_latinx: true,
  # highlight_black: true,
  # top_company:true,
  # isHiring:true,
  # nonprofit: true,
  # app_video_public:true,
  # demo_day_video_public:true,
  #app_answers:true,
  # question_answers:true,
}

scraper = YCombinatorScraper.new(50, filters)
scraper.scrape_companies