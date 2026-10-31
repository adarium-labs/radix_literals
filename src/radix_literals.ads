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
   ---    * ``Unexpected_Exponent`` -- exponent supplied where the format
   ---      forbids one (currently unused; ``e`` on prefixed literals is
   ---      accepted as a hex digit).
   ---    * ``Overflow`` -- value exceeds ``Vaton``'s ``Big_Integer`` digit
   ---      limit and is rejected by ``Vaton.Is_Valid_Number``. A based
   ---      exponent above ``Natural'Last`` is also reported as ``Overflow``.
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
   ---    The character used as the decimal separator on the decimal path.
   ---    Passed through to ``Vaton.Append`` unchanged. Must not be one of
   ---    the reserved characters ``+``, ``-``, ``_``, ``e``, ``E`` or a
   ---    digit.
   ---  @return
   ---    ``Parse_Result`` with ``Status = Ok`` on success (``Value`` set) or
   ---    ``Status = Error`` on failure (``Reason``, ``Position`` set).
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
   ---    ``Significand = 0``. Representation is not normalised: ``7e0`` gives
   ---    ``(Significand => 70, Scale => -1)``, the same as ``7.0``.
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
   ---    Accepts and rejects exactly the same inputs as ``Parse``, with the
   ---    same ``Reason`` and ``Position`` on failure. Unlike ``Parse``, it
   ---    does not build a ``Vaton.Number``: no floating-point value and no
   ---    power of the radix is computed, so an exponent such as
   ---    ``1e999999999999999999999`` is returned as a ``Big_Integer``
   ---    ``Scale``.
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
