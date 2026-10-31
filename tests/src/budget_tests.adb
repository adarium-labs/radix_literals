--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Exceptions;
with Ada.Strings.Fixed;
with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Ada.Numerics.Big_Numbers.Big_Integers;
with Ada.Numerics.Big_Numbers.Big_Reals;

package body Budget_Tests is

   package RL renames Radix_Literals;
   package BR renames Ada.Numerics.Big_Numbers.Big_Reals;
   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   use type BR.Valid_Big_Real;
   use type BI.Big_Integer;
   use type RL.Parse_Status;

   function Pow10 (K : Natural) return BI.Big_Integer is
      Acc : BI.Big_Integer := BI.To_Big_Integer (1);
   begin
      for I in 1 .. K loop
         Acc := Acc * BI.To_Big_Integer (10);
      end loop;
      return Acc;
   end Pow10;

   function Ones (N : Positive) return String is ([1 .. N => '1']);

   --  "raised <name>" when Parse or Parse_Exact raises, otherwise a
   --  description of the Parse result.
   function Outcome (Image : String) return String is
   begin
      declare
         P : constant RL.Parse_Result := RL.Parse (Image);
      begin
         if P.Status = RL.Ok then
            return "Ok";
         else
            return RL.Error_Kind'Image (P.Reason);
         end if;
      end;
   exception
      when E : others =>
         return "raised " & Ada.Exceptions.Exception_Name (E);
   end Outcome;

   function Exact_Outcome (Image : String) return String is
   begin
      declare
         E : constant RL.Exact_Result := RL.Parse_Exact (Image);
      begin
         if E.Status = RL.Ok then
            return "Ok";
         else
            return RL.Error_Kind'Image (E.Reason);
         end if;
      end;
   exception
      when Ex : others =>
         return "raised " & Ada.Exceptions.Exception_Name (Ex);
   end Exact_Outcome;

   procedure Assert_Outcome (Image, Want : String; Msg : String) is
      Got : constant String := Outcome (Image);
   begin
      Assert (Got = Want,
              Msg & ": Parse of " & Image (Image'First .. Image'First
                       + Natural'Min (Image'Length - 1, 40))
              & "... gave " & Got & ", want " & Want);
   end Assert_Outcome;

   procedure Assert_Exact_Outcome (Image, Want : String; Msg : String) is
      Got : constant String := Exact_Outcome (Image);
   begin
      Assert (Got = Want,
              Msg & ": Parse_Exact gave " & Got & ", want " & Want);
   end Assert_Exact_Outcome;

   --  Consumer-side limit (documented in README and the spec): at the budget
   --  boundary, a Big_Real value itself is exact and "=", Numerator and
   --  Denominator are safe.  Ordering and arithmetic on two such values
   --  cross-multiply their numerators and denominators and can exceed the
   --  capacity: consumers do that from Parse_Exact's (Significand, Scale).
   --  This test does not call those operations.
   procedure Big_Real_Safe_Operations (T : in out Test_Fixture) is
      A : constant RL.Parse_Result :=
        RL.Parse (String'("1.12345678901234567e-1919"));
      B : constant RL.Parse_Result :=
        RL.Parse (String'("2.12345678901234567e-1919"));
      Ra : constant BR.Valid_Big_Real := A.Value.Big_Real;
      Rb : constant BR.Valid_Big_Real := B.Value.Big_Real;
      Den : constant BI.Big_Integer := BR.Denominator (Ra);
   begin
      Assert (A.Status = RL.Ok and then B.Status = RL.Ok,
              "boundary values are Ok");
      Assert (Ra = Ra, "= on a boundary Big_Real");
      Assert (not (Ra = Rb), "= separates two boundary Big_Reals");
      Assert (BR.Numerator (Ra) /= BI.To_Big_Integer (0),
              "Numerator of a boundary Big_Real");
      Assert (Den = Pow10 (1936),
              "Denominator of 1.12345678901234567e-1919 is 10 ** 1936");
   end Big_Real_Safe_Operations;

   --  F1: Vaton's Big_Real branch builds 10 ** (F - E) beyond capacity.
   procedure Big_Denominator_Repros (T : in out Test_Fixture) is
   begin
      Assert_Outcome ("1.123456789012345678e-1919", "OVERFLOW",
                      "F1 repro, denominator 10 ** 1937");
      Assert_Outcome (Ones (37) & "e-1937", "OVERFLOW", "F1: 37 ones e-1937");
      Assert_Outcome (Ones (100) & "e-2000", "OVERFLOW",
                      "F1: 100 ones e-2000");
   end Big_Denominator_Repros;

   --  F2: significand digits materialised before any budget check.
   procedure Digit_Budget_Repros (T : in out Test_Fixture) is
      Long : constant String := Ones (1000) & "." & Ones (1000);
   begin
      Assert_Outcome (Long, "OVERFLOW", "F2 repro, 2000 digits");
      Assert_Exact_Outcome (Long, "OVERFLOW", "F2 repro, 2000 digits");
   end Digit_Budget_Repros;

   --  The digit budget boundary: 1900 significand digits are exact, 1901 are
   --  Overflow (Parse and Parse_Exact alike).
   procedure Digit_Budget_Boundary (T : in out Test_Fixture) is
   begin
      Assert_Outcome (Ones (1900), "Ok", "1900 digits, Parse");
      Assert_Exact_Outcome (Ones (1900), "Ok", "1900 digits");
      Assert_Outcome (Ones (1901), "OVERFLOW", "1901 digits, Parse");
      Assert_Exact_Outcome (Ones (1901), "OVERFLOW", "1901 digits");
      --  Based significands, same limit as the decimal digit budget:
      --  2 ** 6311 - 1 is 1900 digits (Ok); 2 ** 6312 - 1 is 1901 digits
      --  (Overflow).  log10 (2 ** 6312) is about 1900.1.
      Assert_Outcome ("2#" & Ones (6311) & "#", "Ok", "based 1900 digits");
      Assert_Outcome ("2#" & Ones (6312) & "#", "OVERFLOW",
                      "based 1901 digits");
      Assert_Exact_Outcome ("2#" & Ones (6312) & "#", "OVERFLOW",
                            "based 1901 digits, Parse_Exact");
   end Digit_Budget_Boundary;

   --  F3: exponent text accumulated before its digit count is checked.
   procedure Exponent_Digits_Repros (T : in out Test_Fixture) is
   begin
      Assert_Exact_Outcome ("1e" & Ones (3000), "OVERFLOW",
                            "F3 repro, 3000-digit exponent");
      Assert_Outcome ("1e" & Ones (3000), "OVERFLOW",
                      "F3: Parse, 3000-digit exponent");
   end Exponent_Digits_Repros;

   --  F4: Base ** Exponent built without bound (pre-existing).
   procedure Based_Power_Repros (T : in out Test_Fixture) is
   begin
      Assert_Outcome ("2#1#E6432", "OVERFLOW", "F4 repro, 2 ** 6432");
      Assert_Outcome ("16#1#E1609", "OVERFLOW", "F4 repro, 16 ** 1609");
      Assert_Outcome ("2#1#E2147483647", "OVERFLOW",
                      "F4 repro, 2 ** Natural'Last");
      Assert_Exact_Outcome ("2#1#E2147483647", "Ok",
                            "F4: Parse_Exact keeps the exponent as Scale");
   end Based_Power_Repros;

   --  The budget boundary, both sides: denominators of 1936 digits are
   --  exact, 1937 are Overflow (no Storage_Error).
   procedure Denominator_Budget_Boundary (T : in out Test_Fixture) is
   begin
      Assert_Outcome ("1.12345678901234567e-1919", "Ok",
                      "denominator 10 ** 1936 (Vaton Big_Real branch)");
      Assert_Outcome ("1.123456789012345678e-1919", "OVERFLOW",
                      "denominator 10 ** 1937");
      --  Two-digit values stay on Vaton's Long_Long_Float path (unchanged).
      Assert_Outcome ("1.5e-1935", "Ok", "x87 path, unchanged");
      Assert_Outcome ("1.5e-1936", "Ok", "x87 path, unchanged");
   end Denominator_Budget_Boundary;

   --  Every band that raised: no Parse or Parse_Exact may raise.
   procedure Budget_Sweep (T : in out Test_Fixture) is
      Failures : Natural := 0;
      procedure Check (Image : String) is
         O : constant String := Outcome (Image);
         E : constant String := Exact_Outcome (Image);
      begin
         if Ada.Strings.Fixed.Index (O, "raised") /= 0 then
            Failures := Failures + 1;
         end if;
         if Ada.Strings.Fixed.Index (E, "raised") /= 0 then
            Failures := Failures + 1;
         end if;
      end Check;
      Lengths : constant array (1 .. 7) of Positive :=
        [19, 37, 100, 500, 1000, 1900, 2000];
      Long_Lengths : constant array (1 .. 6) of Positive :=
        [19, 1900, 1901, 2000, 3000, 5000];
      Exps : constant array (1 .. 7) of Integer :=
        [-1900, -1919, -1937, -2000, -2500, -3000, -3800];
   begin
      for L of Lengths loop
         for X of Exps loop
            Check (Ones (L) & "e" & Ada.Strings.Fixed.Trim
                     (Integer'Image (X), Ada.Strings.Left));
         end loop;
      end loop;
      for Pair in 1 .. 4 loop
         declare
            W : constant Positive :=
              (case Pair is when 1 => 1, when 2 => 100, when 3 => 1900,
                            when others => 1900);
            F : constant Positive :=
              (case Pair is when 1 => 1900, when 2 => 1900, when 3 => 1900,
                            when others => 1000);
         begin
            Check (Ones (W) & "." & Ones (F) & "e-1919");
            Check (Ones (W) & "." & Ones (F) & "e0");
            Check (Ones (W) & "." & Ones (F) & "e5");
         end;
      end loop;
      for N in 6000 .. 7000 loop
         if N mod 250 = 0 then
            Check ("2#1#E" & Ada.Strings.Fixed.Trim (Integer'Image (N),
                                                      Ada.Strings.Left));
         end if;
      end loop;
      for N in 1500 .. 1700 loop
         if N mod 50 = 0 then
            Check ("16#1#E" & Ada.Strings.Fixed.Trim (Integer'Image (N),
                                                       Ada.Strings.Left));
         end if;
      end loop;
      for L of Long_Lengths loop
         Check ("1e" & Ones (L));
      end loop;
      Assert (Failures = 0,
              "Parse or Parse_Exact raised for" & Natural'Image (Failures)
              & " budget-sweep inputs");
   end Budget_Sweep;

end Budget_Tests;
