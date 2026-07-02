# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-07-02

### Fixed
- Preserve keyword arguments through `perform_debounce` on Ruby 3 (`ruby2_keywords`); jobs whose `perform` takes keyword arguments no longer raise `ArgumentError` on execution
- Repair test suite left broken by the activejob-debounce rebrand (stale `sidekiq-debouncer` require and `Sidekiq::Debouncer` configuration reset)

## [1.0.0] - 2025-01-13

### Added
- Initial release
- `Sidekiq::Debouncer::Concern` module for adding debounce behavior to ActiveJob classes
- `debounce_for` class method to configure debounce duration
- `perform_debounce` class method to queue debounced jobs
- Global configuration for default_delay, buffer, ttl, and redis_connection
- Support for ActiveRecord objects via GlobalID
- Automatic Redis key cleanup after job execution
- Comprehensive test suite
