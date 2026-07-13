--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

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
---    property of that library. See ``README.md`` for the full grammar and the
---    proof-reproduction command.
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
   ---      limit and is rejected by ``Vaton.Is_Valid_Number``.
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

end Radix_Literals;
