--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Integers;
with Vaton;

---  @summary Parse numeric literals written in several bases and syntaxes into
---  a ``Vaton.Number``.
---  @description
---    ``Radix_Literals`` accepts, in a single ``Parse`` entry point, decimal
---    literals (as understood by ``Vaton``), C-style prefixed literals
---    (``0x`` / ``0o`` / ``0b``), and Ada-style based literals
---    (``base#value#[Eexp]``), each with underscore separators and an optional
---    leading sign.
---
---    The library is a thin front-end that owns sign handling and base
---    validation, then delegates every value construction to ``Vaton`` so that
---    smallest-type selection and big-integer handling remain the verified
---    property of that library. ``Parse_Exact`` exposes the exact value of the
---    same literals without constructing one. See ``README.md`` for the full
---    grammar and the proof-reproduction command.
package Radix_Literals with SPARK_Mode is

   ---  @summary Reason attached to an ``Error`` ``Parse_Result``.
   ---  @description
   ---    * ``None`` -- not returned; default for uninitialised values.
   ---    * ``Empty_Input`` -- ``Image`` is the empty string.
   ---    * ``Invalid_Character`` -- character not permitted in any literal.
   ---    * ``Invalid_Digit_For_Base`` -- digit above the current base
   ---      (for example ``'8'`` in an octal literal, ``'G'`` in hex).
   ---    * ``Bad_Underscore`` -- underscore misplaced (leading, trailing,
   ---      doubled, or adjacent to a non-digit delimiter).
   ---    * ``Base_Out_Of_Range`` -- Ada-style base outside ``2 .. 16``.
   ---    * ``Empty_Digits`` -- a required digit run is empty
   ---      (for example ``0x``, ``16##``, ``16#FF#E``).
   ---    * ``Malformed_Based_Literal`` -- missing or extra ``#`` in a
   ---      based literal.
   ---    * ``Unexpected_Exponent`` -- a negative exponent on a based literal
   ---      (``Parse ("2#1#E-2")``, at 6: a based-integer exponent must be
   ---      non-negative). ``e`` on a prefixed literal is accepted as a hex
   ---      digit.
   ---    * ``Overflow`` -- the value exceeds the digit budget: significand
   ---      or exponent digits above 1900 (``Vaton``'s ``Big_Integer`` digit
   ---      limit), a based value of 10 ** 1900 or more, or, with ``Parse``,
   ---      a decimal too large for the exact fallback, or a based exponent
   ---      above ``Natural'Last`` (see ``Parse`` and ``Parse_Exact``).
   ---    * ``Storage_Exhausted`` -- ``Vaton.Append`` reported
   ---      ``Success = False``: an internal allocation failure, not a user
   ---      syntax error.
   type Error_Kind is
     (None,
      Empty_Input,
      Invalid_Character,
      Invalid_Digit_For_Base,
      Bad_Underscore,
      Base_Out_Of_Range,
      Empty_Digits,
      Malformed_Based_Literal,
      Unexpected_Exponent,
      Overflow,
      Storage_Exhausted);

   ---  @summary Discriminant tag on ``Parse_Result``: ``Ok`` carries a value,
   ---  ``Error`` carries a diagnostic.
   type Parse_Status is (Ok, Error);

   ---  @summary Outcome of a ``Parse`` call.
   ---  @description
   ---    On success, ``Value`` holds the ``Vaton.Number`` produced by
   ---    ``Vaton.To_Number`` (already narrowed to the smallest fitting
   ---    standard type). On failure, ``Reason`` names the error kind and
   ---    ``Position`` is a 1-based index into the original ``Image`` pointing
   ---    at the offending character, or at end-of-input for structural errors
   ---    such as a missing terminating ``#``.
   type Parse_Result (Status : Parse_Status := Error) is record
      case Status is
         when Ok =>
            Value : Vaton.Number;
         when Error =>
            Reason   : Error_Kind;
            Position : Positive;
      end case;
   end record;

   ---  @summary Parse an ASCII numeric literal.
   ---  @param Image
   ---    The literal to parse. Only 7-bit ASCII is significant; any character
   ---    outside that range yields ``Invalid_Character`` at its position.
   ---  @param Decimal_Point
   ---    The fraction separator recognised on the decimal path, and the only
   ---    fraction character there: with ``','`` the literal ``1,5`` is 1.5 and
   ---    ``1.5`` is ``Invalid_Character`` at 2. The prefixed and based paths
   ---    never use it. It must not be ``'+'``, ``'-'``, ``'_'``, ``'e'``,
   ---    ``'E'`` or a digit (Vaton's rule), nor one of the format delimiters
   ---    ``'#'``, ``'x'``, ``'X'``, ``'o'``, ``'O'``, ``'b'``, ``'B'``
   ---    (``Parse ("1#5", '#')`` would otherwise be ambiguous); with one of
   ---    those, decimal literals are ``Invalid_Character`` at 1, while
   ---    prefixed and based literals are unaffected.
   ---  @return
   ---    ``Parse_Result`` with ``Status = Ok`` on success (``Value`` set) or
   ---    ``Status = Error`` on failure (``Reason``, ``Position`` set).
   ---  @description
   ---    A decimal Vaton would build with an overflow (its power
   ---    ``10 ** exponent`` or its product exceeds the range of the float kind
   ---    chosen for it), or whose Big_Real would be a denominator beyond
   ---    budget, is returned as its exact value in a ``Big_Real``
   ---    (``Vaton.Number`` kind ``Big_Real``): a rational, never rounded.
   ---    This covers ``8e39`` and ``3.4e38`` (``Float`` range) and ``1e308``
   ---    (``Long_Float``): their exact values are returned. At the top of the
   ---    ``Long_Long_Float`` range a flagged literal (above about 5.9e4931,
   ---    half the kind's largest value) has too many digits for the budget:
   ---    ``1e4932`` is ``Overflow`` (``Position = 6``), while
   ---    ``Parse_Exact`` returns it exactly.
   ---
   ---    That value is the exact literal value. Vaton would have rounded it
   ---    into a float: ``898844e302`` is now exactly ``898844 * 10 ** 302``,
   ---    not the nearby ``Long_Float``. Only literals the conservative guard
   ---    flags change (a 2**-18 margin below each kind's limit), and a
   ---    flagged literal could raise before.
   ---
   ---    The budget (see the body, *Big_Integer inventory*): significand
   ---    digits (whole and fraction) and exponent digits at most 1900 (the
   ---    digit limit of ``Vaton``, about 2**6313); the numerator and the
   ---    denominator of a ``Big_Real`` at most ``10 ** 1936`` each (about
   ---    2**6431.4, below GNAT's Big_Integer capacity of 2**6432):
   ---    ``0.000000000000000001e1954`` (exactly ``10 ** 1936``) is a
   ---    ``Big_Real``, ``0.000000000000000002e1954`` is ``Overflow``.
   ---    Beyond it, the result is ``Overflow`` at the end of input
   ---    (``Position = Image'Length``). A decimal whose ``Vaton`` result is
   ---    ``NaN`` takes the same route: the exact value within budget, else
   ---    ``Overflow``, never ``Ok`` with a ``NaN`` value.
   ---
   ---    Limits never hide a syntax error: ``Parse ("2#1#E2147483648X")`` is
   ---    ``Invalid_Character`` at 16, as in ``Parse_Exact``.
   ---
   ---    A decimal exponent has at most 1900 digits (leading zeros count), and
   ---    ``Parse`` gives Vaton an exponent of at most 7 significant digits
   ---    (Vaton requires an ``Integer`` exponent): from 10 ** 7 on, the value
   ---    is beyond every budget, so the result is ``Overflow``, or an exact
   ---    zero when the significand is zero (``0e99999999``).
   ---
   ---    A based exponent has at most 1900 digits (leading zeros count) and is
   ---    a ``Natural``: above ``Natural'Last`` the result is ``Overflow``
   ---    (``Parse_Exact`` keeps it).
   ---
   ---    A dropped zero exponent keeps the value a real: ``7e0`` is the
   ---    float 7.0 (with ``Decimal_Point => ','`` too). The digit this adds
   ---    internally is not charged to the budget; a numeral of 1900 digits,
   ---    which cannot take it, is returned as the exact ``Big_Real``.
   ---
   ---    No Big_Integer is built from digits or exponents above the budget,
   ---    and no storage grows with the length of ``Image`` beyond that
   ---    budget, so ``Parse`` never raises for any input, including images
   ---    of millions of characters and images ending at ``Positive'Last``,
   ---    provided the process can satisfy the allocations of one call.
   ---
   ---    Memory: one call allocates at most 256 KiB (262,144 bytes) of heap
   ---    and secondary stack, whatever the length of ``Image`` (derived in the
   ---    body, *Memory bound*: the Vaton digit arrays 48 KiB, the big numbers
   ---    100 KiB, the stack 64 KiB; the measured peak is 7.8 KB). The digit
   ---    arrays are freed before the call returns, on every path. If the
   ---    heap is already exhausted,
   ---    ``Storage_Error`` may propagate, or the process may terminate: heap
   ---    exhaustion is outside this contract and no recovery is promised.
   ---
   ---    Consumer-side limit: a returned ``Big_Real`` is exact, and ``=``,
   ---    ``Numerator`` and ``Denominator`` are safe on it.  Ordering and
   ---    arithmetic on two such values cross-multiply their numerators and
   ---    denominators and can raise ``Storage_Error`` (for example
   ---    ``1.12345678901234567e-1919 < 2.12345678901234567e-1919``).  Such
   ---    consumers should use ``Parse_Exact``'s ``(Significand, Scale)``.
   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Parse_Result;

   ---  @summary ``Wide_String`` overload of ``Parse``.
   ---  @description
   ---    Non-ASCII characters are rejected as ``Invalid_Character``; the
   ---    overload exists for callers whose input is already in
   ---    ``Wide_String`` form.
   function Parse
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result;

   ---  @summary ``Wide_Wide_String`` overload of ``Parse``.
   ---  @description
   ---    Same semantics as the ``String`` overload; non-ASCII characters are
   ---    rejected as ``Invalid_Character``.
   function Parse
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result;

   ---  @summary Radix of an ``Exact_Value``: 10 for decimal literals, the
   ---  literal's base for ``0x`` / ``0o`` / ``0b`` and Ada based literals.
   subtype Radix_Range is Positive range 2 .. 16;

   ---  @summary Exact value of a literal accepted by ``Parse``.
   ---  @description
   ---    The literal denotes::
   ---
   ---      (-1 if Negative else 1) * Significand * Radix ** Scale
   ---
   ---    ``Significand`` is non-negative. ``Scale`` is the exact power
   ---    (fraction digits and exponent folded together) and may be negative.
   ---    Both are unbounded ``Big_Integer`` values: ``Scale`` is never
   ---    narrowed to a machine integer, and the value is never evaluated, so
   ---    ``Radix ** Scale`` is not formed by the library.
   ---
   ---    ``Negative`` is kept for zero: ``-0.0`` is ``Negative`` with
   ---    ``Significand = 0``. A zero exponent is no exponent: ``7e0`` gives
   ---    ``(Significand => 7, Scale => 0)``; ``7.0`` gives ``(70, -1)``.
   type Exact_Value is record
      Negative    : Boolean;
      Significand : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer;
      Radix       : Radix_Range;
      Scale       : Ada.Numerics.Big_Numbers.Big_Integers.Big_Integer;
   end record;

   ---  @summary Outcome of a ``Parse_Exact`` call. Same discriminant and
   ---  error reporting (``Reason``, ``Position``) as ``Parse_Result``.
   type Exact_Result (Status : Parse_Status := Error) is record
      case Status is
         when Ok =>
            Value : Exact_Value;
         when Error =>
            Reason   : Error_Kind;
            Position : Positive;
      end case;
   end record;

   ---  @summary Exact value of an ASCII numeric literal.
   ---  @description
   ---    Syntax: it accepts and rejects exactly the literals ``Parse``
   ---    does, and reports the same ``Reason`` and ``Position`` for every
   ---    syntax error (including ``16#F.8#``, which neither accepts).
   ---
   ---    Representation limits: ``Parse`` is limited by what ``Vaton`` can
   ---    build; ``Parse_Exact`` forms no power of the radix and is limited
   ---    only by the digit budget. So some literals ``Parse`` rejects with
   ---    ``Overflow`` are ``Ok`` here, with the exact ``(Significand,
   ---    Scale)``:
   ---
   ---      * ``1e4932``: ``Parse`` is ``Overflow`` (beyond the ``Big_Real``
   ---        budget), here ``(1, 10, 4932)``;
   ---      * ``1e999999999999999999999``: ``Parse`` is ``Overflow``, here
   ---        ``Scale = 999999999999999999999``;
   ---      * ``2#1#E2147483648`` (a based exponent above ``Natural'Last``,
   ---        also ``2#1#E6432`` whose value is above the digit budget):
   ---        ``Scale`` is the exponent text read exactly.
   ---
   ---    The exponent (decimal or based) is read exactly into ``Scale``, up
   ---    to 1900 digits; beyond that, ``Overflow``. A limit is only reported
   ---    once the whole literal is known to be valid: a syntax error always
   ---    wins, in both functions, and ``Overflow`` is at the end of input.
   ---    The significand (whole
   ---    and fraction digits, or a based digit run) is limited to
   ---    ``10 ** 1900``; beyond that, ``Overflow``. ``Parse_Exact`` never
   ---    forms a power of the radix; ``Parse`` forms one only within the
   ---    budget above. Like ``Parse``, it never raises, whatever the length
   ---    or the bounds of ``Image``.
   ---    @param Image
   ---      See ``Parse``.
   ---    @param Decimal_Point
   ---      See ``Parse``.
   function Parse_Exact
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Exact_Result;

   ---  @summary ``Wide_String`` overload of ``Parse_Exact``; same semantics
   ---  as the ``Wide_String`` overload of ``Parse``.
   function Parse_Exact
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result;

   ---  @summary ``Wide_Wide_String`` overload of ``Parse_Exact``; same
   ---  semantics as the ``Wide_Wide_String`` overload of ``Parse``.
   function Parse_Exact
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result;

end Radix_Literals;
