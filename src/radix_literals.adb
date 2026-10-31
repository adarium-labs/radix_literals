--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Reals;

package body Radix_Literals with SPARK_Mode => Off is

   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   package BR renames Ada.Numerics.Big_Numbers.Big_Reals;
   use type BI.Big_Integer;
   use type BR.Valid_Big_Real;
   use type Vaton.Number_Kind;

   subtype Base_Range is Positive range 2 .. 16;

   --  Positions inside an Image are counted from 1, relative to
   --  Image'First, in Long_Long_Integer: no index arithmetic can leave the
   --  range, even for a string that ends at Positive'Last.  The string is
   --  only ever indexed by Image'First + (N - 1) with 1 <= N <= Image'Length.
   subtype Idx is Long_Long_Integer;

   type Format_Kind is (Format_Empty, Format_Decimal, Format_Prefixed,
                        Format_Based);

   type Detected_Format (Kind : Format_Kind := Format_Empty) is record
      case Kind is
         when Format_Empty =>
            null;
         when Format_Decimal =>
            null;
         when Format_Prefixed =>
            Prefix_Base : Base_Range;
         when Format_Based =>
            null;
      end case;
   end record;

   --  Outcome of a scanner. Failed = False means the literal is valid
   --  according to its grammar; the scanned facts are returned separately.
   type Scan_Result (Failed : Boolean := True) is record
      case Failed is
         when True =>
            Reason   : Error_Kind;
            Position : Positive;
         when False =>
            null;
      end case;
   end record;

   --  Position is clamped into Positive (a position one past the end of a
   --  Positive'Last-long image has no Positive value).
   function Clamp (N : Idx) return Positive is
     (Positive (Idx'Min (Idx'Max (N, 1), Idx (Positive'Last))));

   function Failed_At (Reason : Error_Kind; Position : Idx)
     return Scan_Result is
     ((Failed => True, Reason => Reason, Position => Clamp (Position)));

   -----------------------------------------------------------------------
   --  Character helpers
   -----------------------------------------------------------------------

   function Is_Ascii_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Is_Hex_Letter (C : Character) return Boolean is
     (C in 'a' .. 'f' or else C in 'A' .. 'F');

   function Is_Ascii_Letter (C : Character) return Boolean is
     (C in 'a' .. 'z' or else C in 'A' .. 'Z');

   function Digit_Value (C : Character) return Natural is
     (case C is
        when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
        when 'a' .. 'f' => 10 + Character'Pos (C) - Character'Pos ('a'),
        when 'A' .. 'F' => 10 + Character'Pos (C) - Character'Pos ('A'),
        when others     => 0);

   function Is_Digit_For_Base (C : Character; Base : Base_Range)
     return Boolean is
     ((Is_Ascii_Digit (C) or else Is_Hex_Letter (C))
      and then Digit_Value (C) < Base);

   function Widen (C : Character) return Wide_Character is
     (Wide_Character'Val (Character'Pos (C)));

   --  Characters that delimit a prefixed or based literal; as a decimal
   --  point they would make the format ambiguous, so they are refused (like
   --  '+', '-', '_', 'e', 'E' and the digits, which Vaton refuses).
   function Is_Format_Delimiter (W : Wide_Character) return Boolean is
     (W in '#' | 'x' | 'X' | 'o' | 'O' | 'b' | 'B');

   -----------------------------------------------------------------------
   --  Decimal scanner states (see Scan_Decimal in Engine).
   -----------------------------------------------------------------------

   type Decimal_State is
     (Whole_Start, Whole_Digit, Whole_Us,
      Frac_Start, Frac_Digit, Frac_Us,
      Exp_Sign, Exp_Start, Exp_Digit, Exp_Us);

   -----------------------------------------------------------------------
   --  Vaton float guard (conservative).
   --
   --  Vaton.To_Number builds a decimal in the first float kind whose digit
   --  and exponent bounds admit it (Float, Long_Float, Long_Long_Float), by
   --  Vaton.Float_Conversions.Combine, which raises Constraint_Error when:
   --    * BASED_10 ** Exponent leaves the kind's range (Exponent above the
   --      decimal order of the kind's largest value: 38, 308, 4932), or
   --    * the product S * 10 ** Exponent, assigned to Combined (subtype
   --      0 .. Last / 2), exceeds Last / 2.
   --  Vaton_Float_Overflows flags every literal that MIGHT do either.  It
   --  compares the exact value with Limit = (1 - 2**-18) * Last / 2 (exact
   --  integer), and flags on the power test without margin.
   --
   --  Why this suffices (the argument behind "Parse never raises"):
   --    Vaton computes the product with relative error below 2**-20: the
   --    least precise kind (Float, 2**-24 per operation, about ten operations
   --    in the fraction, power and product) stays under that.  If Vaton's
   --    computed product exceeds Last / 2, the exact value exceeds
   --    Last / 2 * (1 - 2**-20), which is above Limit (1 - 2**-18).  So a
   --    literal is not
   --    flagged only when Vaton's product stays below Last / 2, and Vaton
   --    then cannot raise.  The power test is exact: 10 ** E for E at most
   --    the decimal order of Last is representable.
   --  The cost of conservatism is a change of representation and of value:
   --  a literal in (Limit, Last / 2] is returned as its exact value in a
   --  Big_Real, where Vaton would have built a float kind holding that value
   --  rounded (a Long_Float value, for example, is not always the exact
   --  decimal).  The exact value is the more correct one; see Parse.
   -----------------------------------------------------------------------

   type Kind_Bound is record
      Max_Decimal_Exponent : Integer;  --  floor (log10 (Kind'Last))
      Limit_Digits         : Positive; --  decimal digits of Limit
      Limit_Prefix         : String (1 .. 17); --  leading digits of Limit
   end record;

   --  Limit = floor ((1 - 2**-18) * Kind'Last / 2), an exact integer; the
   --  digit count and the 17 leading digits describe it exactly.
   Float_Bound : constant Kind_Bound :=
     (Max_Decimal_Exponent => 38, Limit_Digits => 39,
      Limit_Prefix => "17014052428219579");
   Long_Float_Bound : constant Kind_Bound :=
     (Max_Decimal_Exponent => 308, Limit_Digits => 308,
      Limit_Prefix => "89884313860361485");
   Long_Long_Float_Bound : constant Kind_Bound :=
     (Max_Decimal_Exponent => 4932, Limit_Digits => 4932,
      Limit_Prefix => "59486347844587479");

   --  Significant digits of Whole & Fraction, leading zeros dropped.
   function Significant_Digits (P : Vaton.Number_Pieces) return String is
      Buf  : String (1 .. 32);
      Last : Natural := 0;

      procedure Add (Pieces : Vaton.Digit_Array.Unbound_Array) is
         First : constant Positive := Vaton.Digit_Array.First_Index (Pieces);
      begin
         for K in 0 .. Vaton.Digit_Array.Length (Pieces) - 1 loop
            declare
               D : constant Integer :=
                 Integer (Vaton.Digit_Array.Element (Pieces, First + K));
            begin
               if Last > 0 or else D /= 0 then
                  Last := Last + 1;
                  Buf (Last) := Character'Val (Character'Pos ('0') + D);
               end if;
            end;
         end loop;
      end Add;
   begin
      Add (P.Whole);
      Add (P.Fraction);
      return Buf (1 .. Last);
   end Significant_Digits;

   --  True when Sig * 10 ** K > Half, Sig having no leading zero and at
   --  most 17 digits.
   function Above_Limit
     (Sig : String; K : Integer; B : Kind_Bound) return Boolean
   is
      --  Digit count of Sig * 10 ** K.
      Digits_Of_Product : constant Integer := Sig'Length + K;
   begin
      if Digits_Of_Product /= B.Limit_Digits then
         return Digits_Of_Product > B.Limit_Digits;
      end if;
      return Sig > B.Limit_Prefix (1 .. Sig'Length);
   end Above_Limit;

   --  Whether Combine raises for the significand of P, with fraction
   --  digit count F and exponent E, in the kind described by B.
   function Combine_Raises
     (P : Vaton.Number_Pieces; E : Integer; F : Integer; B : Kind_Bound)
      return Boolean
   is
   begin
      if E <= 0 then
         return False;     --  division by a power only: no overflow
      elsif E > B.Max_Decimal_Exponent then
         return True;      --  BASED_10 ** E is not representable
      end if;

      declare
         Sig : constant String := Significant_Digits (P);
      begin
         return Sig'Length > 0 and then Above_Limit (Sig, E - F, B);
      end;
   end Combine_Raises;

   --  True when Vaton.To_Number would raise Constraint_Error for P.  Mirrors
   --  the branch conditions of Vaton.To_Number, including its use of an
   --  exponent value of 0 when the exponent digits do not form an Integer.
   --  Digit budget (Vaton's own BIG_NUMBER_DIGIT_LIMIT): significand digits
   --  (whole and fraction) and exponent digits.  A value of this many digits
   --  is below 10 ** 1900, about 2**6313.
   Digit_Budget : constant Positive := Vaton.BIG_NUMBER_DIGIT_LIMIT;
   Budget_Idx   : constant Idx := Idx (Digit_Budget);

   --  Power budget: 10 ** K is formed only for K <= Power_Budget.  10 ** 1936
   --  is about 2**6431.4, below GNAT's Big_Integer capacity (values below
   --  2**6432, s-genbig.adb).  Every power formed for a Big_Real is a factor
   --  of its numerator or denominator, which bounds the Big_Integers built
   --  for it.
   Power_Budget : constant Positive := 1936;

   --  Big_Integer inventory.  Every construction that depends on input, and
   --  the check that bounds it before it happens.  Together they make
   --  "Parse and Parse_Exact never raise" hold: no Big_Integer above
   --  2**6432 (GNAT's capacity, s-genbig.adb) is ever formed.
   --    1. Exponent_Value (Scan_Decimal, and Scan_Based for Parse_Exact): it
   --       receives at most Digit_Budget digits.  The scanners count the
   --       exponent digits as they read them and keep only the first
   --       Digit_Budget in a buffer of that size; above Digit_Budget the
   --       literal is Overflow, nothing is built.
   --    2. Append_Digits (Decimal_Exact, Parse_Exact and the fallback): the
   --       significand digits (whole and fraction) are counted while
   --       scanning; above Digit_Budget the scanner streams nothing more to
   --       Vaton and the literal is Overflow at end of input.  The exponent
   --       is the value of (1).
   --    3. Exact_Big_Real (fallback): the numerator Significand * 10 ** Scale
   --       only when it is at most 10 ** Power_Budget (digits of Significand
   --       plus Scale at most Power_Budget, or one more and Significand a
   --       power of ten); the denominator 10 ** (-Scale) only when -Scale <=
   --       Power_Budget.  Loops are bounded by those tests.  Otherwise
   --       Overflow.
   --    4. Big_Accumulate (Parse's based big path and Parse_Exact's
   --       significand): each step is tested against Digit_Budget (values
   --       below 10 ** Digit_Budget) before it multiplies; the
   --       Base ** Exponent factor loop likewise.  Otherwise Overflow.
   --    5. Big_To_Number: the value is below 10 ** Digit_Budget (item 4).
   --    6. Vaton.To_Number, called only when Vaton_Float_Overflows and
   --       Vaton_Big_Denominator_Too_Large are both false, and the result
   --       is not NaN.  Vaton's integer work: Whole <= Digit_Budget
   --       digits.  Its Big_Real work: the fraction divisor 10 ** F with
   --       F <= Digit_Budget, the denominator 10 ** (F - E) with
   --       F - E <= Power_Budget (guard), the numerator with
   --       E <= Digit_Budget - F - W (Vaton's NaN rule).  Its float kinds
   --       build no integer.
   --    7. Fast_Accumulate and LLI_To_Vaton_Number: Long_Long_Integer only.
   --  Memory bound of one call (heap and secondary stack, in bytes; the
   --  same for any image length):
   --    * Vaton digit arrays: Whole + Fraction <= Digit_Budget digits, one
   --      byte per digit (Parse streams at most 7 exponent digits and
   --      Parse_Exact none, so the exponent array is negligible; the bound
   --      keeps Digit_Budget for it), capacity at most twice the length, a
   --      doubling step holds the old and new arrays, one copy more: under
   --      48 KiB.  They are freed (Vaton.Reset) before the call returns, on
   --      every path.
   --    * Big_Integers: every value is below 2**6432 (about 0.8 KiB), at most
   --      a product of two such values in a GNAT temporary (1.6 KiB), and
   --      fewer than 64 of them are live in any construction of the
   --      inventory: about 100 KiB.  No decimal image of a big value is
   --      built (BI.To_String holds a quadratic amount of temporary strings):
   --      big values are converted directly and the shape of a significand is
   --      read from the Vaton digits.
   --    * Stack: the two exponent buffers of Digit_Budget characters (never
   --      live together) and small frames: 64 KiB.
   --  Total under 212 KiB; the documented bound is 256 KiB.  Measured peak
   --  (live heap with a malloc interposer, glibc; 1900-digit literals of every
   --  band, 5,000,000-character images): 7.8 KB, for "9" * 1900 & "e0"
   --  through Parse.
   --  No other storage depends on the input length: the image is read in
   --  place (no slice, no narrowed copy, whatever its character type), the
   --  only buffers are the two exponent buffers of Digit_Budget characters,
   --  and Vaton receives at most Digit_Budget significand digits.  Positions
   --  are Long_Long_Integer offsets from Image'First, so no index arithmetic
   --  leaves its range for an image ending at Positive'Last.

   --  10 ** K by repeated multiplication; K is always within a budget.
   function Pow10 (K : Natural) return BI.Big_Integer is
      Acc : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      for I in 1 .. K loop
         Acc := Acc * BI.To_Big_Integer (10);
      end loop;
      return Acc;
   end Pow10;

   --  The path Vaton.To_Number takes for P (mirrors its branch conditions).
   type Vaton_Path is
     (Path_Integer, Path_Nan, Path_Float, Path_Long_Float,
      Path_Long_Long_Float, Path_Big);

   --  Exp is the exponent value Vaton uses (zero when its digits do not form
   --  an Integer, as in To_Number); Frac is the fraction digit count.
   procedure Vaton_Plan
     (P : Vaton.Number_Pieces; Path : out Vaton_Path;
      Exp : out Integer; Frac : out Integer)
   is
      Whole : constant Integer := Vaton.Digit_Array.Length (P.Whole);
   begin
      Path := Path_Integer;
      Exp  := 0;
      Frac := Vaton.Digit_Array.Length (P.Fraction);
      if not (P.Has_Exponent or else P.Has_Fraction) then
         return;                 --  integer path: no float, no Big_Real
      end if;
      if Whole = 0 or else Whole > Vaton.BIG_NUMBER_DIGIT_LIMIT - Frac then
         Path := Path_Nan;
         return;
      end if;

      if P.Has_Exponent and then Vaton.Digit_Array.Length (P.Exponent) < 8
      then
         declare
            First : constant Positive :=
              Vaton.Digit_Array.First_Index (P.Exponent);
         begin
            for K in 0 .. Vaton.Digit_Array.Length (P.Exponent) - 1 loop
               Exp := Exp * 10
                      + Integer (Vaton.Digit_Array.Element (P.Exponent,
                                                            First + K));
            end loop;
         end;
         if P.Exponent_Is_Negative then
            Exp := -Exp;
         end if;
      end if;

      if Whole + Frac < Standard.Float'Digits
        and then ((Exp < 0 and then Exp >= Vaton.MIN_FLOAT_EXPONENT)
                  or else (Exp >= 0
                           and then Exp <= Vaton.MAX_FLOAT_EXPONENT
                                           + Standard.Float'Digits
                                           - Frac - Whole))
      then
         Path := Path_Float;
      elsif Whole + Frac < Standard.Long_Float'Digits
        and then ((Exp < 0 and then Exp >= Vaton.MIN_LONG_FLOAT_EXPONENT)
                  or else (Exp >= 0
                           and then Exp <= Vaton.MAX_LONG_FLOAT_EXPONENT
                                           + Standard.Long_Float'Digits
                                           - Frac - Whole))
      then
         Path := Path_Long_Float;
      elsif Whole + Frac < Standard.Long_Long_Float'Digits
        and then ((Exp < 0
                   and then Exp >= Vaton.MIN_LONG_LONG_FLOAT_EXPONENT)
                  or else (Exp >= 0
                           and then Exp <= Vaton.MAX_LONG_LONG_FLOAT_EXPONENT
                                           + Standard.Long_Long_Float'Digits
                                           - Frac - Whole))
      then
         Path := Path_Long_Long_Float;
      elsif Exp < 0 and then Exp + Whole + Frac < -Vaton.BIG_NUMBER_DIGIT_LIMIT
      then
         Path := Path_Nan;       --  Big_Real branch refuses: NaN, no build
      elsif Exp >= 0
        and then Exp > Vaton.BIG_NUMBER_DIGIT_LIMIT - Frac - Whole
      then
         Path := Path_Nan;
      else
         Path := Path_Big;
      end if;
   end Vaton_Plan;

   --  Vaton would raise Constraint_Error in a float branch: the power
   --  overflows (Exp above the decimal order of the kind's largest value) or
   --  the product exceeds half of it.  Conservative, see the comment above.
   function Vaton_Float_Overflows (P : Vaton.Number_Pieces) return Boolean is
      Path      : Vaton_Path;
      Exp, Frac : Integer;
   begin
      Vaton_Plan (P, Path, Exp, Frac);
      case Path is
         when Path_Float =>
            return Combine_Raises (P, Exp, Frac, Float_Bound);
         when Path_Long_Float =>
            return Combine_Raises (P, Exp, Frac, Long_Float_Bound);
         when Path_Long_Long_Float =>
            return Combine_Raises (P, Exp, Frac, Long_Long_Float_Bound);
         when others =>
            return False;
      end case;
   end Vaton_Float_Overflows;

   --  Vaton's Big_Real branch builds 10 ** (Frac - Exp) as the denominator
   --  (Convert_Big_Real).  Beyond Power_Budget that is beyond capacity:
   --  Vaton must not be called, and the value is not representable in the
   --  budget either, so Parse takes the exact fallback (Overflow).
   function Vaton_Big_Denominator_Too_Large (P : Vaton.Number_Pieces)
     return Boolean
   is
      Path      : Vaton_Path;
      Exp, Frac : Integer;
   begin
      Vaton_Plan (P, Path, Exp, Frac);
      return Path = Path_Big and then Exp < 0
        and then Frac - Exp > Power_Budget;
   end Vaton_Big_Denominator_Too_Large;

   --  Exact value of an exponent given as its digits (at most Digit_Budget
   --  of them: the caller checks) and sign.
   function Exponent_Value
     (Digits_Text : String; Negative : Boolean) return BI.Big_Integer
   is
      Acc : BI.Big_Integer := BI.To_Big_Integer (0);
   begin
      for I in Digits_Text'Range loop
         Acc := Acc * BI.To_Big_Integer (10)
                + BI.To_Big_Integer (Digit_Value (Digits_Text (I)));
      end loop;
      return (if Negative then -Acc else Acc);
   end Exponent_Value;

   package LLI_Conversions is new BI.Signed_Conversions (Long_Long_Integer);

   function Fast_To_Big (V : Long_Long_Integer) return BI.Big_Integer
     renames LLI_Conversions.To_Big_Integer;

   -----------------------------------------------------------------------
   --  Number construction: from a Long_Long_Integer, pick the smallest
   --  standard type that fits, then wrap into Vaton.Number directly.
   -----------------------------------------------------------------------

   function LLI_To_Vaton_Number (V : Long_Long_Integer) return Vaton.Number is
      --  Where Long_Integer is as wide as Long_Long_Integer (x86_64 Linux)
      --  the second range test is statically true; GNAT reports that as
      --  dead code.  The test is kept so the kind choice stays the same on
      --  targets where the widths differ.
      pragma Warnings (Off, "range test optimized away");
      pragma Warnings (Off, "value is known to be in range");
   begin
      if V in Long_Long_Integer (Integer'First) ..
              Long_Long_Integer (Integer'Last)
      then
         return (Kind => Vaton.Integer, Integer => Integer (V));
      elsif V in Long_Long_Integer (Long_Integer'First) ..
                 Long_Long_Integer (Long_Integer'Last)
      then
         return (Kind => Vaton.Long_Integer, Long_Integer => Long_Integer (V));
      else
         return (Kind => Vaton.Long_Long_Integer, Long_Long_Integer => V);
      end if;
   end LLI_To_Vaton_Number;

   -----------------------------------------------------------------------
   --  A non-negative Big_Integer below 10 ** Digit_Budget with its sign, as
   --  the Vaton.Number Vaton.To_Integer builds from its decimal digits: the
   --  kind depends on the number of digits (Vaton.BASE_10_LENGTH_TO_BIT_SIZE
   --  bits for each), Big_Integer beyond.  No decimal image is built.
   -----------------------------------------------------------------------

   function Big_To_Number
     (Big : BI.Big_Integer; Is_Negative : Boolean) return Vaton.Number
   is
      Signed : constant BI.Big_Integer := (if Is_Negative then -Big else Big);
   begin
      if Big <= Fast_To_Big (Long_Long_Integer'Last) then
         declare
            Value  : constant Long_Long_Integer :=
              LLI_Conversions.From_Big_Integer (Signed);
            Magn   : Long_Long_Integer := abs Value;
            Digits_In : Natural := 1;
         begin
            while Magn >= 10 loop
               Magn := Magn / 10;
               Digits_In := Digits_In + 1;
            end loop;
            if Digits_In * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                 < Standard.Integer'Size
            then
               return (Kind => Vaton.Integer, Integer => Integer (Value));
            elsif Digits_In * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                    < Standard.Long_Integer'Size
            then
               return (Kind => Vaton.Long_Integer,
                       Long_Integer => Long_Integer (Value));
            elsif Digits_In * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                    < Standard.Long_Long_Integer'Size
            then
               return (Kind => Vaton.Long_Long_Integer,
                       Long_Long_Integer => Value);
            end if;
         end;
      end if;
      return (Kind => Vaton.Big_Integer, Big_Integer => Signed);
   end Big_To_Number;

   --  Significant digits of Whole & Fraction (leading zeros dropped): their
   --  count, and whether they are 1 followed by zeros only.
   procedure Significand_Shape
     (P      : Vaton.Number_Pieces;
      Length : out Natural;
      Is_P10 : out Boolean)
   is
      Seen : Boolean := False;

      procedure Add (Pieces : Vaton.Digit_Array.Unbound_Array) is
         First : constant Positive := Vaton.Digit_Array.First_Index (Pieces);
      begin
         for K in 0 .. Vaton.Digit_Array.Length (Pieces) - 1 loop
            declare
               D : constant Integer :=
                 Integer (Vaton.Digit_Array.Element (Pieces, First + K));
            begin
               if Seen or else D /= 0 then
                  if not Seen then
                     Is_P10 := D = 1;
                  elsif D /= 0 then
                     Is_P10 := False;
                  end if;
                  Seen := True;
                  Length := Length + 1;
               end if;
            end;
         end loop;
      end Add;
   begin
      Length := 0;
      Is_P10 := False;
      Add (P.Whole);
      Add (P.Fraction);
   end Significand_Shape;

   --  Acc := Acc * Radix + each digit of Pieces, in order.
   procedure Append_Digits
     (Acc    : in out BI.Big_Integer;
      Radix  : BI.Big_Integer;
      Pieces : Vaton.Digit_Array.Unbound_Array)
   is
      Len : constant Natural := Vaton.Digit_Array.Length (Pieces);
      First : constant Positive := Vaton.Digit_Array.First_Index (Pieces);
   begin
      for K in 0 .. Len - 1 loop
         Acc := Acc * Radix
                + BI.To_Big_Integer
                    (Integer (Vaton.Digit_Array.Element (Pieces, First + K)));
      end loop;
   end Append_Digits;

   function Decimal_Exact
     (P           : Vaton.Number_Pieces;
      Is_Negative : Boolean;
      Exponent    : BI.Big_Integer) return Exact_Value
   is
      Ten         : constant BI.Big_Integer := BI.To_Big_Integer (10);
      Significand : BI.Big_Integer := BI.To_Big_Integer (0);
      Scale       : BI.Big_Integer := Exponent;
   begin
      Append_Digits (Significand, Ten, P.Whole);
      Append_Digits (Significand, Ten, P.Fraction);
      Scale := Scale
               - BI.To_Big_Integer
                   (Vaton.Digit_Array.Length (P.Fraction));

      return (Negative    => Is_Negative,
              Significand => Significand,
              Radix       => 10,
              Scale       => Scale);
   end Decimal_Exact;

   --  The exact value Significand * 10 ** Scale as a Big_Real (a rational:
   --  exact, never rounded), or False when numerator or denominator would
   --  exceed the budget: the numerator is at most 10 ** Power_Budget (so
   --  Significand * 10 ** Scale, measured on the actual value), the
   --  denominator 10 ** (-Scale) is at most 10 ** Power_Budget, the
   --  significand at most Digit_Budget digits.  Powers of ten are formed only
   --  within that budget, so their size is bounded by a constant.
   function Exact_Big_Real
     (X          : Exact_Value;
      Sig_Len    : Natural;   --  digits of X.Significand
      Sig_Is_P10 : Boolean;   --  X.Significand is 1 followed by zeros
      Result     : out Vaton.Number) return Boolean
   is
      Ten     : constant BI.Big_Integer := BI.To_Big_Integer (10);
      Budget  : constant BI.Big_Integer := BI.To_Big_Integer (Power_Budget);
      One     : constant BI.Big_Integer := BI.To_Big_Integer (1);
      Num     : BI.Big_Integer := X.Significand;
      Den     : BI.Big_Integer := One;
      Count   : BI.Big_Integer := BI.To_Big_Integer (0);
   begin
      if X.Significand = BI.To_Big_Integer (0) then
         Result := (Kind => Vaton.Big_Real, Big_Real => BR.To_Real (0));
         return True;
      end if;
      if Sig_Len > Digit_Budget then
         return False;
      end if;

      if X.Scale >= BI.To_Big_Integer (0) then
         --  Digits of the numerator: Sig_Len + Scale.  At most Power_Budget
         --  + 1 of them, and in the last case only 10 ** Power_Budget itself.
         declare
            Digits_Of_Num : constant BI.Big_Integer :=
              BI.To_Big_Integer (Sig_Len) + X.Scale;
         begin
            if Digits_Of_Num > Budget + One
              or else (Digits_Of_Num = Budget + One
                       and then not Sig_Is_P10)
            then
               return False;
            end if;
         end;
         while Count < X.Scale loop
            Num := Num * Ten;
            Count := Count + One;
         end loop;
      else
         --  The denominator 10 ** (-Scale) is formed only within the budget.
         if -X.Scale > Budget then
            return False;
         end if;
         while Count < -X.Scale loop
            Den := Den * Ten;
            Count := Count + One;
         end loop;
      end if;

      if X.Negative then
         Num := -Num;
      end if;
      Result := (Kind => Vaton.Big_Real,
                 Big_Real => BR.To_Big_Real (Num) / BR.To_Big_Real (Den));
      return True;
   end Exact_Big_Real;

   type Scanned_Literal is record
      Kind         : Format_Kind := Format_Empty;
      Is_Negative  : Boolean := False;
      Base         : Base_Range := 2;
      Digits_First : Idx := 1;
      Digits_Last  : Idx := 0;
      --  Based literal in Parse: the Ada exponent as a Natural.
      Exponent     : Natural := 0;
      --  Decimal literal with a dropped zero exponent too long to take
      --  vaton's synthetic fraction digit: Parse returns an exact Big_Real.
      Force_Real   : Boolean := False;
      --  Decimal literal, and based literal in Parse_Exact: the exponent as
      --  an exact value (zero when absent).
      Dec_Exponent : BI.Big_Integer := BI.To_Big_Integer (0);
   end record;

   --  A decimal Vaton cannot build (see Vaton_Float_Overflows, or a NaN
   --  result for an exponent beyond its Big_Real limit) is returned as the
   --  exact value when it fits the budget, otherwise Overflow.
   function Decimal_Fallback
     (P       : Vaton.Number_Pieces;
      Lit     : Scanned_Literal;
      End_Pos : Positive) return Parse_Result
   is
      V      : Vaton.Number;
      Length : Natural;
      Is_P10 : Boolean;
   begin
      Significand_Shape (P, Length, Is_P10);
      if Exact_Big_Real
           (Decimal_Exact (P, Lit.Is_Negative, Lit.Dec_Exponent),
            Length, Is_P10, V)
      then
         return (Status => Ok, Value => V);
      end if;
      return (Status => Error, Reason => Overflow, Position => End_Pos);
   end Decimal_Fallback;

   -----------------------------------------------------------------------
   --  Engine: the scanners and the two entry points, once for String,
   --  Wide_String and Wide_Wide_String.  The image is read in place (never
   --  copied or narrowed into a temporary), and every buffer is sized by a
   --  budget, not by the input.
   -----------------------------------------------------------------------

   generic
      type Item is private;
      type Text is array (Positive range <>) of Item;
      with function Narrow (X : Item) return Character;
   package Engine is
      function Parse_Text
        (Image : Text; Decimal_Point : Wide_Character) return Parse_Result;
      function Parse_Exact_Text
        (Image : Text; Decimal_Point : Wide_Character) return Exact_Result;
   end Engine;

   package body Engine is

      --  Character at 1-based position N (1 <= N <= Image'Length).
      function C (Image : Text; N : Idx) return Character is
        (Narrow (Image (Image'First + Integer (N - 1))));

      -----------------------------------------------------------------
      --  Format detection on Image (B_First .. Len)
      -----------------------------------------------------------------

      function Detect_Format
        (Image : Text; B_First, Len : Idx) return Detected_Format is
      begin
         if B_First > Len then
            return (Kind => Format_Empty);
         end if;

         if Len - B_First >= 1 and then C (Image, B_First) = '0' then
            case C (Image, B_First + 1) is
               when 'x' | 'X' =>
                  return (Kind => Format_Prefixed, Prefix_Base => 16);
               when 'o' | 'O' =>
                  return (Kind => Format_Prefixed, Prefix_Base => 8);
               when 'b' | 'B' =>
                  return (Kind => Format_Prefixed, Prefix_Base => 2);
               when others =>
                  null;
            end case;
         end if;

         for N in B_First .. Len loop
            if C (Image, N) = '#' then
               return (Kind => Format_Based);
            end if;
         end loop;

         return (Kind => Format_Decimal);
      end Detect_Format;

      -----------------------------------------------------------------
      --  Decimal scanner: validates the decimal grammar and streams the
      --  literal into vaton, with the exponent part held back.
      --
      --  Digits are counted as they are read; once the significand has
      --  more than Digit_Budget digits nothing more is streamed (the
      --  syntax is still checked, so a syntax error keeps precedence) and
      --  the result is Overflow at end of input.  The exponent digits are
      --  kept in a buffer of Digit_Budget characters, further digits are
      --  only counted.
      --
      --  Exact: the exponent is not streamed into vaton; its value is
      --  returned as Exponent.  Not Exact (Parse): it is streamed.
      -----------------------------------------------------------------
      procedure Scan_Decimal
        (Image         : Text;
         B_First, Len  : Idx;
         Is_Negative   : Boolean;
         Decimal_Point : Wide_Character;
         Exact         : Boolean;
         P             : out Vaton.Number_Pieces;
         Exponent      : out BI.Big_Integer;
         Force_Real    : out Boolean;
         Outcome       : out Scan_Result)
      is
         Append_Ok : Boolean;
         State     : Decimal_State := Whole_Start;

         Whole_Count : Idx := 0;
         Frac_Count  : Idx := 0;
         Over        : Boolean := False;   --  more than Digit_Budget digits

         --  The exponent part is held back until the end of input instead
         --  of being streamed: vaton returns 1 for an explicit zero
         --  exponent (Combine and Convert_Big_Real both short-circuit on
         --  it), so a zero exponent must never reach it.
         Exp_Digits  : String (1 .. Digit_Budget);
         Exp_Count   : Idx := 0;
         Exp_Neg     : Boolean := False;
         Exp_Is_Zero : Boolean := True;
         Has_Fraction : Boolean := False;
         Lead_Zero     : Boolean := False;  --  whole part so far: zeros only
         Whole_Started : Boolean := False;  --  a whole digit was streamed
      begin
         Exponent := BI.To_Big_Integer (0);
         Force_Real := False;

         --  Vaton only accepts a separator outside '+', '-', '_', 'e', 'E'
         --  and the digits; any other use would violate its preconditions.
         --  The format delimiters are refused too (ambiguous with the
         --  prefixed and based formats).
         if not Vaton.Is_Valid_Decimal_Point (Decimal_Point)
           or else Is_Format_Delimiter (Decimal_Point)
         then
            Outcome := Failed_At (Invalid_Character, 1);
            return;
         end if;

         Vaton.Reset (P);

         --  Inject a leading '-' into vaton so it records Whole_Is_Negative.
         if Is_Negative then
            Vaton.Append (P, '-', Append_Ok, Decimal_Point);
            if not Append_Ok then
               Outcome := Failed_At (Storage_Exhausted, 1);
               return;
            end if;
         end if;

         --  Validate each character against the decimal grammar (state
         --  machine encodes: numeral [ '.' numeral ] [ (e|E) [+|-] numeral
         --  ], with a single '_' allowed between digits) and stream it
         --  into vaton.
         for N in B_First .. Len loop
            declare
               Ch : constant Character := C (Image, N);
            begin
               if Character'Pos (Ch) > 127 then
                  Outcome := Failed_At (Invalid_Character, N);
                  return;
               end if;

               case State is
                  when Whole_Start =>
                     if Is_Ascii_Digit (Ch) then
                        State := Whole_Digit;
                     elsif Ch = '_' then
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     else
                        Outcome := Failed_At (Invalid_Character, N);
                        return;
                     end if;

                  when Whole_Digit =>
                     if Is_Ascii_Digit (Ch) then
                        null;
                     elsif Ch = '_' then
                        State := Whole_Us;
                     elsif Widen (Ch) = Decimal_Point then
                        State := Frac_Start;
                     elsif Ch = 'e' or else Ch = 'E' then
                        State := Exp_Sign;
                     else
                        Outcome := Failed_At (Invalid_Character, N);
                        return;
                     end if;

                  when Whole_Us =>
                     if Is_Ascii_Digit (Ch) then
                        State := Whole_Digit;
                     else
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     end if;

                  when Frac_Start =>
                     if Is_Ascii_Digit (Ch) then
                        State := Frac_Digit;
                     elsif Ch = '_' then
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     else
                        Outcome := Failed_At (Empty_Digits, N);
                        return;
                     end if;

                  when Frac_Digit =>
                     if Is_Ascii_Digit (Ch) then
                        null;
                     elsif Ch = '_' then
                        State := Frac_Us;
                     elsif Ch = 'e' or else Ch = 'E' then
                        State := Exp_Sign;
                     else
                        Outcome := Failed_At (Invalid_Character, N);
                        return;
                     end if;

                  when Frac_Us =>
                     if Is_Ascii_Digit (Ch) then
                        State := Frac_Digit;
                     else
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     end if;

                  when Exp_Sign =>
                     if Is_Ascii_Digit (Ch) then
                        State := Exp_Digit;
                     elsif Ch = '+' or else Ch = '-' then
                        State := Exp_Start;
                     elsif Ch = '_' then
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     else
                        Outcome := Failed_At (Invalid_Character, N);
                        return;
                     end if;

                  when Exp_Start =>
                     if Is_Ascii_Digit (Ch) then
                        State := Exp_Digit;
                     elsif Ch = '_' then
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     else
                        Outcome := Failed_At (Empty_Digits, N);
                        return;
                     end if;

                  when Exp_Digit =>
                     if Is_Ascii_Digit (Ch) then
                        null;
                     elsif Ch = '_' then
                        State := Exp_Us;
                     else
                        Outcome := Failed_At (Invalid_Character, N);
                        return;
                     end if;

                  when Exp_Us =>
                     if Is_Ascii_Digit (Ch) then
                        State := Exp_Digit;
                     else
                        Outcome := Failed_At (Bad_Underscore, N);
                        return;
                     end if;
               end case;

               --  Character is grammatically valid: hold it back when it
               --  belongs to the exponent part, else feed it to vaton
               --  (while the significand is within budget).  Success is
               --  only False on storage / capacity trouble, never on
               --  syntax.
               if State = Exp_Digit then
                  Exp_Count := Exp_Count + 1;
                  if Exp_Count <= Budget_Idx then
                     Exp_Digits (Integer (Exp_Count)) := Ch;
                  end if;
                  if Ch /= '0' then
                     Exp_Is_Zero := False;
                  end if;
               elsif State = Exp_Start then
                  Exp_Neg := Exp_Neg or else Ch = '-';
               elsif State in Exp_Sign | Exp_Us then
                  null;
               else
                  if State = Whole_Digit and then Is_Ascii_Digit (Ch) then
                     Whole_Count := Whole_Count + 1;
                  elsif State = Frac_Digit and then Is_Ascii_Digit (Ch) then
                     Frac_Count := Frac_Count + 1;
                  end if;
                  Has_Fraction := Has_Fraction or else State = Frac_Start;
                  Over := Whole_Count + Frac_Count > Budget_Idx;
                  --  Vaton refuses a whole part with a leading zero beyond
                  --  the first (Is_Possible_Piece), and does not need the
                  --  underscores: leading zeros are held back (the value is
                  --  the same) and a lone zero is streamed when the whole
                  --  part ends; underscores are not streamed.  Residual
                  --  defect, left alone: the 'e' of a literal with both a
                  --  fraction and an exponent (7.5e3) is still streamed,
                  --  though Is_Possible_Piece wants an empty fraction there;
                  --  Vaton 0.1.0 does not check it and the value is right.
                  if Over or else Ch = '_' then
                     null;
                  elsif State = Whole_Digit and then Ch = '0'
                    and then not Whole_Started
                  then
                     Lead_Zero := True;
                  else
                     if Lead_Zero and then State /= Whole_Digit then
                        Vaton.Append (P, '0', Append_Ok, Decimal_Point);
                        Lead_Zero := False;
                        Whole_Started := True;
                     end if;
                     if State = Whole_Digit then
                        Whole_Started := True;
                        Lead_Zero := False;
                     end if;
                     Vaton.Append (P, Widen (Ch), Append_Ok, Decimal_Point);
                     if not Append_Ok then
                        Outcome := Failed_At (Storage_Exhausted, N);
                        return;
                     end if;
                  end if;
               end if;
            end;
         end loop;

         --  End-of-input acceptance check.
         case State is
            when Whole_Start | Frac_Start | Exp_Sign | Exp_Start =>
               Outcome := Failed_At (Empty_Digits, Len);
               return;
            when Whole_Us | Frac_Us | Exp_Us =>
               Outcome := Failed_At (Bad_Underscore, Len);
               return;
            when Whole_Digit | Frac_Digit | Exp_Digit =>
               null;
         end case;

         --  Digit budget: significand digits (whole and fraction) and
         --  exponent digits.  Overflow at end of input; no Big_Integer is
         --  built from more.
         if Over or else Exp_Count > Budget_Idx then
            Outcome := Failed_At (Overflow, Len);
            return;
         end if;

         --  Stream the held-back exponent unless it is zero (x * 10**0 =
         --  x).  A dropped zero exponent on a numeral without fraction
         --  becomes "<point>0" so that "7e0" stays a floating-point value,
         --  like "7e1".  That digit is synthetic: it is not charged to the
         --  budget.  When it would exceed vaton's digit limit (a
         --  Digit_Budget-digit numeral) it is not streamed and the literal
         --  is flagged Force_Real: Parse then builds the exact Big_Real.
         Append_Ok := True;
         if Lead_Zero then
            Vaton.Append (P, '0', Append_Ok, Decimal_Point);
         end if;
         if not Exact and then Exp_Count > 0 then
            if not Exp_Is_Zero then
               --  Vaton needs an exponent that is an Integer and, to be
               --  read correctly, of fewer than 8 digits: leading zeros are
               --  dropped, and a longer exponent (10 ** 7 or more, beyond
               --  every budget) is not streamed: the literal is flagged
               --  Force_Real (exact Big_Real or Overflow).
               declare
                  First_Sig : Integer := 1;
               begin
                  while Exp_Digits (First_Sig) = '0' loop
                     First_Sig := First_Sig + 1;
                  end loop;
                  if Integer (Exp_Count) - First_Sig + 1 > 7 then
                     Force_Real := True;
                  else
                     Vaton.Append (P, 'e', Append_Ok, Decimal_Point);
                     if Append_Ok and then Exp_Neg then
                        Vaton.Append (P, '-', Append_Ok, Decimal_Point);
                     end if;
                     for I in First_Sig .. Integer (Exp_Count) loop
                        exit when not Append_Ok;
                        Vaton.Append
                          (P, Widen (Exp_Digits (I)), Append_Ok,
                           Decimal_Point);
                     end loop;
                  end if;
               end;
            elsif not Has_Fraction then
               if Whole_Count < Budget_Idx then
                  Vaton.Append (P, Decimal_Point, Append_Ok, Decimal_Point);
                  if Append_Ok then
                     Vaton.Append (P, '0', Append_Ok, Decimal_Point);
                  end if;
               else
                  Force_Real := True;
               end if;
            end if;
         end if;
         if not Append_Ok then
            Outcome := Failed_At (Storage_Exhausted, Len);
            return;
         end if;

         if not Vaton.Is_Valid_Number (P) then
            --  State machine ruled out empty parts and dangling
            --  underscores, so the only remaining reason is length above
            --  vaton's digit limit (Is_Valid_Partial_Number -> Overflow).
            Outcome := Failed_At (Overflow, Len);
            return;
         end if;

         Exponent := Exponent_Value
                       (Exp_Digits (1 .. Integer (Exp_Count)), Exp_Neg);
         Outcome := (Failed => False);
      end Scan_Decimal;

      -----------------------------------------------------------------
      --  Underscore state machine + digit validation for a non-decimal
      --  run.
      --
      --  Digits (a stream of Character in Image (First..Last)) must
      --  satisfy:
      --    * first and last characters are digits valid in Base;
      --    * '_' occurs only between two such digits;
      --    * no other character is permitted.
      --
      --  Reports the FIRST offending position, or 0 in Bad_Pos on success.
      -----------------------------------------------------------------
      procedure Validate_Digit_Run
        (Image       : Text;
         First, Last : Idx;
         Base        : Base_Range;
         Bad_Pos     : out Idx;
         Bad_Reason  : out Error_Kind)
      is
         Prev_Was_Digit : Boolean := False;
         Any_Digit_Seen : Boolean := False;
      begin
         Bad_Pos := 0;
         Bad_Reason := None;

         if First > Last then
            Bad_Pos := Idx'Max (1, First);
            Bad_Reason := Empty_Digits;
            return;
         end if;

         for N in First .. Last loop
            declare
               Ch : constant Character := C (Image, N);
            begin
               if Ch = '_' then
                  if not Prev_Was_Digit then
                     Bad_Pos := N; Bad_Reason := Bad_Underscore; return;
                  end if;
                  Prev_Was_Digit := False;
               elsif Is_Ascii_Digit (Ch) then
                  if not Is_Digit_For_Base (Ch, Base) then
                     Bad_Pos := N; Bad_Reason := Invalid_Digit_For_Base;
                     return;
                  end if;
                  Prev_Was_Digit := True;
                  Any_Digit_Seen := True;
               elsif Is_Ascii_Letter (Ch) then
                  --  Any ASCII letter here is an attempted extended digit.
                  --  If it is not a valid one for the current base, report
                  --  Invalid_Digit_For_Base (covers 'G' in a hex/base-16
                  --  literal, 'a' in an octal literal, ...).
                  if not Is_Digit_For_Base (Ch, Base) then
                     Bad_Pos := N; Bad_Reason := Invalid_Digit_For_Base;
                     return;
                  end if;
                  Prev_Was_Digit := True;
                  Any_Digit_Seen := True;
               else
                  Bad_Pos := N; Bad_Reason := Invalid_Character; return;
               end if;
            end;
         end loop;

         if not Any_Digit_Seen then
            Bad_Pos := First;
            Bad_Reason := Empty_Digits;
            return;
         end if;

         if not Prev_Was_Digit then
            Bad_Pos := Last;
            Bad_Reason := Bad_Underscore;
         end if;
      end Validate_Digit_Run;

      -----------------------------------------------------------------
      --  Fast Long_Long_Integer accumulator (no exponent applied here).
      --  Reports Overflowed = True if we cannot represent the magnitude.
      -----------------------------------------------------------------
      procedure Fast_Accumulate
        (Image       : Text;
         First, Last : Idx;
         Base        : Base_Range;
         Value       : out Long_Long_Integer;
         Overflowed  : out Boolean)
      is
         Acc  : Long_Long_Integer := 0;
         LB   : constant Long_Long_Integer := Long_Long_Integer (Base);
         Lim  : constant Long_Long_Integer := Long_Long_Integer'Last;
      begin
         Value := 0;
         Overflowed := False;
         for N in First .. Last loop
            declare
               Ch : constant Character := C (Image, N);
            begin
               if Ch /= '_' then
                  declare
                     D : constant Long_Long_Integer :=
                       Long_Long_Integer (Digit_Value (Ch));
                  begin
                     if Acc > Lim / LB then
                        Overflowed := True; return;
                     end if;
                     Acc := Acc * LB;
                     if Acc > Lim - D then
                        Overflowed := True; return;
                     end if;
                     Acc := Acc + D;
                  end;
               end if;
            end;
         end loop;
         Value := Acc;
      end Fast_Accumulate;

      -----------------------------------------------------------------
      --  Big_Integer accumulator with optional Ada based exponent.
      --  Exponent = 0 yields the digit value alone; a positive exponent
      --  multiplies by Base ** Exponent (only the Parse path asks for
      --  that).
      --
      --  Bounded: a result of Digit_Budget decimal digits or more (at
      --  least 10 ** Digit_Budget) is Overflowed, the value is not built,
      --  and no integer above the limit is ever formed.  Each step checks
      --  the bound before it multiplies; the bound is monotone (every step
      --  only grows the value, and the final value is at least the last
      --  intermediate value when Acc is non-zero), so the decision is
      --  exact.
      -----------------------------------------------------------------
      procedure Big_Accumulate
        (Image       : Text;
         First, Last : Idx;
         Base        : Base_Range;
         Exponent    : Natural;
         Big         : out BI.Big_Integer;
         Overflowed  : out Boolean)
      is
         BI_Base : constant BI.Big_Integer :=
           BI.To_Big_Integer (Integer (Base));
         Limit   : constant BI.Big_Integer := Pow10 (Digit_Budget);
         --  Largest value V with V * Base still below Limit.
         Max_Pre : constant BI.Big_Integer :=
           (Limit - BI.To_Big_Integer (1)) / BI_Base;
         Acc     : BI.Big_Integer := BI.To_Big_Integer (0);
         Acc_Zero : Boolean := True;   --  Acc = 0, without a Big_Integer test
      begin
         Overflowed := False;
         Big := Acc;
         for N in First .. Last loop
            declare
               Ch : constant Character := C (Image, N);
            begin
               if Ch /= '_' and then not (Acc_Zero and then Ch = '0') then
                  Acc_Zero := False;
                  if Acc > Max_Pre then
                     Overflowed := True;
                     return;
                  end if;
                  Acc := Acc * BI_Base
                         + BI.To_Big_Integer (Digit_Value (Ch));
                  if Acc >= Limit then
                     Overflowed := True;
                     return;
                  end if;
               end if;
            end;
         end loop;

         if Exponent > 0 and then not Acc_Zero then
            declare
               Factor : BI.Big_Integer := BI.To_Big_Integer (1);
            begin
               for I in 1 .. Exponent loop
                  if Factor > Max_Pre then
                     --  Factor * Base >= Limit, and Acc is at least 1.
                     Overflowed := True;
                     return;
                  end if;
                  Factor := Factor * BI_Base;
               end loop;
               if Acc > (Limit - BI.To_Big_Integer (1)) / Factor then
                  Overflowed := True;
                  return;
               end if;
               Acc := Acc * Factor;     --  below Limit by the test above
            end;
         end if;
         Big := Acc;
      end Big_Accumulate;

      -----------------------------------------------------------------
      --  Common back-end for Parse's non-decimal paths: given a validated
      --  digit run and an optional Ada based exponent, produce a
      --  Parse_Result.
      -----------------------------------------------------------------
      function Finish_Non_Decimal
        (Image       : Text;
         First, Last : Idx;
         Base        : Base_Range;
         Exponent    : Natural;
         Is_Negative : Boolean;
         End_Pos     : Positive) return Parse_Result
      is
         Value  : Long_Long_Integer;
         Blew   : Boolean;
      begin
         if Exponent = 0 then
            Fast_Accumulate (Image, First, Last, Base, Value, Blew);
            if not Blew then
               return (Status => Ok,
                       Value  => LLI_To_Vaton_Number
                                   (if Is_Negative then -Value else Value));
            end if;
         end if;

         declare
            Big        : BI.Big_Integer;
            Overflowed : Boolean;
         begin
            Big_Accumulate
              (Image, First, Last, Base, Exponent, Big, Overflowed);
            if Overflowed then
               return (Status => Error, Reason => Overflow,
                       Position => End_Pos);
            end if;
            return (Status => Ok, Value => Big_To_Number (Big, Is_Negative));
         end;
      end Finish_Non_Decimal;

      -----------------------------------------------------------------
      --  Prefixed scanner: 0x / 0o / 0b, no exponent grammar.  A trailing
      --  'e'/'E' on a hex literal is accepted as a hex digit.
      -----------------------------------------------------------------
      procedure Scan_Prefixed
        (Image        : Text;
         B_First, Len : Idx;
         Base         : Base_Range;
         Digits_First : out Idx;
         Digits_Last  : out Idx;
         Outcome      : out Scan_Result)
      is
         Bad_Pos    : Idx;
         Bad_Reason : Error_Kind;
      begin
         Digits_First := B_First + 2;
         Digits_Last  := Len;
         if Digits_First > Digits_Last then
            Outcome := Failed_At (Empty_Digits, B_First + 1);
            return;
         end if;
         Validate_Digit_Run
           (Image, Digits_First, Digits_Last, Base, Bad_Pos, Bad_Reason);
         if Bad_Pos /= 0 then
            Outcome := Failed_At (Bad_Reason, Bad_Pos);
            return;
         end if;
         Outcome := (Failed => False);
      end Scan_Prefixed;

      -----------------------------------------------------------------
      --  Based scanner:  base '#' digits '#' [ ('e'|'E') ['+'] digits ]
      --
      --  Exponent: at most Digit_Budget digits (Overflow at end of input
      --  beyond, leading zeros counted).  Parse reads it as a Natural
      --  (Overflow beyond).  Exact (Parse_Exact) reads it as an exact value
      --  in Exp_Big.  A limit trips only after the whole literal has been
      --  validated: a syntax error always wins.
      -----------------------------------------------------------------
      procedure Scan_Based
        (Image        : Text;
         B_First, Len : Idx;
         Exact        : Boolean;
         Base         : out Base_Range;
         Digits_First : out Idx;
         Digits_Last  : out Idx;
         Exponent     : out Natural;
         Exp_Big      : out BI.Big_Integer;
         Outcome      : out Scan_Result)
      is
         First_Hash    : Idx := 0;
         Second_Hash   : Idx := 0;
         Base_Value    : Natural := 0;
         Base_Last     : Idx;
         Exp_Value     : Natural := 0;
         Bad_Pos       : Idx;
         Bad_Reason    : Error_Kind;
      begin
         Base := 2;
         Digits_First := 1;
         Digits_Last  := 0;
         Exponent     := 0;
         Exp_Big      := BI.To_Big_Integer (0);

         for N in B_First .. Len loop
            if C (Image, N) = '#' then
               First_Hash := N;
               exit;
            end if;
         end loop;
         if First_Hash = 0 then
            Outcome := Failed_At (Malformed_Based_Literal, Len);
            return;
         end if;
         Base_Last := First_Hash - 1;

         if Base_Last < B_First then
            Outcome := Failed_At (Empty_Digits, B_First);
            return;
         end if;
         for N in B_First .. Base_Last loop
            if not Is_Ascii_Digit (C (Image, N)) then
               Outcome := Failed_At (Invalid_Character, N);
               return;
            end if;
            if Base_Value > (Natural'Last - Digit_Value (C (Image, N))) / 10
            then
               Outcome := Failed_At (Base_Out_Of_Range, N);
               return;
            end if;
            Base_Value := Base_Value * 10 + Digit_Value (C (Image, N));
         end loop;
         if Base_Value not in 2 .. 16 then
            Outcome := Failed_At (Base_Out_Of_Range, Base_Last);
            return;
         end if;

         for N in First_Hash + 1 .. Len loop
            if C (Image, N) = '#' then
               Second_Hash := N;
               exit;
            end if;
            if C (Image, N) = '.' then
               Outcome := Failed_At (Invalid_Character, N);
               return;
            end if;
         end loop;
         if Second_Hash = 0 then
            Outcome := Failed_At (Malformed_Based_Literal, Len);
            return;
         end if;
         Digits_First := First_Hash + 1;
         Digits_Last  := Second_Hash - 1;

         Validate_Digit_Run
           (Image, Digits_First, Digits_Last, Base_Range (Base_Value),
            Bad_Pos, Bad_Reason);
         if Bad_Pos /= 0 then
            Outcome := Failed_At (Bad_Reason, Bad_Pos);
            return;
         end if;

         if Second_Hash < Len then
            declare
               I           : Idx := Second_Hash + 1;
               Ch          : Character := C (Image, I);
               Exp_Digits  : String (1 .. Digit_Budget);
               Exp_Count   : Idx := 0;
               Nat_Over    : Boolean := False;
            begin
               if Ch /= 'e' and then Ch /= 'E' then
                  Outcome := Failed_At (Malformed_Based_Literal, I);
                  return;
               end if;
               I := I + 1;
               if I > Len then
                  Outcome := Failed_At (Empty_Digits, I);
                  return;
               end if;
               if C (Image, I) = '+' then
                  I := I + 1;
               elsif C (Image, I) = '-' then
                  Outcome := Failed_At (Unexpected_Exponent, I);
                  return;
               end if;
               if I > Len then
                  Outcome := Failed_At (Empty_Digits, I);
                  return;
               end if;
               declare
                  Prev_Was_Digit : Boolean := False;
                  Any_Seen       : Boolean := False;
               begin
                  while I <= Len loop
                     Ch := C (Image, I);
                     if Ch = '_' then
                        if not Prev_Was_Digit then
                           Outcome := Failed_At (Bad_Underscore, I);
                           return;
                        end if;
                        Prev_Was_Digit := False;
                     elsif Is_Ascii_Digit (Ch) then
                        if not Nat_Over then
                           if Exp_Value
                                > (Natural'Last - Digit_Value (Ch)) / 10
                           then
                              Nat_Over := True;
                           else
                              Exp_Value := Exp_Value * 10 + Digit_Value (Ch);
                           end if;
                        end if;
                        Exp_Count := Exp_Count + 1;
                        if Exp_Count <= Budget_Idx then
                           Exp_Digits (Integer (Exp_Count)) := Ch;
                        end if;
                        Prev_Was_Digit := True;
                        Any_Seen := True;
                     else
                        Outcome := Failed_At (Invalid_Character, I);
                        return;
                     end if;
                     I := I + 1;
                  end loop;
                  if not Any_Seen then
                     Outcome := Failed_At (Empty_Digits, Len);
                     return;
                  end if;
                  if not Prev_Was_Digit then
                     Outcome := Failed_At (Bad_Underscore, Len);
                     return;
                  end if;
               end;
               --  Limits after syntax: the whole literal is valid here.
               --  Digit budget, as for a decimal exponent (leading zeros
               --  count), and, for Parse, the Natural range: Overflow at
               --  end of input.
               if Exp_Count > Budget_Idx or else (Nat_Over and not Exact)
               then
                  Outcome := Failed_At (Overflow, Len);
                  return;
               end if;
               if Exact then
                  Exp_Big := Exponent_Value
                               (Exp_Digits (1 .. Integer (Exp_Count)), False);
               end if;
            end;
         end if;

         Base     := Base_Range (Base_Value);
         Exponent := Exp_Value;
         Outcome  := (Failed => False);
      end Scan_Based;

      -----------------------------------------------------------------
      --  Shared front end for Parse and Parse_Exact: sign, empty checks
      --  and format dispatch to the scanners.  On success, Lit describes
      --  the literal: for Format_Decimal the digits live in P; for the
      --  other formats they are the digit run [Digits_First .. Digits_Last]
      --  of Image (1-based) and the Ada based exponent.
      --
      --  Exact = False: Parse's scan (exponent streamed into vaton).
      --  Exact = True : Parse_Exact's scan (exponent held as Dec_Exponent).
      -----------------------------------------------------------------
      procedure Scan_Literal
        (Image         : Text;
         Decimal_Point : Wide_Character;
         Exact         : Boolean;
         P             : out Vaton.Number_Pieces;
         Lit           : out Scanned_Literal;
         Outcome       : out Scan_Result)
      is
         Len         : constant Idx := Idx (Image'Length);
         B_First     : Idx := 1;
      begin
         Lit := (others => <>);
         if Len = 0 then
            Outcome := Failed_At (Empty_Input, 1);
            return;
         end if;
         case C (Image, 1) is
            when '+' =>
               B_First := 2;
            when '-' =>
               Lit.Is_Negative := True;
               B_First := 2;
            when others =>
               null;
         end case;
         if B_First > Len then
            Outcome := Failed_At (Empty_Digits, B_First);
            return;
         end if;

         declare
            Fmt : constant Detected_Format :=
              Detect_Format (Image, B_First, Len);
         begin
            case Fmt.Kind is
               when Format_Empty =>
                  Outcome := Failed_At (Empty_Digits, B_First);
               when Format_Decimal =>
                  Lit.Kind := Format_Decimal;
                  Scan_Decimal (Image, B_First, Len, Lit.Is_Negative,
                                Decimal_Point, Exact, P, Lit.Dec_Exponent,
                                Lit.Force_Real, Outcome);
               when Format_Prefixed =>
                  Lit.Kind := Format_Prefixed;
                  Lit.Base := Fmt.Prefix_Base;
                  Scan_Prefixed (Image, B_First, Len, Lit.Base,
                                 Lit.Digits_First, Lit.Digits_Last, Outcome);
               when Format_Based =>
                  Lit.Kind := Format_Based;
                  Scan_Based (Image, B_First, Len, Exact, Lit.Base,
                              Lit.Digits_First, Lit.Digits_Last,
                              Lit.Exponent, Lit.Dec_Exponent, Outcome);
            end case;
         end;
      end Scan_Literal;

      -----------------------------------------------------------------
      --  Entry points
      -----------------------------------------------------------------

      --  P is owned by the caller (Parse_Text), which frees its digit arrays
      --  with Vaton.Reset on every path: this body may return anywhere.
      function Parse_Body
        (Image         : Text;
         Decimal_Point : Wide_Character;
         P             : in out Vaton.Number_Pieces) return Parse_Result
      is
         Lit     : Scanned_Literal;
         Outcome : Scan_Result;
      begin
         Scan_Literal (Image, Decimal_Point, False, P, Lit, Outcome);
         if Outcome.Failed then
            return (Status => Error, Reason => Outcome.Reason,
                    Position => Outcome.Position);
         end if;

         case Lit.Kind is
            when Format_Empty =>
               return (Status => Error, Reason => Empty_Digits, Position => 1);
            when Format_Decimal =>
               if Lit.Force_Real
                 or else Vaton_Float_Overflows (P)
                 or else Vaton_Big_Denominator_Too_Large (P)
               then
                  return Decimal_Fallback (P, Lit, Image'Length);
               end if;
               declare
                  V : constant Vaton.Number := Vaton.To_Number (P);
               begin
                  if V.Kind = Vaton.NaN then
                     return Decimal_Fallback (P, Lit, Image'Length);
                  end if;
                  return (Status => Ok, Value => V);
               end;
            when Format_Prefixed | Format_Based =>
               return Finish_Non_Decimal
                        (Image, Lit.Digits_First, Lit.Digits_Last, Lit.Base,
                         Lit.Exponent, Lit.Is_Negative,
                         End_Pos => Image'Length);
         end case;
      end Parse_Body;

      function Parse_Text
        (Image : Text; Decimal_Point : Wide_Character) return Parse_Result
      is
         P      : Vaton.Number_Pieces;
         Result : constant Parse_Result :=
           Parse_Body (Image, Decimal_Point, P);
      begin
         Vaton.Reset (P);
         return Result;
      end Parse_Text;

      function Parse_Exact_Body
        (Image         : Text;
         Decimal_Point : Wide_Character;
         P             : in out Vaton.Number_Pieces) return Exact_Result
      is
         Lit     : Scanned_Literal;
         Outcome : Scan_Result;
      begin
         Scan_Literal (Image, Decimal_Point, True, P, Lit, Outcome);
         if Outcome.Failed then
            return (Status => Error, Reason => Outcome.Reason,
                    Position => Outcome.Position);
         end if;

         case Lit.Kind is
            when Format_Empty =>
               return (Status => Error, Reason => Empty_Digits, Position => 1);
            when Format_Decimal =>
               return (Status => Ok,
                       Value  => Decimal_Exact (P, Lit.Is_Negative,
                                                Lit.Dec_Exponent));
            when Format_Prefixed | Format_Based =>
               declare
                  Significand : BI.Big_Integer;
                  Fast        : Long_Long_Integer;
                  Overflowed  : Boolean;
               begin
                  --  Digits only, bounded by the digit budget; the Ada
                  --  exponent is carried as Scale, never as a power.
                  Fast_Accumulate (Image, Lit.Digits_First, Lit.Digits_Last,
                                   Lit.Base, Fast, Overflowed);
                  if not Overflowed then
                     Significand := Fast_To_Big (Fast);
                  else
                     Big_Accumulate (Image, Lit.Digits_First, Lit.Digits_Last,
                                     Lit.Base, 0, Significand, Overflowed);
                  end if;
                  if Overflowed then
                     return (Status => Error, Reason => Overflow,
                             Position => Image'Length);
                  end if;
                  return (Status => Ok,
                          Value  => (Negative    => Lit.Is_Negative,
                                     Significand => Significand,
                                     Radix       => Lit.Base,
                                     Scale       => Lit.Dec_Exponent));
               end;
         end case;
      end Parse_Exact_Body;

      function Parse_Exact_Text
        (Image : Text; Decimal_Point : Wide_Character) return Exact_Result
      is
         P      : Vaton.Number_Pieces;
         Result : constant Exact_Result :=
           Parse_Exact_Body (Image, Decimal_Point, P);
      begin
         Vaton.Reset (P);
         return Result;
      end Parse_Exact_Text;

   end Engine;

   function Identity (X : Character) return Character is (X);

   function Narrow_Wide (X : Wide_Character) return Character is
     (Character'Val (Natural'Min (Wide_Character'Pos (X), 255)));

   function Narrow_Wide_Wide (X : Wide_Wide_Character) return Character is
     (Character'Val (Natural'Min (Wide_Wide_Character'Pos (X), 255)));

   package String_Engine is new Engine (Character, String, Identity);
   package Wide_Engine is new Engine (Wide_Character, Wide_String,
                                      Narrow_Wide);
   package Wide_Wide_Engine is new Engine (Wide_Wide_Character,
                                           Wide_Wide_String,
                                           Narrow_Wide_Wide);

   -----------------------------------------------------------------------
   --  Public entry points.  A non-ASCII character in a Wide_String is
   --  reported first (at its position), before any syntax error, exactly
   --  as when the image was narrowed up front; the image is scanned, not
   --  copied.
   -----------------------------------------------------------------------

   --  Position of the first non-ASCII character, or 0.
   function First_Non_Ascii (Image : Wide_String) return Natural is
   begin
      for I in Image'Range loop
         if Wide_Character'Pos (Image (I)) > 127 then
            return I - Image'First + 1;
         end if;
      end loop;
      return 0;
   end First_Non_Ascii;

   function First_Non_Ascii (Image : Wide_Wide_String) return Natural is
   begin
      for I in Image'Range loop
         if Wide_Wide_Character'Pos (Image (I)) > 127 then
            return I - Image'First + 1;
         end if;
      end loop;
      return 0;
   end First_Non_Ascii;

   --  No handler for Storage_Error: heap exhaustion is outside the contract
   --  (see the spec).  One call allocates a bounded amount (Memory bound,
   --  below), whatever the length of the image.

   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Parse_Result is
   begin
      return String_Engine.Parse_Text (Image, Decimal_Point);
   end Parse;

   function Parse
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Bad : constant Natural := First_Non_Ascii (Image);
   begin
      if Bad /= 0 then
         return (Status => Error, Reason => Invalid_Character,
                 Position => Bad);
      end if;
      return Wide_Engine.Parse_Text (Image, Decimal_Point);
   end Parse;

   function Parse
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Bad : constant Natural := First_Non_Ascii (Image);
   begin
      if Bad /= 0 then
         return (Status => Error, Reason => Invalid_Character,
                 Position => Bad);
      end if;
      return Wide_Wide_Engine.Parse_Text (Image, Decimal_Point);
   end Parse;

   function Parse_Exact
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Exact_Result is
   begin
      return String_Engine.Parse_Exact_Text (Image, Decimal_Point);
   end Parse_Exact;

   function Parse_Exact
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result
   is
      Bad : constant Natural := First_Non_Ascii (Image);
   begin
      if Bad /= 0 then
         return (Status => Error, Reason => Invalid_Character,
                 Position => Bad);
      end if;
      return Wide_Engine.Parse_Exact_Text (Image, Decimal_Point);
   end Parse_Exact;

   function Parse_Exact
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result
   is
      Bad : constant Natural := First_Non_Ascii (Image);
   begin
      if Bad /= 0 then
         return (Status => Error, Reason => Invalid_Character,
                 Position => Bad);
      end if;
      return Wide_Wide_Engine.Parse_Exact_Text (Image, Decimal_Point);
   end Parse_Exact;

end Radix_Literals;
