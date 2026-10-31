# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.1] - 2026-10-31

### Added
- `Parse_Exact` (`String`, `Wide_String`, `Wide_Wide_String` overloads)
  returning `Exact_Result`: the exact value of a literal as
  `(-1 if Negative) * Significand * Radix ** Scale`. `Significand` and `Scale`
  are `Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer`, so no power of the
  radix is formed. It accepts the syntax `Parse` accepts; it differs only where
  `Parse` hits a Vaton representation limit (see Fixed). The exponent is read
  exactly, up to Vaton's 1900-digit budget. `Radix_Range`, `Exact_Value` and
  `Exact_Result` are new types. A zero exponent is no exponent: `7e0` is
  `(Significand 7, Scale 0)`.

### Fixed
- `Parse` no longer raises `Constraint_Error`, and no longer returns `Ok`
  with a `NaN` value. A decimal whose Vaton build would overflow (`8e39`,
  `3.4e38` for `Float`; `1e308` for `Long_Float`) is returned as its
  exact value in a `Big_Real`, when it fits the budget. Beyond the budget
  (the top of the `Long_Long_Float` range, `1e4932`) it is `Overflow` at the
  end of input.
  Cause: `Vaton.Float_Conversions.Combine` raises instead of reporting
  overflow, and its product is bounded by half the kind's largest value.
  Vaton is not modified. The guard is conservative (a 2^-18 relative margin,
  far above Vaton's float error) and also covers Vaton's `Big_Real` branch
  (a denominator 10 ** (F - E) above 10 ** 1936 is never built).
- Budget and raise fixes, all in `Parse` and `Parse_Exact`, none raises any
  more: a decimal with more than 1900 significand digits (whole and fraction)
  is `Overflow` before any value is built from its digits (`1000` ones, `.`,
  `1000` ones: raised `Storage_Error` before); an exponent is counted before
  it is read (`1e` and 3000 ones: `Parse_Exact` raised `Storage_Error`); a
  based value is accumulated with a bound check before each multiply, so
  `2#1#E6432`, `16#1#E1609` and `2#1#E2147483647` are `Overflow` (they raised
  `Storage_Error`), while `Parse_Exact("2#1#E2147483647")` stays `Ok` with
  `Scale = 2147483647`; `1.123456789012345678e-1919` is `Overflow` (it raised
  `Storage_Error`), and `1.12345678901234567e-1919` is an exact `Big_Real`
  (denominator 10 ** 1936).
  Measured over 239,479 distinct literals (290,750 lines, both separators): no
  raise, `Storage_Error` included; against 0.1.0, 1,405 raised and are now an
  exact `Big_Real`, 1,126 raised and are now `Overflow`, 4,968 `NaN` results
  are now `Overflow`, 99 `Long_Long_Float` literals beyond the budget are now
  `Overflow` (for example `594864e4926`).
- Images are no longer copied or sized from the input: a string of
  20,000,000 ones raised `Storage_Error` (a body slice, an exponent buffer
  and, for `Wide_String`, a narrowed copy, all sized from the whole input);
  it is `Overflow` now. Digits are counted while scanning, the buffers are
  1900 characters, syntax errors still take precedence over the budget.
- Indices no longer overflow: `String (Positive'Last .. Positive'Last) := "-"`
  and a `"0x"` ending at `Positive'Last` raised `Constraint_Error`; positions
  are `Long_Long_Integer` offsets from `Image'First` now (all three string
  types, both entry points).
- `Parse_Exact` keeps a based exponent above `Natural'Last`:
  `Parse_Exact("2#1#E2147483648")` is `(1, Radix 2, Scale 2147483648)`
  (it was `Overflow`); the exponent text may have up to 1900 digits.
- A dropped zero exponent used `'.'` whatever `Decimal_Point`:
  `Parse("7e0", ',')` was 70, `Parse("-1e-0", ',')` was -10 and
  `Parse("0e0", ',')` was `Overflow`. They are the floats 7.0, -1.0 and 0.0.
- The digit added for a dropped zero exponent is no longer charged to the
  budget: 1900 nines and `e0` is `Ok` in `Parse` (it was `Overflow`).
- The `Big_Real` numerator is checked on its actual size:
  `0.000000000000000001e1954` (exactly `10 ** 1936`, the documented maximum)
  is a `Big_Real` (it was `Overflow`); `0.000000000000000002e1954` is
  `Overflow`. Numerator and denominator are each at most `10 ** 1936`.
- `Decimal_Point` is honoured by the decimal grammar. Previously the grammar
  recognised only `.`, while the separator was still given to Vaton, which
  silently dropped it. With `','` the literal `1,5` parsed as the integer
  `15`, and `1.5` as `15` too. Now `','` is the fraction point, and `.` is
  `Invalid_Character` then. A separator Vaton rejects (`+`, `-`, `_`, `e`,
  `E`, a digit) makes decimal literals `Invalid_Character` at position 1.
  Behaviour change, documented: `Decimal_Point ','` literals containing `.`
  were accepted with a wrong value or raised; they are now `Invalid_Character`.
- Decimal numerals with an explicit zero exponent (`2.5e0`, `7E+0`,
  `1.5e-0_0`, ...) parsed as `1`: vaton short-circuits a zero exponent in
  both its machine-float and `Big_Real` paths. The decimal path now holds
  the exponent back and drops it when it is zero (a numeral without fraction
  gets `<Decimal_Point>0` instead, so it stays a floating-point value).

- The memory of one call is bounded: at most 256 KiB, whatever the image
  (measured peak 7.8 KB). `Parse` and `Parse_Exact` never raise on any input
  provided the process can satisfy those allocations; with an exhausted heap
  `Storage_Error` may propagate and no recovery is promised.
- A limit no longer hides a syntax error in `Parse`: `Parse ("2#1#E2147483648X")`
  was `Overflow` at 15, it is `Invalid_Character` at 16 like `Parse_Exact`.
  Limits are reported at the end of input, after the whole literal is valid.
- A 1900-digit numeral with a dropped zero exponent (`9...9e0`) is an exact
  `Big_Real` like its shorter neighbours (it was a `Big_Integer`).
- Every decimal call leaked Vaton's digit arrays (about 62 bytes per call,
  also on syntax errors and in `Parse_Exact`): they are freed on every path now
  (live bytes over 100,000 calls: 9,600,000 before, 0 after, for `1.5`). The
  big-integer based path builds its number directly instead of through a
  decimal image, which also removes a quadratic temporary-string cost.
- Leading zeros and long exponents no longer break Vaton's rules for them
  (the `e` of a literal with both fraction and exponent, `7.5e3`, is still
  streamed against Vaton's `Is_Possible_Piece`; the value is right and Vaton
  0.1.0 does not check it): `007` was `Overflow` (also in 0.1.0) and is the
  `Integer` 7; `-00.5`, `0_0_7`, `00e5` likewise. A decimal
  exponent is given to Vaton without its leading zeros and only up to 7
  significant digits (`1e0000000007` was `Overflow`, it is `1e7`; `0e99999999`
  is an exact zero); a longer one is `Overflow`.

### Changed
- **The value of a literal near a float limit is now exact.** For a decimal
  that the conservative guard flags, `Parse` returned a Vaton float rounded
  to its kind; it returns the exact `Big_Real`. This is a change of value,
  not only of kind: of the 371 literals that moved from a `Long_Float` to a
  `Big_Real` in the measured corpus, all 371 differ from the old float
  (`898845e302`, `89884.5e303`). The 0.1.0 and earlier notes of "same
  value" were wrong.
- `Decimal_Point` values `#`, `x`, `X`, `o`, `O`, `b`, `B` (format
  delimiters) are refused like `+ - _ e E` and the digits: decimal literals are
  `Invalid_Character` at 1 (`Parse("1#5", '#')` is a based literal,
  `Base_Out_Of_Range`, whatever the separator).
- The digits of a based exponent are bounded by the 1900-digit budget in
  `Parse` as in `Parse_Exact` (leading zeros count): 24 corpus literals such as
  `2#1#E` followed by 1900 zeros and `1` are `Overflow` now.
- Documentation: `Parse_Exact` agrees with `Parse` on syntax; the cases where
  `Parse` hits a representation limit and `Parse_Exact` does not are listed
  (`1e4932`, `1e999999999`, `2#1#E6432`, `2#1#E2147483648`). `1e4932` is
  `Overflow` in `Parse`, not an exact `Big_Real`.

## [0.1.0] - 2026-07-13

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

