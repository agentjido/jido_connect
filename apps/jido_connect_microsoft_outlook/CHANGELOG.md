# CHANGELOG

All notable changes to `jido_connect_microsoft_outlook` will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-05-19

### Added

- Initial scaffold: integration DSL, auth profile reuse from the Microsoft
  foundation package, scope resolver, catalog pack shell, and generated module
  tests.
- Action catalog shell listing planned mail read and send actions. Handlers
  return `{:error, :not_implemented}` until full message actions are added.
