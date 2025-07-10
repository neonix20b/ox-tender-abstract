# OxTenderAbstract

Ruby library for working with Russian procurement system API (zakupki.gov.ru) via SOAP-XML. Provides modular architecture for fetching and parsing tender data.

## Features

- 🚀 Modular architecture with separate components
- 📊 Complete XML tender document parsing
- 📁 Automatic archive processing (GZIP + ZIP)
- 🔧 Simple configuration and usage
- 📝 Returns structured Hash results
- 🛡️ Error handling and logging

## Installation

Add to your Gemfile:

```ruby
gem 'ox-tender-abstract'
```

Or install directly:

```bash
gem install ox-tender-abstract
```

## Quick Start

### Configuration

```ruby
require 'ox-tender-abstract'

# Global configuration
OxTenderAbstract.configure do |config|
  config.token = key
  config.timeout_open = 30
  config.timeout_read = 120
  config.logger = Logger.new(STDOUT)
end
```

### Search tenders by region and date

```ruby
# Search tenders for a specific date
result = OxTenderAbstract.search_tenders(
  org_region: "77",              # Region code (77 = Moscow)
  exact_date: "2025-07-09"       # Date in YYYY-MM-DD format
)

if result.success?
  puts "Found tenders: #{result.data[:tenders].size}"
  
  result.data[:tenders].first(3).each do |tender|
    puts "Registry Number: #{tender[:reestr_number]}"
    puts "Price: #{tender[:max_price]} rubles"
    puts "Organization: #{tender[:organization_name]}"
    puts "Contact: #{tender[:contact_email]}"
    puts "---"
  end
else
  puts "Error: #{result.error}"
end

# Example output:
# Found tenders: 564
# Registry Number: 0373100066925000138
# Price: 25606.51 rubles
# Organization: FEDERAL STATE INSTITUTION "STATE INSTITUTION FOR THE OPERATION OF ADMINISTRATIVE BUILDINGS..."
# Contact: otd_zakupki@guaz.ru
```

### Enhanced search with detailed information

The `enhanced_search_tenders` method automatically downloads and processes archives to extract comprehensive tender information including attachments, contact details, addresses, and metadata.

```ruby
# Enhanced search with detailed information including attachments
result = OxTenderAbstract.enhanced_search_tenders(
  org_region: "77",              # Region code (77 = Moscow)
  exact_date: "2025-07-09",      # Date in YYYY-MM-DD format
  include_attachments: true      # Include attachment information
)

if result.success?
  puts "Found tenders: #{result.data[:tenders].size}"
  
  result.data[:tenders].first(3).each do |tender|
    puts "Registry Number: #{tender[:reestr_number]}"
    puts "Title: #{tender[:title]}"
    puts "Price: #{tender[:max_price]} #{tender[:currency]}"
    puts "Organization: #{tender[:organization_name]}"
    puts "Contact Person: #{tender[:contact_person_name]}"
    puts "Contact Email: #{tender[:contact_email]}"
    puts "Contact Phone: #{tender[:contact_phone]}"
    puts "Address: #{tender[:post_address]}"
    puts "ETP: #{tender[:etp_name]} (#{tender[:etp_url]})"
    puts "Start Date: #{tender[:start_date]}"
    puts "End Date: #{tender[:end_date]}"
    puts "Attachments: #{tender[:attachments_count]}"
    
    if tender[:attachments]
      tender[:attachments].each do |attachment|
        puts "  - #{attachment[:file_name]} (#{attachment[:file_size]} bytes)"
        puts "    Description: #{attachment[:description]}"
        puts "    URL: #{attachment[:url]}"
      end
    end
    puts "---"
  end
else
  puts "Error: #{result.error}"
end
```

### Get documents by registry number

```ruby
result = OxTenderAbstract.get_docs_by_reestr_number(
  reestr_number: "0373100013125000767"
)

if result.success?
  puts "Found archives: #{result.data[:archive_urls].size}"
end
```

### Working with client directly

```ruby
# Create client with token
client = OxTenderAbstract.client(token: "your_token")

# Or use global configuration
client = OxTenderAbstract.client

# Search by region
result = client.get_docs_by_region(
  org_region: "77",
  subsystem_type: "PRIZ",
  document_type: "epNotificationEF2020", 
  exact_date: "2025-07-09"
)

# Download and process archive
if result.success?
  result.data[:archive_urls].each do |archive_url|
    archive_result = client.download_archive_data(archive_url)
    if archive_result.success?
      files = archive_result.data[:files]
      puts "Files in archive: #{files.size}"
      
      # Parse XML files
      xml_files = files.select { |name, _| name.downcase.end_with?(".xml") }
      xml_files.each do |file_name, file_data|
        xml_result = client.parse_xml_document(file_data[:content])
        if xml_result.success? && xml_result.data[:document_type] == :tender
          tender = xml_result.data[:content]
          puts "Tender: #{tender[:reestr_number]} - #{tender[:max_price]} rubles"
        end
      end
    end
  end
end
```

## Architecture

The library consists of the following modules:

- **Client** - main SOAP API client
- **XmlParser** - XML document parser
- **ArchiveProcessor** - archive handler
- **Configuration** - library configuration
- **Result** - result structure
- **DocumentTypes** - document types and constants

## Supported subsystem types

```ruby
SUBSYSTEM_TYPES = %w[
  PRIZ RPEC RPGZ RJ RDI BTK RPKLKP RPNZ RGK EA UR REC RPP RVP RRK RRA
  RNP RKPO PPRF615 RD615 LKOK OZ OD223 RD223 MSP223 IPVP223 TRU223
  RJ223 RPP223 RPZ223 RI223 RZ223 OV223 TPOZ223 POZ223 RNP223 POM223 ZC
]
```

## Electronic notification types

```ruby
ELECTRONIC_NOTIFICATION_TYPES = %w[
  epNotificationEF2020 epNotificationEF epNotificationOK2020 
  epNotificationEP2020 epNotificationZK2020 epNotificationZP2020 
  epNotificationISM2020 fcsNotificationEF fcsNotificationOK 
  fcsNotificationEP fcsNotificationZK fcsNotificationZP 
  fcsNotificationISM fcsPlacement fcsPlacementResult
]
```

## Result structure

```ruby
{
  success: true,
  data: {
    tenders: [
      {
        reestr_number: "0373100066925000138",
        title: nil,  # May be empty for some tenders
        max_price: "25606.51",
        currency: "РОССИЙСКИЙ РУБЛЬ",
        organization_name: "ФЕДЕРАЛЬНОЕ КАЗЕННОЕ УЧРЕЖДЕНИЕ \"ГОСУДАРСТВЕННОЕ УЧРЕЖДЕНИЕ ПО ЭКСПЛУАТАЦИИ АДМИНИСТРАТИВНЫХ ЗДАНИЙ И ДАЧНОГО ХОЗЯЙСТВА МИНИСТЕРСТВА ФИНАНСОВ РОССИЙСКОЙ ФЕДЕРАЦИИ\"",
        contact_email: "otd_zakupki@guaz.ru",
        contact_phone: nil,
        contact_name: nil,
        start_date: nil,
        end_date: nil,
        placement_type: "Электронный аукцион",
        # Additional metadata
        source_file: "epNotificationEF2020_0373100066925000138_1.xml",
        archive_url: "https://int.zakupki.gov.ru/dstore/ip/download/PRIZ/file.zip?ticket=...",
        processed_at: 2025-07-10 12:51:57 +0300
      }
    ],
    total_archives: 6,
    total_files: 564,
    processed_at: 2025-07-10 12:51:57 +0300
  },
  error: nil,
  metadata: {}
}
```

## Error handling

```ruby
begin
  result = OxTenderAbstract.search_tenders(
    org_region: "77",
    exact_date: "2025-07-09"
  )
rescue OxTenderAbstract::AuthenticationError => e
  puts "Authentication error: #{e.message}"
rescue OxTenderAbstract::NetworkError => e
  puts "Network error: #{e.message}"
rescue OxTenderAbstract::ParseError => e
  puts "Parsing error: #{e.message}"
end
```

## Real-world performance

Based on production testing with zakupki.gov.ru API:

- **564 tenders** processed in ~14 seconds
- **6 archives** downloaded and extracted
- **564 XML files** parsed successfully
- Average processing time: ~25ms per tender

```ruby
# Real example from July 9, 2025 - Moscow region
result = OxTenderAbstract.search_tenders(
  org_region: "77",
  exact_date: "2025-07-09"
)

puts result.data[:tenders].size  # => 564
puts result.data[:total_files]   # => 564
puts result.data[:total_archives] # => 6

# Processing typically takes 10-15 seconds for a full day's data
```

## Requirements

- Ruby >= 3.0.0
- API token for zakupki.gov.ru

## Development

After cloning the repository:

```bash
bin/setup
```

To run tests:

```bash
bundle exec rspec
```

## License

This gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).
