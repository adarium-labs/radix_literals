--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Integers;
with Ada.Numerics.Big_Numbers.Big_Reals;
with Ada.Strings.Fixed;
with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Vaton;

package body Float_Range_Tests is

   package RL renames Radix_Literals;
   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   package BR renames Ada.Numerics.Big_Numbers.Big_Reals;
   use type RL.Parse_Status;
   use type RL.Error_Kind;
   use type Vaton.Number_Kind;
   use type BR.Valid_Big_Real;
   use type BI.Big_Integer;

   function Pow10 (N : Natural) return BI.Big_Integer is
      Acc : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      for I in 1 .. N loop
         Acc := Acc * BI.To_Big_Integer (10);
      end loop;
      return Acc;
   end Pow10;

   --  Sig * 10 ** Scale as a Big_Real, exactly (Scale may be negative).
   function Exact_Real (Sig : Natural; Scale : Integer; Neg : Boolean)
     return BR.Valid_Big_Real
   is
      Num : BI.Big_Integer := BI.To_Big_Integer (Sig);
      Den : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      if Scale >= 0 then
         Num := Num * Pow10 (Scale);
      else
         Den := Pow10 (-Scale);
      end if;
      if Neg then
         Num := -Num;
      end if;
      return BR.To_Big_Real (Num) / BR.To_Big_Real (Den);
   end Exact_Real;

   --  Parse gives the exact Big_Real of Sig * 10 ** Scale.
   procedure Assert_Big_Real
     (Image : String; Sig : Natural; Scale : Integer; Neg : Boolean;
      Msg : String)
   is
      P : constant RL.Parse_Result := RL.Parse (Image);
      E : constant RL.Exact_Result := RL.Parse_Exact (Image);
   begin
      Assert (P.Status = RL.Ok and then P.Value.Kind = Vaton.Big_Real,
              Msg & ": Parse must be Ok Big_Real for " & Image);
      Assert (P.Value.Big_Real = Exact_Real (Sig, Scale, Neg),
              Msg & ": Big_Real must be the exact value of " & Image);
      Assert (E.Status = RL.Ok and then E.Value.Negative = Neg
              and then Ada.Strings.Fixed.Trim
                         (BI.To_String (E.Value.Scale, Width => 0),
                          Ada.Strings.Both)
                       = Ada.Strings.Fixed.Trim (Integer'Image (Scale),
                                                 Ada.Strings.Both),
              Msg & ": Parse_Exact must be Ok with the same scale for "
              & Image);
   end Assert_Big_Real;

   --  Parse returns Overflow at the end of input; Parse_Exact gives the
   --  exact value (Scale must be Scale_Image, Significand Sig_Image).
   procedure Assert_Budget_Overflow
     (Image : String; Scale_Image : String; Msg : String)
   is
      P : constant RL.Parse_Result := RL.Parse (Image);
      E : constant RL.Exact_Result := RL.Parse_Exact (Image);
   begin
      Assert (P.Status = RL.Error and then P.Reason = RL.Overflow
              and then P.Position = Image'Length,
              Msg & ": Parse must be Overflow at end for " & Image);
      Assert (E.Status = RL.Ok, Msg & ": Parse_Exact must be Ok for " & Image);
      Assert (Ada.Strings.Fixed.Trim (BI.To_String (E.Value.Scale, Width => 0),
                                      Ada.Strings.Both) = Scale_Image,
              Msg & ": Parse_Exact Scale for " & Image);
   end Assert_Budget_Overflow;

   procedure Assert_Ok_Kind (Image : String; Kind : Vaton.Number_Kind;
                             Msg : String)
   is
      P : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Assert (P.Status = RL.Ok and then P.Value.Kind = Kind,
              Msg & ": Parse must be Ok " & Vaton.Number_Kind'Image (Kind)
              & " for " & Image);
   end Assert_Ok_Kind;

   --  The power 10 ** Exponent is not representable in Float: exact
   --  Big_Real from Parse, exact value from Parse_Exact.
   procedure Overflow_Float_Power (T : in out Test_Fixture) is
   begin
      Assert_Big_Real ("1e40", 1, 40, False, "Float power");
      Assert_Big_Real ("1E43", 1, 43, False, "Float power, upper E");
      Assert_Big_Real ("0e39", 0, 39, False, "zero mantissa, power 39");
      Assert_Big_Real ("0.0e39", 0, 38, False, "zero with fraction");
      Assert_Big_Real ("-501E41", 501, 41, True, "negative, three digits");
   end Overflow_Float_Power;

   --  The product exceeds Float'Last / 2: an exact Big_Real, never rounded.
   procedure Overflow_Float_Product (T : in out Test_Fixture) is
   begin
      Assert_Big_Real ("8e39", 8, 39, False, "product above Float range");
      Assert_Big_Real ("3.4e38", 34, 37, False,
                       "3.4e38 is below Float'Last, above the Float limit");
      Assert_Big_Real ("17015e34", 17015, 34, False,
                       "first 5-digit value above the Float limit");
      Assert_Big_Real ("-3.4e38", 34, 37, True, "negative, same class");
   end Overflow_Float_Product;

   procedure Overflow_Long_Float (T : in out Test_Fixture) is
   begin
      Assert_Big_Real ("1e308", 1, 308, False, "Long_Float power and product");
      Assert_Big_Real ("9e307", 9, 307, False,
                       "Long_Float product above limit");
      Assert_Big_Real ("1e309", 1, 309, False, "Long_Float power");
   end Overflow_Long_Float;

   --  Beyond the 1900-digit budget: Parse returns Overflow, Parse_Exact the
   --  exact value.
   procedure Overflow_Long_Long_Float (T : in out Test_Fixture) is
   begin
      Assert_Budget_Overflow ("1e4932", "4932", "x87 power beyond budget");
      Assert_Budget_Overflow ("6e4931", "4931", "x87 product beyond budget");
      Assert_Budget_Overflow ("59486574767861589e4915", "4915",
                              "x87: just above the limit, beyond budget");
   end Overflow_Long_Long_Float;

   --  Values below the limits are unchanged: same kind as before.
   procedure Threshold_Edges (T : in out Test_Fixture) is
   begin
      Assert_Ok_Kind ("1.7014e38", Vaton.Float, "Float, below limit");
      Assert_Ok_Kind ("17014e34", Vaton.Float, "Float, 5 digits below limit");
      Assert_Ok_Kind ("1.70142e38", Vaton.Long_Float,
                      "6 digits: Long_Float takes over");
      Assert_Ok_Kind ("9.9943E+36", Vaton.Float, "representative, accepted");
      Assert_Ok_Kind ("1e38", Vaton.Float, "power still in range");
      Assert_Ok_Kind ("1.0e-38", Vaton.Float, "negative exponent");
   end Threshold_Edges;

   --  With ',' as the separator, '.' is not part of a literal and ',' is
   --  the fraction point.
   procedure Decimal_Point_Comma_Class (T : in out Test_Fixture) is
      Dot   : constant RL.Parse_Result :=
        RL.Parse (String'("9.9943E+36"), '.');
      Comma : constant RL.Parse_Result :=
        RL.Parse (String'("9,9943E+36"), ',');
      Bad   : constant RL.Parse_Result :=
        RL.Parse (String'("9.9943E+36"), ',');
   begin
      Assert (Dot.Status = RL.Ok and then Dot.Value.Kind = Vaton.Float,
              "dot separator: 9.9943E+36 is Float");
      Assert (Comma.Status = RL.Ok and then Comma.Value.Kind = Vaton.Float,
              "comma separator: 9,9943E+36 is Float");
      Assert (Bad.Status = RL.Error and then Bad.Reason = RL.Invalid_Character
              and then Bad.Position = 2,
              "comma separator: '.' is Invalid_Character at 2");
   end Decimal_Point_Comma_Class;

   --  Regression for the silent wrong value: with ',' the literal 1,5 is
   --  1.5 (it was 15 when the separator was dropped).
   procedure Comma_Is_Not_Dropped (T : in out Test_Fixture) is
      P : constant RL.Parse_Result := RL.Parse (String'("1,5"), ',');
   begin
      Assert (P.Status = RL.Ok and then P.Value.Kind = Vaton.Float
              and then P.Value.Float = 1.5,
              "Decimal_Point ',': 1,5 is the Float 1.5");
   end Comma_Is_Not_Dropped;

   function Img (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Left));

   --  True when Parse or Parse_Exact raises for Image.
   function Raises (Image : String; Sep : Wide_Character) return Boolean is
   begin
      declare
         P : constant RL.Parse_Result := RL.Parse (Image, Sep);
         E : constant RL.Exact_Result := RL.Parse_Exact (Image, Sep);
         pragma Unreferenced (P, E);
      begin
         return False;
      end;
   exception
      when others => return True;
   end Raises;

   --  Sweeps one mantissa over exponents of every band and both signs.
   procedure Sweep_Mantissa (M : String; Failures : in out Natural) is
   begin
      for N in 0 .. 330 loop
         if Raises (M & "e" & Img (N), '.') then
            Failures := Failures + 1;
         end if;
         if Raises (M & "e-" & Img (N), '.') then
            Failures := Failures + 1;
         end if;
      end loop;
      for N in 4900 .. 4940 loop
         if Raises (M & "e" & Img (N), '.')
           or else Raises (M & "e" & Img (N), ',')
         then
            Failures := Failures + 1;
         end if;
      end loop;
   end Sweep_Mantissa;

   procedure Never_Raises_Sweep (T : in out Test_Fixture) is
      Failures : Natural := 0;
   begin
      Sweep_Mantissa ("1", Failures);
      Sweep_Mantissa ("9", Failures);
      Sweep_Mantissa ("3.4", Failures);
      Sweep_Mantissa ("59486574767861589", Failures);
      Sweep_Mantissa ("0", Failures);
      Sweep_Mantissa ("0.5", Failures);
      Assert (Failures = 0,
              "Parse/Parse_Exact raised for" & Natural'Image (Failures)
              & " sweep inputs");
   end Never_Raises_Sweep;

end Float_Range_Tests;
