# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial public API: `Parse` for `String`, `Wide_String`, and `Wide_Wide_String`
  inputs, returning a structured `Parse_Result`.
- Support for decimal, C-style prefixed (`0x` / `0o` / `0b`), and Ada based
  (`base#value#` with optional `E` exponent) numeric literals, with underscore
  separators and optional leading sign.
- `Radix_Literals.Integers` generic facade for range-checked narrowing to a
  caller-chosen signed integer target, reporting target-range failures
  (including narrowing a float to an integer target) as `Overflow`.
- Fast machine-integer accumulation path with automatic fall-back to
  `Big_Integer` accumulation on overflow.
- `SPARK_Mode` annotations on the public API and a proof harness at
  `prove/prove_radix_literals.adb`. Reproduce with:
  `alr gnatprove --level=1 --output=oneline`.
- AUnit test suite covering the full grammar matrix, sign handling,
  underscore rules, digit-vs-base validation, structural errors, and the
  generic facade.

### Fixed
- Decimal numerals with an explicit zero exponent (`2.5e0`, `7E+0`,
  `1.5e-0_0`, ...) parsed as `1`: vaton short-circuits a zero exponent in
  both its machine-float and `Big_Real` paths. The decimal path now holds
  the exponent back and drops it when it is zero (a numeral without fraction
  gets `.0` instead, so it stays a floating-point value).

[Unreleased]: https://example.invalid/radix_literals/compare/HEAD
