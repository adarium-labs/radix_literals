--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Integers;
with Ada.Strings.Fixed;
with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Test_Support; use Test_Support;
with Vaton;

package body Exact_Tests is

   package RL renames Radix_Literals;
   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   use type RL.Parse_Status;
   use type RL.Error_Kind;
   use type BI.Big_Integer;
   use type Vaton.Number_Kind;

   --  Decimal text of a Big_Integer, without the leading blank that
   --  To_String may emit for non-negative values.
   function Big_Image (X : BI.Big_Integer) return String is
      Img   : constant String := BI.To_String (X, Width => 0, Base => 10);
      First : Positive := Img'First;
   begin
      while First < Img'Last and then Img (First) = ' ' loop
         First := First + 1;
      end loop;
      return Img (First .. Img'Last);
   end Big_Image;

   function Pow (Radix : Positive; N : Natural) return BI.Big_Integer is
      Acc : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      for I in 1 .. N loop
         Acc := Acc * BI.To_Big_Integer (Integer (Radix));
      end loop;
      return Acc;
   end Pow;

   --  Asserts an Ok Parse_Exact result with the given parts.  Significand
   --  and Scale are compared as decimal text so that values beyond Integer
   --  and Long_Long_Integer need no conversion.
   procedure Assert_Exact
     (Image    : String;
      Negative : Boolean;
      Sig      : String;
      Radix    : RL.Radix_Range;
      Scale    : String;
      Msg      : String)
   is
      R : constant RL.Exact_Result := RL.Parse_Exact (Image);
   begin
      Assert (R.Status = RL.Ok,
              Msg & ": expected Ok for " & Image
              & ", got " & (if R.Status = RL.Ok then "Ok"
                            else RL.Error_Kind'Image (R.Reason)));
      Assert (R.Value.Negative = Negative,
              Msg & ": Negative mismatch for " & Image);
      Assert (Big_Image (R.Value.Significand) = Sig,
              Msg & ": Significand mismatch for " & Image & " -- got "
              & Big_Image (R.Value.Significand) & ", expected " & Sig);
      Assert (R.Value.Radix = Radix,
              Msg & ": Radix mismatch for " & Image);
      Assert (Big_Image (R.Value.Scale) = Scale,
              Msg & ": Scale mismatch for " & Image & " -- got "
              & Big_Image (R.Value.Scale) & ", expected " & Scale);
   end Assert_Exact;

   --  Parse and Parse_Exact must agree on accept/reject and on the error
   --  (Reason, Position).  For integer-valued Parse results, the exact
   --  value must also equal (-1 if Negative) * Significand * Radix ** Scale.
   procedure Assert_Same_As_Parse (Image : String; Msg : String) is
      P : constant RL.Parse_Result := RL.Parse (Image);
      E : constant RL.Exact_Result := RL.Parse_Exact (Image);
   begin
      Assert (P.Status = E.Status,
              Msg & ": Status differs for " & Image);
      if P.Status = RL.Error then
         Assert (P.Reason = E.Reason and then P.Position = E.Position,
                 Msg & ": error differs for " & Image & " -- Parse "
                 & RL.Error_Kind'Image (P.Reason) & " at"
                 & Positive'Image (P.Position) & ", Parse_Exact "
                 & RL.Error_Kind'Image (E.Reason) & " at"
                 & Positive'Image (E.Position));
         return;
      end if;

      if P.Value.Kind in Vaton.Integer | Vaton.Long_Integer
                         | Vaton.Long_Long_Integer
        and then E.Value.Scale >= BI.To_Big_Integer (0)
        and then E.Value.Scale <= BI.To_Big_Integer (40)
      then
         declare
            N    : constant Natural :=
              Natural'Value (Big_Image (E.Value.Scale));
            Want : BI.Big_Integer :=
              E.Value.Significand * Pow (E.Value.Radix, N);
            Got  : constant String :=
              Ada.Strings.Fixed.Trim
                (Long_Long_Integer'Image (LLI_Of (P)), Ada.Strings.Left);
         begin
            if E.Value.Negative then
               Want := -Want;
            end if;
            Assert (Big_Image (Want) = Got,
                    Msg & ": exact value differs from Parse for " & Image
                    & " -- Parse " & Got & ", exact " & Big_Image (Want));
         end;
      end if;
   end Assert_Same_As_Parse;

   ---------------------------------------------------------------------

   procedure Decimal_16_To_18_Digits (T : in out Test_Fixture) is
   begin
      Assert_Exact ("1234567890123456", False, "1234567890123456",
                    10, "0", "16 digits");
      Assert_Exact ("12345678901234567", False, "12345678901234567",
                    10, "0", "17 digits");
      Assert_Exact ("123456789012345678", False, "123456789012345678",
                    10, "0", "18 digits");
      Assert_Exact ("0.123456789012345678", False, "123456789012345678",
                    10, "-18", "18 significant fraction digits");
      Assert_Exact ("-1234567890.12345678", True, "123456789012345678",
                    10, "-8", "18 digits split by a point, negative");
   end Decimal_16_To_18_Digits;

   procedure Decimal_Fraction_And_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Exact ("1.25e3", False, "125", 10, "1", "fraction + exponent");
      Assert_Exact ("12.5E-2", False, "125", 10, "-3", "negative exponent");
      Assert_Exact ("0.5e+1", False, "5", 10, "0", "explicit + exponent");
      Assert_Exact ("-3.5e0", True, "35", 10, "-1",
                    "zero exponent with fraction");
      Assert_Exact ("7e1", False, "7", 10, "1", "integer with exponent");
      --  A zero exponent is the same as none: 7e0 is (7, Scale 0).
      Assert_Exact ("7e0", False, "7", 10, "0",
                    "zero exponent without fraction");
   end Decimal_Fraction_And_Exponent;

   procedure Negative_Zero (T : in out Test_Fixture) is
   begin
      Assert_Exact ("-0.0", True, "0", 10, "-1", "-0.0 keeps Negative");
      Assert_Exact ("-0." & String'([1 .. 17 => '0']), True, "0", 10, "-17",
                    "-0.00000000000000000 keeps Negative");
      Assert_Exact ("0", False, "0", 10, "0", "plain zero");
   end Negative_Zero;

   procedure Huge_And_Tiny_Exponents (T : in out Test_Fixture) is
   begin
      Assert_Exact ("1e400", False, "1", 10, "400", "1e400");
      Assert_Exact ("1e-400", False, "1", 10, "-400", "1e-400");
      Assert_Exact ("1e1000", False, "1", 10, "1000", "1e1000");
      Assert_Exact ("-2.5e-1000", True, "25", 10, "-1001", "fraction, -1000");
      --  Parse_Exact reads the exponent exactly (up to Vaton's 1900-digit
      --  budget); Parse keeps Vaton's exponent-length limit.
      Assert_Exact ("1e999999999999999999999", False, "1", 10,
                    "999999999999999999999", "21-digit exponent");
      Assert (RL.Parse (String'("1e999999999999999999999")).Reason
              = RL.Overflow,
              "21-digit exponent: Parse keeps Vaton's limit (Overflow)");
      Assert (RL.Parse_Exact (String'("1e" & [1 .. 1901 => '1'])).Reason
              = RL.Overflow,
              "exponent beyond 1900 digits is Overflow in Parse_Exact");
      Assert_Exact ("2.5e-" & String'([1 .. 1000 => '0']) & "1", False,
                    "25", 10, "-2", "1000-digit exponent (value -1)");
   end Huge_And_Tiny_Exponents;

   procedure Based_Exact_Forms (T : in out Test_Fixture) is
   begin
      Assert_Exact ("16#FF#E2", False, "255", 16, "2", "based with exponent");
      Assert_Exact ("16#FF#E+2", False, "255", 16, "2", "explicit +");
      Assert_Exact ("-16#ff_ff#E+1", True, "65535", 16, "1",
                    "negative, underscore, lower-case digits");
      Assert_Exact ("2#1010#", False, "10", 2, "0", "binary based");
      Assert_Exact ("8#777#", False, "511", 8, "0", "octal based");
      Assert_Exact ("16#0#", False, "0", 16, "0", "zero based");
      Assert_Exact ("11#A#", False, "10", 11, "0", "base 11");
      Assert_Exact ("15#EE#E1", False, "224", 15, "1", "base 15 exponent");
      Assert_Exact ("10#5#E3", False, "5", 10, "3", "base 10 exponent");
      Assert_Exact ("2#11#E4", False, "3", 2, "4", "binary exponent");
   end Based_Exact_Forms;

   procedure Based_Exponent_At_Natural_Max (T : in out Test_Fixture) is
   begin
      --  Parse would compute 2 ** 2147483647 here; Parse_Exact must not.
      Assert_Exact ("2#1#E2147483647", False, "1", 2, "2147483647",
                    "exponent at Natural'Last, no power formed");
   end Based_Exponent_At_Natural_Max;

   procedure Prefixed_Exact_Forms (T : in out Test_Fixture) is
   begin
      Assert_Exact ("0xDEAD_BEEF", False, "3735928559", 16, "0",
                    "hex with underscores");
      Assert_Exact ("0o377", False, "255", 8, "0", "octal prefix");
      Assert_Exact ("0b1010_1010", False, "170", 2, "0", "binary prefix");
      Assert_Exact ("+0x1", False, "1", 16, "0", "explicit plus");
      Assert_Exact ("-0X10", True, "16", 16, "0", "negative, upper X");
      --  A trailing 'e' on a prefixed literal is a hex digit, not an
      --  exponent: 0xFFe2 = 65506.
      Assert_Exact ("0xFFe2", False, "65506", 16, "0", "e is a digit");
   end Prefixed_Exact_Forms;

   procedure Underscores_And_Signs (T : in out Test_Fixture) is
   begin
      --  Digits 1000 . 0001 e 10: significand 10000001, scale 10 - 4.
      Assert_Exact ("1_000.000_1e1_0", False, "10000001", 10, "6",
                    "underscores in whole, fraction and exponent");
      Assert_Exact ("-1_0", True, "10", 10, "0", "negative with underscore");
      Assert_Exact ("+1.5", False, "15", 10, "-1", "explicit plus, decimal");
   end Underscores_And_Signs;

   procedure Decimal_Point_Comma (T : in out Test_Fixture) is
      R : constant RL.Exact_Result :=
        RL.Parse_Exact (String'("1,5e2"), ',');
      P : constant RL.Parse_Result := RL.Parse (String'("1,5e2"), ',');
   begin
      --  The separator is the Decimal_Point argument: ',' is a fraction
      --  point, '.' is then not part of the grammar.
      Assert (R.Status = RL.Ok
              and then Big_Image (R.Value.Significand) = "15"
              and then Big_Image (R.Value.Scale) = "1",
              "Decimal_Point ',': 1,5e2 is 15 * 10 ** 1");
      Assert (P.Status = RL.Ok and then P.Value.Kind = Vaton.Float,
              "Decimal_Point ',': Parse gives a Float for 1,5e2");
      Assert (RL.Parse_Exact (String'("1.5e2"), ',').Reason
              = RL.Invalid_Character
              and then RL.Parse_Exact (String'("1.5e2"), ',').Position = 2,
              "Decimal_Point ',': '.' is Invalid_Character at 2");
   end Decimal_Point_Comma;

   procedure Invalid_Decimal_Point (T : in out Test_Fixture) is
      --  Vaton's separator rule: '+', '-', '_', 'e', 'E' and digits are
      --  not usable; decimal literals are then Invalid_Character at 1.
      Bad : constant array (1 .. 4) of Wide_Character :=
        ('+', 'e', 'E', '7');
   begin
      for I in Bad'Range loop
         declare
            R : constant RL.Exact_Result :=
              RL.Parse_Exact (String'("1.5"), Bad (I));
            P : constant RL.Parse_Result :=
              RL.Parse (String'("1.5"), Bad (I));
         begin
            Assert (R.Status = RL.Error
                    and then R.Reason = RL.Invalid_Character
                    and then R.Position = 1,
                    "invalid separator: Parse_Exact must reject at 1");
            Assert (P.Status = RL.Error
                    and then P.Reason = RL.Invalid_Character
                    and then P.Position = 1,
                    "invalid separator: Parse must reject at 1");
         end;
      end loop;
   end Invalid_Decimal_Point;

   procedure Wide_Overloads (T : in out Test_Fixture) is
      W  : constant RL.Exact_Result :=
        RL.Parse_Exact (Wide_String'("16#FF#E2"));
      WW : constant RL.Exact_Result :=
        RL.Parse_Exact (Wide_Wide_String'("0x1F"));
      NA : constant RL.Exact_Result :=
        RL.Parse_Exact (Wide_Wide_String'
          (1 => Wide_Wide_Character'Val (16#3B1#), 2 => '1'));
   begin
      Assert (W.Status = RL.Ok
              and then Big_Image (W.Value.Significand) = "255"
              and then Big_Image (W.Value.Scale) = "2",
              "Wide_String Parse_Exact: 16#FF#E2");
      Assert (WW.Status = RL.Ok
              and then Big_Image (WW.Value.Significand) = "31"
              and then WW.Value.Radix = 16,
              "Wide_Wide_String Parse_Exact: 0x1F");
      Assert (NA.Status = RL.Error
              and then NA.Reason = RL.Invalid_Character
              and then NA.Position = 1,
              "Wide_Wide_String Parse_Exact: non-ASCII at 1");
   end Wide_Overloads;

   procedure Errors_Match_Parse (T : in out Test_Fixture) is
   begin
      Assert_Same_As_Parse ("", "empty");
      Assert_Same_As_Parse ("-", "lone sign");
      Assert_Same_As_Parse ("+", "lone plus");
      Assert_Same_As_Parse ("0x", "prefix without digits");
      Assert_Same_As_Parse ("0x_FF", "underscore after prefix");
      Assert_Same_As_Parse ("16##", "empty based digits");
      Assert_Same_As_Parse ("16#FF#E", "based exponent without digits");
      Assert_Same_As_Parse ("16#FF#E+", "based exponent sign only");
      Assert_Same_As_Parse ("16#FF#E-1", "based negative exponent");
      Assert_Same_As_Parse ("16#FF", "missing closing hash");
      Assert_Same_As_Parse ("16#FF#X", "junk after based literal");
      Assert_Same_As_Parse ("16#F.8#", "based real");
      Assert_Same_As_Parse ("0x1.8p3", "C hex float");
      Assert_Same_As_Parse ("8#8#", "digit above base");
      Assert_Same_As_Parse ("2#2#", "digit above base 2");
      Assert_Same_As_Parse ("37#1#", "base out of range");
      Assert_Same_As_Parse ("1#1#", "base 1");
      Assert_Same_As_Parse ("0b102", "binary with 2");
      Assert_Same_As_Parse ("0o8", "octal with 8");
      Assert_Same_As_Parse ("1e", "exponent without digits");
      Assert_Same_As_Parse ("1e+", "exponent sign only");
      Assert_Same_As_Parse ("1e_5", "underscore after e");
      Assert_Same_As_Parse (".5", "leading point");
      Assert_Same_As_Parse ("1.", "trailing point");
      Assert_Same_As_Parse ("1..2", "double point");
      Assert_Same_As_Parse ("1__0", "doubled underscore");
      Assert_Same_As_Parse ("1_", "trailing underscore");
      Assert_Same_As_Parse ("_1", "leading underscore");
      Assert_Same_As_Parse ("1_.5", "underscore before point");
      Assert_Same_As_Parse ("1.5_", "trailing underscore in fraction");
      Assert_Same_As_Parse ("--1", "double minus");
      Assert_Same_As_Parse ("+-1", "plus minus");
      Assert_Same_As_Parse ("1 2", "embedded space");
      Assert_Same_As_Parse ("1e5e5", "two exponents");
      Assert_Same_As_Parse ("G", "letter alone");
      Assert_Same_As_Parse ("0x_1", "underscore after 0x");
      --  A based exponent above Natural'Last is the one place the two
      --  differ: Parse reports Overflow, Parse_Exact keeps it as Scale.
      Assert (RL.Parse (String'("2#1#E9999999999")).Reason = RL.Overflow,
              "Parse: based exponent above Natural'Last is Overflow");
      Assert_Exact ("2#1#E9999999999", False, "1", 2, "9999999999",
                    "Parse_Exact: based exponent above Natural'Last");
      Assert_Same_As_Parse (String'([1 => Character'Val (200)]), "non-ASCII");

      declare
         R : constant RL.Exact_Result := RL.Parse_Exact (String'("0x"));
      begin
         Assert (R.Status = RL.Error and then R.Reason = RL.Empty_Digits
                 and then R.Position = 2,
                 "Parse_Exact(0x): Empty_Digits at 2");
      end;
   end Errors_Match_Parse;

   procedure Overflow_Matches_Parse (T : in out Test_Fixture) is
      Big_Image_Input : constant String := [1 .. 2_000 => '1'];
   begin
      Assert_Same_As_Parse (Big_Image_Input, "2000-digit integer");
      Assert (RL.Parse_Exact (Big_Image_Input).Reason = RL.Overflow,
              "Parse_Exact: 2000-digit integer is Overflow");
   end Overflow_Matches_Parse;

   procedure Corpus_Agrees_With_Parse (T : in out Test_Fixture) is
   begin
      --  Decimal, prefixed and based literals that Parse accepts.
      Assert_Same_As_Parse ("0", "zero");
      Assert_Same_As_Parse ("-0.0", "negative zero");
      Assert_Same_As_Parse ("3.14", "pi-ish");
      Assert_Same_As_Parse ("1e4", "exponent integer");
      Assert_Same_As_Parse ("7e0", "zero exponent");
      Assert_Same_As_Parse ("2.5e0", "zero exponent with fraction");
      Assert_Same_As_Parse ("7E+0", "zero exponent, explicit sign");
      Assert_Same_As_Parse ("1.5e-0_0", "zero exponent with underscore");
      Assert_Same_As_Parse ("-1_000", "signed, underscore");
      Assert_Same_As_Parse ("1_000.000_1e1_0", "underscores everywhere");
      Assert_Same_As_Parse ("0xDEAD_BEEF", "hex");
      Assert_Same_As_Parse ("0XdeAd", "hex mixed");
      Assert_Same_As_Parse ("0xFFe2", "hex with e digit");
      Assert_Same_As_Parse ("0o377", "octal");
      Assert_Same_As_Parse ("0b1010_1010", "binary");
      Assert_Same_As_Parse ("-0x7fffffffffffffff", "negative long hex");
      Assert_Same_As_Parse ("0x7fffffffffffffffff", "hex beyond Long_Long");
      Assert_Same_As_Parse ("2#1010#", "based binary");
      Assert_Same_As_Parse ("16#FF#E2", "based exponent");
      Assert_Same_As_Parse ("16#FF#E+2", "based explicit plus");
      Assert_Same_As_Parse ("16#1#E0", "based zero exponent");
      Assert_Same_As_Parse ("2#1#E8", "binary exponent");
      Assert_Same_As_Parse ("10#5#E3", "base 10 exponent");
      Assert_Same_As_Parse ("-16#FF#E1", "negative based exponent");
      Assert_Same_As_Parse ("16#FF_FF#", "based underscore");
      Assert_Same_As_Parse ("16#1_0#E1_0", "based exponent underscore");
   end Corpus_Agrees_With_Parse;

end Exact_Tests;
