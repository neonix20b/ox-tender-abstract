## [0.9.5] - 2025-08-06

### Fixed

- Fixed encoding compatibility error when processing API blocking messages
- Fixed missing `include_attachments` parameter in `search_tenders` and `search_tenders_with_auto_wait` methods
- Improved error handling for binary response data from API

### Changed

- Enhanced encoding handling in `ArchiveProcessor` to safely handle UTF-8 and BINARY responses
- Restored `include_attachments` parameter to all search methods with default value `true`

### Added

- Better error logging for encoding issues
- Safe encoding conversion using `force_encoding('UTF-8').scrub`

## [0.9.3] - 2025-07-27

- Added support for parsing tender documents
- Added support for parsing contract documents
- Added support for parsing organization documents
- Added support for parsing generic documents
- Added support for parsing attachments
- Added support for parsing tender documents
- Added support for parsing contract documents
- Added support for parsing organization documents

## [0.9.0] - 2025-07-15

- Initial release
- Added support for parsing tender documents
- Added support for parsing contract documents
- Added support for parsing organization documents
- Added support for parsing generic documents
- Added support for parsing attachments
- Added support for parsing tender documents
- Added support for parsing contract documents
- Added support for parsing organization documents
