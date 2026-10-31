--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Characters.Conversions;
with Ada.Text_IO;
with Ada.Numerics.Big_Numbers.Big_Integers;
with Ada.Numerics.Big_Numbers.Big_Reals;
with Ada.Unchecked_Deallocation;
with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Vaton;

package body Bounds_Tests is

   package RL renames Radix_Literals;
   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   package BR renames Ada.Numerics.Big_Numbers.Big_Reals;
   use type BI.Big_Integer;
   use type BR.Valid_Big_Real;
   use type RL.Parse_Status;
   use type RL.Error_Kind;
   use type RL.Parse_Result;
   use type RL.Exact_Result;
   use type Vaton.Number_Kind;

   function Pow10 (K : Natural) return BI.Big_Integer is
      Acc : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      for I in 1 .. K loop
         Acc := Acc * BI.To_Big_Integer (10);
      end loop;
      return Acc;
   end Pow10;

   type Dp_Array is array (Positive range <>) of Wide_Character;

   function Rep (C : Character; N : Natural) return String is
     ([1 .. N => C]);

   function P (Image : String; Dp : Wide_Character := '.')
     return RL.Parse_Result is (RL.Parse (Image, Dp));

   function X (Image : String; Dp : Wide_Character := '.')
     return RL.Exact_Result is (RL.Parse_Exact (Image, Dp));

   function Img (N : Natural) return String is
      S : constant String := Natural'Image (N);
   begin
      return S (S'First + 1 .. S'Last);
   end Img;

   procedure Assert_Parse_Error
     (Image : String; Reason : RL.Error_Kind; Position : Positive;
      Msg : String; Dp : Wide_Character := '.')
   is
      R : constant RL.Parse_Result := RL.Parse (Image, Dp);
   begin
      Assert (R.Status = RL.Error and then R.Reason = Reason
              and then R.Position = Position, Msg & ": Parse " & Image);
   end Assert_Parse_Error;

   procedure Assert_Exact_Error
     (Image : String; Reason : RL.Error_Kind; Position : Positive;
      Msg : String; Dp : Wide_Character := '.')
   is
      R : constant RL.Exact_Result := RL.Parse_Exact (Image, Dp);
   begin
      Assert (R.Status = RL.Error and then R.Reason = Reason
              and then R.Position = Position, Msg & ": Parse_Exact " & Image);
   end Assert_Exact_Error;

   procedure Assert_Exact
     (Image : String; Sig : BI.Big_Integer; Radix : RL.Radix_Range;
      Scale : BI.Big_Integer; Msg : String; Dp : Wide_Character := '.')
   is
      R : constant RL.Exact_Result := RL.Parse_Exact (Image, Dp);
   begin
      Assert (R.Status = RL.Ok, Msg & ": Parse_Exact Ok for " & Image);
      Assert (R.Value.Significand = Sig and then R.Value.Radix = Radix
              and then R.Value.Scale = Scale,
              Msg & ": Parse_Exact value for " & Image);
   end Assert_Exact;

   -----------------------------------------------------------------------
   --  R2: Parse_Exact keeps a based exponent beyond Natural as Scale.
   -----------------------------------------------------------------------

   procedure Exact_Based_Exponent_Beyond_Natural (T : in out Test_Fixture) is
      Two31 : constant BI.Big_Integer := BI.To_Big_Integer (2) ** 31;
      Big_E : constant String := Rep ('9', 1900);
   begin
      Assert_Exact ("2#1#E2147483648", BI.To_Big_Integer (1), 2, Two31,
                    "exponent Natural'Last + 1");
      Assert_Exact ("16#F#E4294967296", BI.To_Big_Integer (15), 16,
                    BI.To_Big_Integer (2) ** 32, "exponent 2 ** 32");
      Assert_Exact ("2#1#E+2_147_483_648", BI.To_Big_Integer (1), 2, Two31,
                    "plus sign and underscores");
      Assert_Exact ("10#0#E99999999999999999999", BI.To_Big_Integer (0), 10,
                    Pow10 (20) - BI.To_Big_Integer (1), "zero significand");
      declare
         R : constant RL.Exact_Result := X ("3#2#E" & Big_E);
      begin
         Assert (R.Status = RL.Ok and then R.Value.Scale = Pow10 (1900)
                   - BI.To_Big_Integer (1),
                 "1900-digit based exponent is exact");
      end;
      Assert_Exact_Error ("3#2#E" & Rep ('9', 1901), RL.Overflow, 1906,
                          "1901-digit based exponent");
      Assert_Exact_Error ("3#2#E" & Rep ('0', 1900) & "1", RL.Overflow, 1906,
                          "1901 digits with leading zeros");
      Assert_Parse_Error ("3#2#E" & Rep ('0', 1900) & "1", RL.Overflow, 1906,
                          "Parse: 1901 exponent digits, leading zeros");
      Assert (P ("3#2#E" & Rep ('0', 1899) & "1").Status = RL.Ok,
              "Parse: 1900 exponent digits are within the budget");
      --  Syntax errors after a huge exponent keep precedence.
      Assert_Exact_Error ("2#1#E2147483648X", RL.Invalid_Character, 16,
                          "junk after the exponent");
      --  Parse keeps its Natural limit.
      Assert_Parse_Error ("2#1#E2147483648", RL.Overflow, 15,
                          "Parse exponent above Natural'Last");
   end Exact_Based_Exponent_Beyond_Natural;

   -----------------------------------------------------------------------
   --  R3: the dropped zero exponent must use the caller's decimal point.
   -----------------------------------------------------------------------

   procedure Zero_Exponent_Uses_Decimal_Point (T : in out Test_Fixture) is
      procedure Check (Image : String; Dp : Wide_Character;
                       Want : Long_Float)
      is
         R : constant RL.Parse_Result := RL.Parse (Image, Dp);
         Msg : constant String := "Parse (" & Image
           & ") with separator code" & Natural'Image (Wide_Character'Pos (Dp));
      begin
         Assert (R.Status = RL.Ok, Msg & ": Ok");
         Assert (R.Value.Kind in Vaton.Float | Vaton.Long_Float
                   | Vaton.Long_Long_Float | Vaton.Big_Real,
                 Msg & ": stays a real, got "
                 & Vaton.Number_Kind'Image (R.Value.Kind));
         case R.Value.Kind is
            when Vaton.Float =>
               Assert (Long_Float (R.Value.Float) = Want, Msg & ": value");
            when Vaton.Long_Float =>
               Assert (R.Value.Long_Float = Want, Msg & ": value");
            when Vaton.Long_Long_Float =>
               Assert (Long_Float (R.Value.Long_Long_Float) = Want,
                       Msg & ": value");
            when others =>
               null;
         end case;
      end Check;
   begin
      for Dp of Dp_Array'(['.', ',', ';', ':', '/',
                            Wide_Character'Val (16#066B#)]) loop
         Check ("7e0", Dp, 7.0);
         Check ("7E+0", Dp, 7.0);
         Check ("-1e-0", Dp, -1.0);
         Check ("+3e00", Dp, 3.0);
         Check ("0e0", Dp, 0.0);
         Check ("-0e-0", Dp, 0.0);
         Check ("1_0e0_0", Dp, 10.0);
      end loop;
      Assert (P ("7e0", ',') = P ("7e0", '.'),
              "same value for ',' and '.'");
      Assert (P ("-1e-0", ',') = P ("-1e-0", '.'),
              "same signed value for ',' and '.'");
      --  A fraction is not synthesised; the separator is still the point.
      Assert (P ("2,5e0", ',') = P ("2.5e0", '.'),
              "fraction with ','");
      Assert_Parse_Error ("2.5e0", RL.Invalid_Character, 2,
                          "'.' is not the separator", ',');
   end Zero_Exponent_Uses_Decimal_Point;

   -----------------------------------------------------------------------
   --  R4: images ending at Positive'Last (no index arithmetic past 'Last).
   --  Each literal is placed in a String / Wide_String / Wide_Wide_String
   --  whose bounds end at Positive'Last; the results must equal those of
   --  the same literal at 1-based bounds, for both entry points.
   -----------------------------------------------------------------------

   procedure Check_At_Last (Lit : String) is
      Y  : constant String (Positive'Last - Lit'Length + 1 .. Positive'Last)
        := Lit;
      Ys : constant String (1 .. Lit'Length) := Lit;
      W  : constant Wide_String := Ada.Characters.Conversions.To_Wide_String
                                     (Lit);
      WW : constant Wide_Wide_String :=
        Ada.Characters.Conversions.To_Wide_Wide_String (Lit);
      YW  : constant Wide_String
        (Positive'Last - Lit'Length + 1 .. Positive'Last) := W;
      YWW : constant Wide_Wide_String
        (Positive'Last - Lit'Length + 1 .. Positive'Last) := WW;
      Want_P : constant RL.Parse_Result := RL.Parse (Ys);
      Want_E : constant RL.Exact_Result := RL.Parse_Exact (Ys);
   begin
      Assert (RL.Parse (Y) = Want_P, "Parse String at Positive'Last: " & Lit);
      Assert (RL.Parse (YW) = Want_P,
              "Parse Wide_String at Positive'Last: " & Lit);
      Assert (RL.Parse (YWW) = Want_P,
              "Parse Wide_Wide_String at Positive'Last: " & Lit);
      Assert (RL.Parse_Exact (Y) = Want_E,
              "Parse_Exact String at Positive'Last: " & Lit);
      Assert (RL.Parse_Exact (YW) = Want_E,
              "Parse_Exact Wide_String at Positive'Last: " & Lit);
      Assert (RL.Parse_Exact (YWW) = Want_E,
              "Parse_Exact Wide_Wide_String at Positive'Last: " & Lit);
   end Check_At_Last;

   procedure Strings_Ending_At_Positive_Last (T : in out Test_Fixture) is
   begin
      Check_At_Last ("-");
      Check_At_Last ("+");
      Check_At_Last ("5");
      Check_At_Last ("-5");
      Check_At_Last ("0x");
      Check_At_Last ("-0x");
      Check_At_Last ("0b");
      Check_At_Last ("0xF");
      Check_At_Last ("0o17");
      Check_At_Last ("0b101");
      Check_At_Last ("1e");
      Check_At_Last ("1e5");
      Check_At_Last ("1e-5");
      Check_At_Last ("1.5");
      Check_At_Last ("1.");
      Check_At_Last ("1e0");
      Check_At_Last ("-1e-0");
      Check_At_Last ("7e0");
      Check_At_Last ("16#");
      Check_At_Last ("16#F");
      Check_At_Last ("16#F#");
      Check_At_Last ("16#F#E");
      Check_At_Last ("16#F#E+");
      Check_At_Last ("16#F#E3");
      Check_At_Last ("2#1#E2147483648");
      Check_At_Last ("#");
      Check_At_Last ("##");
      Check_At_Last ("1#");
      Check_At_Last ("16##");
      Check_At_Last ("1_");
      Check_At_Last ("_1");
      Check_At_Last ("1,5");
      Check_At_Last ("1e5e");
      Check_At_Last ("99999999999999999999e0");
      Check_At_Last ("1e999999999999999999999");
      --  The reported positions are 1-based even then.
      declare
         S : constant String (Positive'Last .. Positive'Last) := "-";
         E : constant String (Positive'Last - 1 .. Positive'Last) := "0x";
      begin
         Assert (RL.Parse (S).Reason = RL.Empty_Digits
                 and then RL.Parse (S).Position = 2, "sign alone: position 2");
         Assert (RL.Parse (E).Reason = RL.Empty_Digits
                 and then RL.Parse (E).Position = 2, "0x: position 2");
         Assert (RL.Parse_Exact (S).Reason = RL.Empty_Digits
                 and then RL.Parse_Exact (E).Reason = RL.Empty_Digits,
                 "Parse_Exact agrees");
      end;
   end Strings_Ending_At_Positive_Last;

   -----------------------------------------------------------------------
   --  R5: no temporary proportional to the input.  Strings of several
   --  million characters, on the heap.
   -----------------------------------------------------------------------

   type String_Access is access String;
   type Wide_Access is access Wide_String;
   type Wide_Wide_Access is access Wide_Wide_String;
   procedure Free is new Ada.Unchecked_Deallocation (String, String_Access);
   procedure Free is new Ada.Unchecked_Deallocation (Wide_String, Wide_Access);
   procedure Free is new Ada.Unchecked_Deallocation
     (Wide_Wide_String, Wide_Wide_Access);

   Huge : constant := 5_000_000;

   function Make (Prefix : String; Fill : Character; Suffix : String := "")
     return String_Access
   is
      Result : constant String_Access :=
        new String (1 .. Prefix'Length + Huge + Suffix'Length);
   begin
      Result (1 .. Prefix'Length) := Prefix;
      for I in Prefix'Length + 1 .. Prefix'Length + Huge loop
         Result (I) := Fill;
      end loop;
      Result (Prefix'Length + Huge + 1 .. Result'Last) := Suffix;
      return Result;
   end Make;

   procedure Check_Huge
     (Prefix : String; Fill : Character; Suffix : String;
      Reason : RL.Error_Kind; Position : Natural; Msg : String)
   is
      S : String_Access := Make (Prefix, Fill, Suffix);
      Pos : constant Positive :=
        (if Position = 0 then S'Length else Position);
      P : constant RL.Parse_Result := RL.Parse (S.all);
      E : constant RL.Exact_Result := RL.Parse_Exact (S.all);
   begin
      Assert (P.Status = RL.Error and then P.Reason = Reason
              and then P.Position = Pos, "Parse: " & Msg);
      Assert (E.Status = RL.Error and then E.Reason = Reason
              and then E.Position = Pos, "Parse_Exact: " & Msg);
      Free (S);
   end Check_Huge;

   procedure Huge_Inputs_Are_Bounded (T : in out Test_Fixture) is
   begin
      Check_Huge ("", '1', "", RL.Overflow, 0, "5M-digit integer");
      Check_Huge ("-", '1', "", RL.Overflow, 0, "5M-digit negative integer");
      Check_Huge ("1.", '1', "", RL.Overflow, 0, "5M-digit fraction");
      Check_Huge ("1e", '1', "", RL.Overflow, 0, "5M-digit exponent");
      Check_Huge ("1e-", '0', "1", RL.Overflow, 0,
                  "5M-digit exponent of zeros");
      Check_Huge ("0x", 'F', "", RL.Overflow, 0, "5M-digit hex");
      Check_Huge ("16#", 'F', "#", RL.Overflow, 0, "5M-digit based");
      Check_Huge ("0b", '1', "", RL.Overflow, 0, "5M-digit binary");
      --  Syntax errors after the budget is exhausted keep precedence.
      Check_Huge ("", '1', "x", RL.Invalid_Character, Huge + 1,
                  "junk after 5M digits");
      Check_Huge ("1e", '1', "_", RL.Bad_Underscore, Huge + 3,
                  "dangling underscore after 5M exponent digits");
      --  Based exponent: Parse stops at the first Natural overflow,
      --  Parse_Exact reads on and finds the digit budget exceeded.
      declare
         S : String_Access := Make ("2#1#E", '1');
      begin
         Assert (RL.Parse (S.all).Reason = RL.Overflow,
                 "Parse: 5M-digit based exponent");
         Assert (RL.Parse_Exact (S.all).Reason = RL.Overflow
                 and then RL.Parse_Exact (S.all).Position = S'Length,
                 "Parse_Exact: 5M-digit based exponent");
         Free (S);
      end;
      --  The same through the Wide_String overloads (no narrowed copy).
      declare
         S : constant String_Access := Make ("", '1');
         W : Wide_Access := new Wide_String (1 .. S'Length);
         WW : Wide_Wide_Access := new Wide_Wide_String (1 .. S'Length);
      begin
         for I in S'Range loop
            W (I) := Wide_Character'Val (Character'Pos (S (I)));
            WW (I) := Wide_Wide_Character'Val (Character'Pos (S (I)));
         end loop;
         Assert (RL.Parse (W.all).Reason = RL.Overflow
                 and then RL.Parse_Exact (W.all).Reason = RL.Overflow,
                 "Wide_String 5M digits");
         Assert (RL.Parse (WW.all).Reason = RL.Overflow
                 and then RL.Parse_Exact (WW.all).Reason = RL.Overflow,
                 "Wide_Wide_String 5M digits");
         W (S'Length) := Wide_Character'Val (16#263A#);
         Assert (RL.Parse (W.all).Reason = RL.Invalid_Character
                 and then RL.Parse (W.all).Position = S'Length,
                 "Wide_String 5M digits then non-ASCII");
         Free (W);
         Free (WW);
         declare
            Mutable : String_Access := S;
         begin
            Free (Mutable);
         end;
      end;
   end Huge_Inputs_Are_Bounded;

   -----------------------------------------------------------------------
   --  R6: the synthetic fraction digit of a dropped zero exponent is not
   --  charged to the digit budget.
   -----------------------------------------------------------------------

   procedure Synthetic_Digit_Not_Charged (T : in out Test_Fixture) is
   begin
      for N in 1898 .. 1900 loop
         declare
            Image : constant String := Rep ('9', N) & "e0";
            P : constant RL.Parse_Result := RL.Parse (Image);
            E : constant RL.Exact_Result := RL.Parse_Exact (Image);
         begin
            Assert (P.Status = RL.Ok,
                    Img (N) & " nines and e0: Parse Ok");
            Assert (E.Status = RL.Ok
                    and then E.Value.Significand
                               = Pow10 (N) - BI.To_Big_Integer (1)
                    and then E.Value.Scale = BI.To_Big_Integer (0),
                    Img (N) & " nines and e0: Parse_Exact Ok");
            Assert (P.Value.Kind = Vaton.Big_Real,
                    Img (N) & " nines and e0 stays a real, got "
                    & Vaton.Number_Kind'Image (P.Value.Kind));
            case P.Value.Kind is
               when Vaton.Big_Integer =>
                  Assert (P.Value.Big_Integer
                            = Pow10 (N) - BI.To_Big_Integer (1),
                          "value of " & Img (N) & " nines");
               when Vaton.Big_Real =>
                  Assert (BR.Numerator (P.Value.Big_Real)
                            = Pow10 (N) - BI.To_Big_Integer (1)
                          and then BR.Denominator (P.Value.Big_Real)
                            = BI.To_Big_Integer (1),
                          "value of " & Img (N) & " nines");
               when others =>
                  Assert (False, "kind of " & Img (N) & " nines and e0");
            end case;
         end;
      end loop;
      --  Real digits are charged: one more is Overflow, as before.
      Assert_Parse_Error (Rep ('9', 1901) & "e0", RL.Overflow, 1903,
                          "1901 nines");
      Assert_Exact_Error (Rep ('9', 1901) & "e0", RL.Overflow, 1903,
                          "1901 nines");
   end Synthetic_Digit_Not_Charged;

   -----------------------------------------------------------------------
   --  A limit never hides a syntax error: the whole literal is validated
   --  first, then Overflow is reported; Parse and Parse_Exact agree.
   -----------------------------------------------------------------------

   procedure Both_Error
     (Image : String; Reason : RL.Error_Kind; Position : Positive)
   is
   begin
      Assert_Parse_Error (Image, Reason, Position, "syntax before limit");
      Assert_Exact_Error (Image, Reason, Position, "syntax before limit");
   end Both_Error;

   procedure Syntax_Before_Limits (T : in out Test_Fixture) is
   begin
      Both_Error ("2#1#E2147483648X", RL.Invalid_Character, 16);
      Both_Error ("2#1#E2147483648_", RL.Bad_Underscore, 16);
      Both_Error ("2#1#E2147483648_1X", RL.Invalid_Character, 18);
      Both_Error ("2#1#E99999999999999999999.", RL.Invalid_Character, 26);
      Both_Error (Rep ('1', 1901) & "x", RL.Invalid_Character, 1902);
      Both_Error (Rep ('1', 1901) & "_", RL.Bad_Underscore, 1902);
      Both_Error ("1." & Rep ('1', 1901) & "_", RL.Bad_Underscore, 1904);
      Both_Error ("1e" & Rep ('9', 1901) & "x", RL.Invalid_Character, 1904);
      Both_Error ("1e" & Rep ('9', 1901) & "_", RL.Bad_Underscore, 1904);
      Both_Error ("1e-" & Rep ('9', 1901) & "e", RL.Invalid_Character, 1905);
      Both_Error ("3#2#E" & Rep ('0', 1901) & "1X", RL.Invalid_Character,
                  1908);
      Both_Error ("16#" & Rep ('F', 2000) & "#X", RL.Malformed_Based_Literal,
                  2005);
      Both_Error ("16#" & Rep ('F', 2000) & "G#", RL.Invalid_Digit_For_Base,
                  2004);
      Both_Error ("0x" & Rep ('F', 2000) & "G", RL.Invalid_Digit_For_Base,
                  2003);
      --  Without the syntax error, the limit is reported at end of input.
      Assert_Parse_Error ("2#1#E2147483648", RL.Overflow, 15, "limit");
      Assert_Parse_Error (Rep ('1', 1901), RL.Overflow, 1901, "limit");
      Assert_Exact_Error (Rep ('1', 1901), RL.Overflow, 1901, "limit");
   end Syntax_Before_Limits;

   -----------------------------------------------------------------------
   --  Leading zeros and long exponents never reach Vaton unnormalised.
   -----------------------------------------------------------------------

   procedure Leading_Zeros_Are_Normalised (T : in out Test_Fixture) is
      procedure Same (Zeros, Plain : String) is
      begin
         Assert (P (Zeros).Status = RL.Ok, "Parse Ok for " & Zeros);
         Assert (P (Zeros) = P (Plain), "Parse " & Zeros & " = " & Plain);
         Assert (X (Zeros).Status = RL.Ok, "Parse_Exact Ok for " & Zeros);
      end Same;
   begin
      Same ("007", "7");
      Same ("-007", "-7");
      Same ("+007", "7");
      Same ("000", "0");
      Same ("-000", "0");
      Same ("0_0_7", "7");
      Same ("00.5", "0.5");
      Same ("-00.5", "-0.5");
      Same ("000.50", "0.50");
      Same ("00e5", "0e5");
      Same ("007e2", "7e2");
      Same ("0_07.5e1", "7.5e1");
      Same ("1e007", "1e7");
      Same ("1e-007", "1e-7");
      Same ("1e0000000007", "1e7");
      Same ("1.5e0000000000", "1.5");
      Same ("0e0000000003", "0e3");
      Assert_Exact ("007", BI.To_Big_Integer (7), 10, BI.To_Big_Integer (0),
                    "Parse_Exact leading zeros");
      Assert_Exact ("00.50", BI.To_Big_Integer (50), 10,
                    BI.To_Big_Integer (-2), "Parse_Exact leading zeros");
      Assert (P ("007").Value.Kind = Vaton.Integer
              and then P ("007").Value.Integer = 7, "007 is the Integer 7");
      --  An exponent of 8 or more significant digits is beyond every budget.
      Assert (P ("0e99999999").Status = RL.Ok
              and then P ("0e99999999").Value.Kind = Vaton.Big_Real
              and then BR.Numerator (P ("0e99999999").Value.Big_Real)
                         = BI.To_Big_Integer (0), "zero with a huge exponent");
      Assert_Parse_Error ("1e99999999", RL.Overflow, 10, "exponent 10 ** 8");
      Assert_Parse_Error ("1.5e-99999999", RL.Overflow, 13,
                          "exponent -10 ** 8");
      Assert_Parse_Error ("1e00099999999", RL.Overflow, 13,
                          "exponent 10 ** 8 with leading zeros");
      Assert_Exact ("1e99999999", BI.To_Big_Integer (1), 10,
                    BI.To_Big_Integer (99999999), "Parse_Exact huge exponent");
      Both_Error ("1e99999999X", RL.Invalid_Character, 11);
      --  A based value with an exponent keeps the kind Vaton picks from the
      --  number of decimal digits (7 -> Integer, 15 -> Long_Integer, more ->
      --  Big_Integer), whatever the value.
      Assert (P ("16#F#E3").Value.Kind = Vaton.Integer, "5 digits: Integer");
      Assert (P ("7#6_21#E+7").Value.Kind = Vaton.Long_Integer,
              "9 digits: Long_Integer");
      Assert (P ("9#1328742_018#e8").Value.Kind = Vaton.Big_Integer,
              "17 digits: Big_Integer");
      Assert (P ("-16#FFFFFFFFFFFF#E1").Value.Kind = Vaton.Big_Integer,
              "16 digits, negative: Big_Integer");

      --  The kind Vaton picks for an integer of N digits, from 'Size.
      declare
         function Expected (Digit_Count : Positive) return Vaton.Number_Kind is
           (if Digit_Count * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                 < Standard.Integer'Size
            then Vaton.Integer
            elsif Digit_Count * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                    < Standard.Long_Integer'Size
            then Vaton.Long_Integer
            elsif Digit_Count * Vaton.BASE_10_LENGTH_TO_BIT_SIZE
                    < Standard.Long_Long_Integer'Size
            then Vaton.Long_Long_Integer
            else Vaton.Big_Integer);
      begin
         for Digit_Count in 1 .. 18 loop
            declare
               --  10#1#E<k> has Digit_Count digits when k = Digit_Count - 1.
               Image : constant String :=
                 "10#1#E" & Img (Digit_Count - 1);
               R : constant RL.Parse_Result := P (Image);
               Vaton_Via_Decimal : constant RL.Parse_Result :=
                 P ("1" & Rep ('0', Digit_Count - 1));
            begin
               Assert (R.Status = RL.Ok, Image & " Ok");
               Assert (R.Value.Kind = Expected (Digit_Count),
                       Image & ": kind from the digit count, got "
                       & Vaton.Number_Kind'Image (R.Value.Kind));
               Assert (R = Vaton_Via_Decimal,
                       Image & " = the decimal literal Vaton builds");
            end;
         end loop;
      end;
   end Leading_Zeros_Are_Normalised;

   -----------------------------------------------------------------------
   --  No leak: Vaton's digit arrays are freed on every path.  Resident
   --  memory (Linux /proc/self/statm) must not grow with the number of calls
   --  (it grew by about 62 bytes per decimal call before).
   -----------------------------------------------------------------------

   function Resident_Pages return Long_Integer is
      F : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "/proc/self/statm");
      declare
         Line  : constant String := Ada.Text_IO.Get_Line (F);
         Space : Natural := Line'First;
      begin
         Ada.Text_IO.Close (F);
         while Line (Space) /= ' ' loop
            Space := Space + 1;
         end loop;
         declare
            Stop : Natural := Space + 1;
         begin
            while Stop <= Line'Last and then Line (Stop) /= ' ' loop
               Stop := Stop + 1;
            end loop;
            return Long_Integer'Value (Line (Space + 1 .. Stop - 1));
         end;
      end;
   exception
      when others => return -1;
   end Resident_Pages;

   procedure No_Digit_Array_Leak (T : in out Test_Fixture) is
      Calls : constant := 300_000;
      Before, After : Long_Integer;
      Sink : Natural := 0;
   begin
      for I in 1 .. 1_000 loop   --  warm up
         Sink := Sink + Boolean'Pos (P ("1.5").Status = RL.Ok);
      end loop;
      Before := Resident_Pages;
      if Before < 0 then
         return;   --  no /proc: nothing to measure
      end if;
      for I in 1 .. Calls loop
         Sink := Sink + Boolean'Pos (P ("1.5").Status = RL.Ok)
                      + Boolean'Pos (X ("1.5").Status = RL.Ok)
                      + Boolean'Pos (P ("1.5.5").Status = RL.Ok)
                      + Boolean'Pos (X ("12345678901234567890e3").Status
                                     = RL.Ok);
      end loop;
      After := Resident_Pages;
      --  A leak of 62 bytes per call would be about 18,000 pages here.
      Assert (After - Before < 2_000,
              "resident memory grew by" & Long_Integer'Image (After - Before)
              & " pages over" & Natural'Image (4 * Calls) & " calls ("
              & Natural'Image (Sink) & ")");
   end No_Digit_Array_Leak;

   -----------------------------------------------------------------------
   --  R7: the numerator of an exact Big_Real is bounded by 10 ** 1936 (the
   --  same bound as the denominator), measured on the actual value.
   -----------------------------------------------------------------------

   procedure Assert_Real
     (Image : String; Num, Den : BI.Big_Integer; Msg : String)
   is
      P : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Assert (P.Status = RL.Ok, Msg & ": Parse Ok for " & Image);
      Assert (P.Value.Kind = Vaton.Big_Real, Msg & ": Big_Real " & Image);
      Assert (BR.Numerator (P.Value.Big_Real) = Num
              and then BR.Denominator (P.Value.Big_Real) = Den,
              Msg & ": exact value of " & Image);
   end Assert_Real;

   --  Sig * 10 ** Scale written with an 18-digit fraction, so that the
   --  literal has 19 digits and takes the exact fallback (not a float kind).
   function Lit (Sig : String; Scale : Natural; Sign : String := "")
     return String is
     (Sign & "0." & Rep ('0', 18 - Sig'Length) & Sig & "e" & Img (Scale + 18));

   procedure Positive_Scale_Boundary (T : in out Test_Fixture) is
      One : constant BI.Big_Integer := BI.To_Big_Integer (1);
      Max : constant BI.Big_Integer := Pow10 (1936);
   begin
      Assert (Lit ("1", 1936) = "0.000000000000000001e1954", "literal form");
      Assert_Real ("0.000000000000000001e1954", Max, One, "documented max");
      Assert_Real (Lit ("1", 1936, "-"), -Max, One,
                   "documented max, negative");
      Assert_Real (Lit ("10", 1935), Max, One, "10 * 10 ** 1935");
      Assert_Real (Lit ("100000000000000000", 1919), Max, One,
                   "10 ** 17 * 10 ** 1919");
      Assert_Real (Lit ("9", 1935), BI.To_Big_Integer (9) * Pow10 (1935), One,
                   "below the maximum");
      Assert_Real (Lit ("99", 1934), BI.To_Big_Integer (99) * Pow10 (1934),
                   One, "below the maximum");
      Assert_Real (Lit ("999999999999999999", 1918),
                   (Pow10 (18) - One) * Pow10 (1918), One,
                   "below the maximum, 18 digits");
      Assert_Parse_Error (Lit ("2", 1936), RL.Overflow, 25,
                          "above the maximum");
      Assert_Parse_Error (Lit ("11", 1935), RL.Overflow, 25,
                          "above the maximum");
      Assert_Parse_Error (Lit ("1", 1937), RL.Overflow, 25,
                          "above the maximum");
      Assert_Parse_Error (Lit ("100000000000000001", 1919), RL.Overflow, 25,
                          "just above the maximum, 18 digits");
      Assert_Parse_Error (Lit ("123456789012345678", 1919), RL.Overflow, 25,
                          "above the maximum, 18 digits");
      Assert_Parse_Error (Lit ("2", 1936, "-"), RL.Overflow, 26,
                          "above the maximum, negative");
      --  Parse_Exact never overflows on scale.
      Assert_Exact (Lit ("2", 1936), BI.To_Big_Integer (2), 10,
                    BI.To_Big_Integer (1936),
                    "exact above the maximum");
      --  The Big_Real is safe to compare for equality.
      declare
         A : constant RL.Parse_Result := P (Lit ("1", 1936));
         B : constant RL.Parse_Result := P (Lit ("10", 1935));
      begin
         Assert (A.Value.Big_Real = B.Value.Big_Real, "same exact value");
      end;
   end Positive_Scale_Boundary;

   -----------------------------------------------------------------------
   --  R9: decimal points that are also format delimiters are refused.
   -----------------------------------------------------------------------

   procedure Format_Delimiter_Decimal_Points (T : in out Test_Fixture) is
   begin
      for Dp of Dp_Array'(['#', 'x', 'X', 'o', 'O', 'b', 'B']) loop
         Assert_Parse_Error ("15", RL.Invalid_Character, 1,
                             "delimiter as decimal point", Dp);
         Assert_Exact_Error ("15", RL.Invalid_Character, 1,
                             "delimiter as decimal point", Dp);
         Assert_Parse_Error ("-1e5", RL.Invalid_Character, 1,
                             "delimiter as decimal point", Dp);
         Assert_Exact_Error ("1.5", RL.Invalid_Character, 1,
                             "delimiter as decimal point", Dp);
         --  The other formats never use the decimal point.
         Assert (P ("0x1F", Dp).Status = RL.Ok
                 and then P ("2#101#", Dp).Status = RL.Ok
                 and then P ("0b101", Dp).Status = RL.Ok
                 and then P ("0o17", Dp).Status = RL.Ok,
                 "prefixed and based literals are unaffected");
         Assert (X ("16#F#E2", Dp).Status = RL.Ok,
                 "Parse_Exact based literal is unaffected");
      end loop;
      --  The ambiguous literal is a based literal, whatever the separator.
      Assert_Parse_Error ("1#5", RL.Base_Out_Of_Range, 1,
                          "1#5 is a based literal", '#');
      Assert_Parse_Error ("1#5", RL.Base_Out_Of_Range, 1,
                          "1#5 is a based literal", '.');
   end Format_Delimiter_Decimal_Points;

end Bounds_Tests;
