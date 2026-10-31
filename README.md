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

- `Parse_Exact` accepts and rejects exactly the literals `Parse` does, with
  the same `Reason` and `Position` on failure.
- Decimals: `Significand` is all digits, whole part then fraction;
  `Scale` is the exponent minus the number of fraction digits.
  `1.25e3` is `(125, Radix 10, Scale 1)`.
- `0x` / `0o` / `0b` and Ada based literals: `Radix` is the base and `Scale`
  is the Ada exponent (0 for prefixed literals). `16#FF#E2` is
  `(255, Radix 16, Scale 2)`.
- `Negative` is kept for zero: `-0.0` is `Negative` with `Significand = 0`.
- The representation is not normalised: `7e0` is `(70, Scale -1)`, the same
  as `7.0`.
- `Significand` and `Scale` are unbounded `Big_Integer` values (the type
  `Vaton` uses), so `Scale` never overflows. The library never evaluates
  `Radix ** Scale`, so a based exponent such as `2#1#E2147483647` is returned
  without building a power of two.
- Vaton's decimal exponent limit still applies: `1e999999999` is `Overflow`
  from both `Parse` and `Parse_Exact`.

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
- `Overflow` -- value exceeds vaton's `Big_Integer` digit limit
  (`Vaton.BIG_NUMBER_DIGIT_LIMIT` = 1900) and is rejected by
  `Vaton.Is_Valid_Number`. Also used by the `Radix_Literals.Integers`
  facade to report values that parsed but do not fit the target range,
  and to report a float value being narrowed to an integer target.
- `Storage_Exhausted` -- internal allocation failure, not a syntax error.

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

Reproduce the current gnatprove run with:

```
alr gnatprove --level=1 --output=oneline
```

Version 0.1.1 adds `Parse_Exact` and its types to the public specs. Its
proof summary is not measured in that release: gnatprove was not installed
where 0.1.1 was built. Run the command above to measure it.

Expected outcome at the time of writing (0.1.0):

- All checks on the public specs are proved.
- 3 initialization checks on the prove harness remain "medium" because
  gnatprove cannot see through the `SPARK_Mode => Off` bodies of the
  `Signed_Conversions` instantiations that the generic facade uses. Those
  are declared and used only inside the library body, so they never leak
  into consumer code.
- The remaining `medium` messages (about 86) come from the vaton
  dependency and its use of `Big_Real` / `Big_Integer` conversions.
  Nothing in `Radix_Literals` itself is flagged.

The full breakdown (with the exact counts for the current release) is in
`obj/<profile>/gnatprove/gnatprove.out` after running the command above,
where `<profile>` is `development` or `release` depending on the active
Alire profile.

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
