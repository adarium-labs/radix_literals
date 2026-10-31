# radix_literals

A small Ada/SPARK library that parses numeric literals written in several
radices and syntaxes into a `Vaton.Number`. It is the missing front-end that
[`vaton`](https://github.com/mhatzl/vaton) explicitly does not cover:
non-decimal bases and Ada-style based literals. It detects and validates the
radix, then reuses `vaton` for the actual value construction and
smallest-type selection.

## Supported formats

| Syntax        | Example                | Base   | Notes                                     |
|---------------|------------------------|--------|-------------------------------------------|
| decimal       | `-1_000`, `3.14`, `1e4` | 10    | integers and floats, via vaton            |
| `0x` / `0X`   | `0xDEAD_BEEF`          | 16     | prefix and digits case-insensitive        |
| `0o` / `0O`   | `0o377`                | 8      |                                           |
| `0b` / `0B`   | `0b1010_1010`          | 2      |                                           |
| `base#...#`   | `16#FF#`, `2#1010#`    | 2..16  | Ada-style                                 |
| `base#...#E`  | `16#FF#E2` = 65280     | 2..16  | Ada exponent: `value * base ** exp`       |

Underscore separators are allowed inside any digit run, one at a time and
only between two digits. A leading `+` or `-` is accepted on every path.

## Quick start

Add to your `alire.toml`:

```toml
[[depends-on]]
radix_literals = "~0.1.0"
```

Then in your code:

```ada
with Ada.Text_IO; use Ada.Text_IO;
with Radix_Literals;
with Radix_Literals.Integers;
with Vaton;

procedure Demo is
   use type Radix_Literals.Parse_Status;
   use type Vaton.Number_Kind;

   R : constant Radix_Literals.Parse_Result :=
     Radix_Literals.Parse ("0xFF");
begin
   if R.Status = Radix_Literals.Ok
     and then R.Value.Kind = Vaton.Integer
   then
      Put_Line ("Value =" & Integer'Image (R.Value.Integer));
      --  prints: Value = 255
   end if;

   --  Range-checked narrowing to a specific target type:
   declare
      package To_Int is new Radix_Literals.Integers (Integer);
      C : constant To_Int.Conv_Result := To_Int.Parse ("16#FF#E2");
   begin
      if C.Status = Radix_Literals.Ok then
         Put_Line ("As Integer =" & Integer'Image (C.Value));
         --  prints: As Integer = 65280
      end if;
   end;
end Demo;
```

A complete runnable example is in `example/src/example.adb`, built as the
`example` executable by the dedicated `example` sub-crate:

```
cd example
alr build
./bin/example
```

## Exact values: `Parse_Exact`

`Parse` returns a `Vaton.Number`, which Vaton narrows to the smallest
standard type. A decimal with 16 to 18 significant digits becomes a
floating-point kind, so the value no longer determines the literal exactly.
`Parse_Exact` returns the exact value instead, in the shape

```
value = (-1 if Negative) * Significand * Radix ** Scale
```

```ada
type Exact_Value is record
   Negative    : Boolean;
   Significand : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer; -- >= 0
   Radix       : Radix_Range;  -- 2 .. 16: 10 for decimals, the base otherwise
   Scale       : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer;
end record;

type Exact_Result (Status : Parse_Status := Error) is record
   case Status is
      when Ok    => Value : Exact_Value;
      when Error => Reason : Error_Kind; Position : Positive;
   end case;
end record;

function Parse_Exact
  (Image : String; Decimal_Point : Wide_Character := '.')
   return Exact_Result;
--  plus Wide_String and Wide_Wide_String overloads, as for Parse
```

- **Syntax**: `Parse_Exact` accepts and rejects exactly the literals `Parse`
  does, with the same `Reason` and `Position` on every syntax error (for
  example `16#F.8#` is `Invalid_Character` at 5 in both).
- **Representation limits** are where they differ: `Parse` is limited by
  what `Vaton` can build, `Parse_Exact` only by the digit budget. Some
  literals that `Parse` reports as `Overflow` are `Ok` in `Parse_Exact`
  (results from a run of each):

  | Literal | `Parse` | `Parse_Exact` (Significand, Radix, Scale) |
  |---|---|---|
  | `1e4932` | `Overflow` at 6 | `(1, 10, 4932)` |
  | `1e999999999` | `Overflow` at 11 | `(1, 10, 999999999)` |
  | `1e999999999999999999999` | `Overflow` at 23 | `(1, 10, 999999999999999999999)` |
  | `2#1#E6432` | `Overflow` at 9 | `(1, 2, 6432)` |
  | `2#1#E2147483648` | `Overflow` at 15 | `(1, 2, 2147483648)` |
- Decimals: `Significand` is all digits, whole part then fraction;
  `Scale` is the exponent minus the number of fraction digits.
  `1.25e3` is `(125, Radix 10, Scale 1)`.
- `0x` / `0o` / `0b` and Ada based literals: `Radix` is the base and `Scale`
  is the Ada exponent (0 for prefixed literals). `16#FF#E2` is
  `(255, Radix 16, Scale 2)`.
- `Negative` is kept for zero: `-0.0` is `Negative` with `Significand = 0`.
- A zero exponent is no exponent: `7e0` is `(7, Scale 0)`. Trailing zeros of
  the fraction are kept: `7.0` is `(70, Scale -1)`.
- `Significand` and `Scale` are unbounded `Big_Integer` values (the type
  `Vaton` uses), so `Scale` never overflows. The library never evaluates
  `Radix ** Scale`, so a based exponent such as `2#1#E2147483647` is returned
  without building a power of two.
- Exponents: `Parse_Exact` reads the exponent exactly, decimal or based, up
  to Vaton's 1900-digit budget, so `1e999999999999999999999` has
  `Scale = 999999999999999999999` and `2#1#E2147483648` has
  `Scale = 2147483648`. Beyond 1900 digits it is `Overflow` (at the end of
  input). `Parse` reads a based exponent as a `Natural` (above
  `Natural'Last` it is `Overflow`) and forms `Base ** Exponent` only below
  `10 ** 1900`.
- `Parse_Exact` and `Parse` never raise on any input, provided the process
  can satisfy the allocations of one call (at most 256 KiB, see *Memory
  bound*): a string of millions of characters, or one whose bounds end at
  `Positive'Last`, is scanned in place (see *Budgets*). If the heap is
  already exhausted, `Storage_Error` may propagate (or the process may
  terminate): heap exhaustion is outside this contract and no recovery is
  promised.

```ada
declare
   use Ada.Numerics.Big_Numbers.Big_Integers;
   R : constant Radix_Literals.Exact_Result :=
     Radix_Literals.Parse_Exact ("-1234567890.12345678");
begin
   --  R.Value.Negative = True
   --  R.Value.Significand = 123456789012345678
   --  R.Value.Radix = 10, R.Value.Scale = -8
   null;
end;
```

## Two-layer error model

`Parse` never raises for user-input errors. It returns a discriminated
`Parse_Result` whose `Status` is either `Ok` (with a `Vaton.Number` in
`Value`) or `Error` (with a `Reason : Error_Kind` and a 1-based
`Position : Positive` pointing at the offending character).

There are two conceptual layers of failure:

1. **User syntax** errors -- every `Error_Kind` except `Storage_Exhausted`.
   These correspond to a specific character position in the input, so a
   consumer can render, for example, `invalid digit 'G' for base 16 at
   position 5`.
2. **Internal** errors -- `Storage_Exhausted` is the only non-syntax error
   kind. It appears when `Vaton.Append` reports `Success = False`, which
   means either an internal allocation failure or that the digit array hit
   its capacity ceiling. Callers should treat it as an internal condition,
   not a user mistake.

### `Error_Kind` values

- `None` -- reserved default for uninitialised values (never returned).
- `Empty_Input` -- the input `Image` was the empty string.
- `Invalid_Character` -- a character was not permitted in any literal at
  that position (non-ASCII, or a delimiter where a digit was expected).
- `Invalid_Digit_For_Base` -- a digit whose numeric value is not less than
  the current base (for example `8` in an octal literal, `G` in hex).
- `Bad_Underscore` -- underscore misplaced: leading, trailing, doubled, or
  adjacent to a non-digit delimiter (`sign`, prefix, `#`, `.`, `e`).
- `Base_Out_Of_Range` -- the Ada-style base was outside `2 .. 16`.
- `Empty_Digits` -- a required digit run was empty (`0x`, `16##`,
  `16#FF#E`, `-`).
- `Malformed_Based_Literal` -- missing or extra `#` in a based literal.
- `Unexpected_Exponent` -- currently used on the based path when the
  Ada-style exponent has a disallowed sign (a based-integer exponent must
  be non-negative).
- `Overflow` -- the value exceeds the digit budget: significand or exponent
  digits above 1900 (Vaton's `BIG_NUMBER_DIGIT_LIMIT`), a based value of
  `10 ** 1900` or more, or, with `Parse`, a decimal too large for the exact
  fallback (see *Vaton float range*) or a based exponent above
  `Natural'Last`. Also used by the
  `Radix_Literals.Integers` facade to report values that parsed but do not
  fit the target range, and to report a float value being narrowed to an
  integer target.
- `Storage_Exhausted` -- internal allocation failure reported by
  `Vaton.Append`, not a syntax error.
- Limits never hide syntax errors: the whole literal is validated, then
  `Overflow` is reported (at the end of input). `Parse ("2#1#E2147483648X")`
  and `Parse_Exact` of it are both `Invalid_Character` at 16.

## Documented behaviour decisions

- **Prefixed literals followed by `e`/`E`** are treated as more hex digits,
  not exponents. So `0xFFe2` parses as `0xFFE2` = 65506. Prefixed literals
  have no exponent grammar; consequently no C-style hex-float `p` notation
  is recognised.
- **`_` immediately after a prefix** (`0x_FF`, `16#_F#`) is rejected as
  `Bad_Underscore`. Underscores must be between two digits.
- **Ada based real literals** (`16#F.8#`) are out of scope for v0.1.0 and
  are rejected with `Invalid_Character` at the offending `.`. Decimal
  floats remain supported via vaton.
- **C-style hex-float `p` notation** (`0x1.8p3`) is out of scope; rejected
  as `Invalid_Character`.
- **A `+` or `-` alone** (no digits following) yields `Empty_Digits`, not
  `Invalid_Character`, because the sign was accepted and a digit run was
  expected.
- **Decimal separator.** `Decimal_Point` (default `'.'`) is the fraction
  point on the decimal path, and the only one there; the prefixed and based
  paths never use it. A separator Vaton rejects (`+`, `-`, `_`, `e`, `E`, a
  digit) makes every decimal literal `Invalid_Character` at position 1; so
  do the format delimiters `#`, `x`, `X`, `o`, `O`, `b`, `B`, which would
  make `Parse ("1#5", '#')` ambiguous (`1#5` is a based literal with base 1:
  `Base_Out_Of_Range` at 1, whatever the separator). Prefixed and based
  literals are unaffected by the separator. The dropped zero exponent of
  `7e0` uses the separator too: `Parse ("7e0", ',')` is the float 7.0.
- **Vaton float range.** Vaton builds a decimal in the first float kind
  (`Float`, `Long_Float`, `Long_Long_Float`) whose digit and exponent bounds
  admit it, through `Float_Conversions.Combine`. That raises
  `Constraint_Error` when `10 ** exponent` or the product leaves the kind's
  range; the product must not exceed half of the kind's largest value (a
  subtype bound on an intermediate). `Parse` does not change Vaton. It flags
  every literal that might reach those branches (a conservative guard with a
  2^-18 relative margin, far above Vaton's float error, see
  `Vaton_Float_Overflows`), and every literal whose Vaton Big_Real denominator
  would be beyond the power budget (see `Vaton_Big_Denominator_Too_Large`).
  Flagged literals return the **exact value** as a `Big_Real` (a rational,
  never rounded), when within budget: `8e39` and `3.4e38` (Float) and `1e308`
  (Long_Float) are exact `Big_Real` values. At the top of the
  `Long_Long_Float` range a flagged literal (above about 5.9e4931, half the
  kind's largest value) has too many digits for the budget, so `Parse` returns
  `Overflow` at the end of input: `1e4932` is `Overflow` at 6 (while
  `Parse_Exact` gives `(1, 10, 4932)`).
  **That value is the exact literal value, not Vaton's.** Vaton rounds into a
  float kind; for a flagged literal the old result and the exact value can
  differ. For example `898844e302` used to be a `Long_Float` slightly off
  `898844 * 10 ** 302`; it is now exactly `898844 * 10 ** 302` as a
  `Big_Real`. Only flagged literals change (the margin below each kind's
  limit); see *Measured counts* for how many.
- **Budgets.** Significand digits (whole and fraction) and exponent digits:
  at most 1900 (Vaton's `BIG_NUMBER_DIGIT_LIMIT`, about 2^6313); leading zeros
  count, and so do the digits of a based exponent. The synthetic fraction digit
  added for a dropped zero exponent (`7e0`) is not charged: 1900 nines and
  `e0` is `Ok`. Exact `Big_Real` results: the numerator (`Significand *
  10 ** Scale`, measured on the actual value) and the denominator
  (`10 ** -Scale`) are each at most `10 ** 1936`, about 2^6431.4, below GNAT's
  `Big_Integer` capacity of 2^6432 (`s-genbig.adb`):
  `0.000000000000000001e1954` (exactly `10 ** 1936`) is a `Big_Real`,
  `0.000000000000000002e1954` is `Overflow`. Based values: below
  `10 ** 1900`, the same limit as Vaton's decimal values. Every Big_Integer
  construction is listed with its check in the body (*Big_Integer
  inventory*); the guard is conservative and every check runs before the value
  is built.
  **Exponent limit.** A decimal exponent has at most 1900 digits (leading
  zeros count), but `Parse` hands Vaton an exponent of at most 7 significant
  digits (Vaton requires an `Integer` exponent, and reads a longer one
  wrongly): leading zeros are dropped (`1e0000000007` is `1e7`), and from
  `10 ** 7` on the value is beyond every budget, so the result is `Overflow`
  (`1e99999999` at 10), or an exact zero (`0e99999999`). Leading zeros of the
  whole part are held back too (`007` is the `Integer` 7; it was `Overflow`).
  One residual Vaton grammar defect is left alone: the `e` of a literal with
  both a fraction and an exponent (`7.5e3`) is streamed although Vaton's
  `Is_Possible_Piece` wants an empty fraction there; Vaton 0.1.0 does not
  check it and the values are right.
  **Memory bound.** One call allocates at most 256 KiB (heap and secondary
  stack), for any image: the Vaton digit arrays (one byte per digit, at most
  1900 + 1900 digits, doubling, one copy) under 48 KiB, the big numbers
  (fewer than 64 live, each at most 1.6 KiB) about 100 KiB, the stack 64 KiB.
  No decimal image of a big value is built (GNAT's `To_String` holds a
  quadratic amount of temporary strings), and the digit arrays are freed
  before the call returns on every path (they were not: about 62 bytes leaked
  per decimal call). Peak live heap measured with a `malloc` interposer:
  7.8 KB at most (1900 nines and `e0`), under 8 KB for 5,000,000-character
  images. Beyond the bound (an already exhausted heap) `Storage_Error` may
  propagate: no recovery is promised.
  **No storage proportional to the input.** The image is read in place, with
  `Long_Long_Integer` offsets from `Image'First`; no slice, no narrowed copy
  for the `Wide_String` overloads, and the only buffers are two of 1900
  characters. Digits are counted while scanning and Vaton receives no more
  than the budget, so a 20,000,000-character image of ones is `Overflow` (not
  `Storage_Error`), and an image whose bounds end at `Positive'Last` does not
  raise (`String (Positive'Last .. Positive'Last) := "-"` is `Empty_Digits`
  at 2). Syntax errors still take precedence over the budget: the whole image
  is validated before `Overflow` is reported.
  **Consumer-side limit.** A `Big_Real` returned by `Parse` is exact, and `=`,
  `Numerator` and `Denominator` are safe on it, including at the budget
  boundary. Ordering (`<`, `<=`, `>`, `>=`, `Min`, `Max`) and arithmetic
  (`+`, `-`, `*`, `/`) on **two** such values cross-multiply their numerators
  and denominators, and can exceed GNAT's Big_Integer capacity: they raise
  `Storage_Error`. Verified: with `A := Parse ("1.12345678901234567e-1919")`
  and `B := Parse ("2.12345678901234567e-1919")`, `A < B` raises
  `Storage_Error`. Consumers that need arithmetic or ordering should work from
  `Parse_Exact`'s `(Significand, Scale)` with their own budget.
- **Vaton `NaN` results.** For exponents beyond Vaton's `Big_Real` limit,
  Vaton returns `Ok` with kind `NaN` (for example `1e1000000`). `Parse` never
  returns that: it gives the exact value if it fits the budget, else
  `Overflow`. `Parse_Exact` reads the value exactly.
- **Measured counts.** Differential of `026e1ba` against this tree over a
  corpus of 290,750 lines (239,479 distinct literals with `Decimal_Point =>
  '.'`; the same lines with `.` turned into `,` for `Decimal_Point => ','`):
  the generated corpus, the threshold, Big_Real and budget bands, the
  boundaries of the budgets, zero exponents, 1 to 100,000-digit images and 60,000
  mutations. Each literal went through `Parse` and `Parse_Exact` on
  `String`, `Wide_String` and `Wide_Wide_String`: no raise (`Storage_Error`
  included) and no disagreement between the three string types. Against
  `026e1ba` (`.`): 226,363 literals unchanged; 4,964 `Overflow` (a leading zero, `007`) now `Ok`; 1,405 raised, now an exact
  `Big_Real`; 1,126 raised, now `Overflow`; 4 raised, now `0`; 4,968 were `Ok`
  with `NaN`, now `Overflow`; 107 were `NaN`, now an exact `Big_Real` (zero
  significand, or 1900 digits); 99 were a
  `Long_Long_Float` beyond the budget (for example `594864e4926`), now
  `Overflow`; 24 were a based literal with more than 1900 exponent digits
  (leading zeros), now `Overflow`; 48 based-exponent `Overflow` moved from
  the digit to the end of input; **371 were a `Long_Float` and are now the
  exact `Big_Real`: all 371 differ in value from Vaton's rounded float** (for
  example `898845e302`). Against `bfa1007` (`.`): 234,243 unchanged, 4,968 `Overflow` (leading zeros, and 4 zeros with a long exponent) now
  `Ok`, 24 as above; with `,` the 585 integers
  `7e0`-style (`-9E-0` was `-90`) are now floats, 29 `Overflow` (`0E+0`) are
  now `Ok`. `Parse_Exact` against `bfa1007`: 72 `Overflow` now `Ok` (based
  exponents above `Natural'Last`), 24 `Ok` now `Overflow` (exponent over 1900
  digits), 12 `Overflow` at a new position (the end of input). `Parse` against `Parse_Exact`: same `Reason` and
  `Position` on every syntax error; 6,140 `Overflow` in `Parse` are `Ok` in `Parse_Exact`
  (representation limits). The underlying defect is in
  Vaton; it is not reported upstream from this repository.

## SPARK proof

The public spec (`src/radix_literals.ads`, `src/radix_literals-integers.ads`)
is annotated with `SPARK_Mode => On`. The bodies keep `SPARK_Mode => Off`
for v0.1.0 because the parsing pipeline uses
`Ada.Numerics.Big_Numbers.Big_Integers`, whose body is itself
`SPARK_Mode => Off`; formalising the surrounding parser is more effort than
a first release warrants. A proof harness in
`prove/prove_radix_literals.adb` instantiates the `Radix_Literals.Integers`
generic for a few representative target types (`Interfaces.Integer_16`,
`Integer`, `Long_Long_Integer`).

Reproduce the proof run with (from the Alire environment that provides
`gnatprove`, `vaton` and `spark_unbound`):

```
alr -n exec -- gnatprove -P radix_literals.gpr --level=1 --output=oneline -j0
```

The summary is in `obj/<profile>/gnatprove/gnatprove.out`
(`<profile>` is set by the generated configuration: `release` or
`development`). The command used for both measurements, run from
`/home/heziode/workspaces/aclida-next/libs/common`, was:

```
alr -n exec -- gnatprove -P /home/heziode/.paseo/worktrees/0t1ovu42/rl-exact-rational/radix_literals.gpr --level=1 --output=oneline -j0
```

BEFORE is the pristine 0.1.0 tree (`026e1ba`, profile `release`). AFTER is
the 0.1.1 fix commit that contains this section (its `src/` and `tests/` are
the measured sources; profile `development` in the last run, `release` in an
earlier run on the same sources, with the same table):

| Category (SPARK Analysis results) | Total | Flow | Provers | Justified | Unproved (before / after) |
|---|---:|---:|---:|---:|---:|
| Data Dependencies | 4 | 4 | . | . | . / . |
| Flow Dependencies | . | . | . | . | . / . |
| Initialization | 23 | 20 | . | . | 3 / 3 |
| Non-Aliasing | . | . | . | . | . / . |
| Run-time Checks | 394 | . | 334 | . | 60 / 60 |
| Assertions | 57 | . | 48 | . | 9 / 9 |
| Functional Contracts | 139 | . | 122 | . | 17 / 17 |
| Termination | 51 | 41 | 10 | . | . / . |
| **Total** | **668** | **65** | **514** | **.** | **89 / 89** |

The per-check messages are identical before and after (92 lines each,
compared as sorted text). Every unproved check is in the `vaton` dependency
(`vaton-float_conversions.adb`, `vaton.ads`) or in the proof harness
initialization (`prove_radix_literals.adb`). None is in
`src/radix_literals.ads`; the bodies stay `SPARK_Mode => Off`. The 0.1.1 spec
adds no contract or `SPARK_Mode` change, so the public specs gain no checks.

## Testing

Build and run the AUnit suite:

```
cd tests
alr build
./bin/tests
```

The suite exits with a non-zero status if any case fails.

## Scope limits (v0.1.0)

- **Based real literals** (`16#F.8#`, a fraction inside `#...#`) are out of
  scope. Reject a `.` inside a based literal with `Invalid_Character`.
  Decimal floats remain supported via vaton.
- **C hex-float `p` notation** (`0x1.8p3`) is out of scope; rejected.
- No `Float` generic facade yet. `Radix_Literals.Integers` covers signed
  integer targets; a float-target facade is planned for v0.2.0.
- The generic facade requires a signed integer target
  (`type Target is range <>`). Modular types are not covered by v0.1.0.

## License

Apache-2.0. See `LICENSE`.
