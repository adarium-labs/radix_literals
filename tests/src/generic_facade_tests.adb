--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Radix_Literals.Integers;

package body Generic_Facade_Tests is

   package RL renames Radix_Literals;
   use type RL.Parse_Status;
   use type RL.Error_Kind;

   package Int_Parser is new RL.Integers (Target => Integer);

   type Small is range -100 .. 100;
   package Small_Parser is new RL.Integers (Target => Small);

   procedure Integer_Round_Trip (T : in out Test_Fixture) is
      R : constant Int_Parser.Conv_Result :=
        Int_Parser.Parse ("0xdead");
   begin
      Assert (R.Status = RL.Ok, "Integer_Round_Trip: expected Ok");
      Assert (R.Value = 16#DEAD#,
              "Integer_Round_Trip: value mismatch for 0xdead");
   end Integer_Round_Trip;

   procedure Small_Range_In (T : in out Test_Fixture) is
      R  : constant Small_Parser.Conv_Result := Small_Parser.Parse ("42");
      R2 : constant Small_Parser.Conv_Result :=
        Small_Parser.Parse ("-100");
   begin
      Assert (R.Status = RL.Ok, "Small_Range_In: 42 should fit");
      Assert (R.Value = 42, "Small_Range_In: wrong value for 42");
      Assert (R2.Status = RL.Ok, "Small_Range_In: -100 should fit");
      Assert (R2.Value = -100, "Small_Range_In: wrong value for -100");
   end Small_Range_In;

   procedure Small_Range_Out (T : in out Test_Fixture) is
      R : constant Small_Parser.Conv_Result := Small_Parser.Parse ("200");
   begin
      Assert (R.Status = RL.Error,
              "Small_Range_Out: 200 should not fit in -100 .. 100");
      Assert (R.Reason = RL.Overflow,
              "Small_Range_Out: expected Overflow reason");
   end Small_Range_Out;

   procedure Negative_Value (T : in out Test_Fixture) is
      R : constant Int_Parser.Conv_Result := Int_Parser.Parse ("-1_000");
   begin
      Assert (R.Status = RL.Ok, "Negative_Value: expected Ok");
      Assert (R.Value = -1_000,
              "Negative_Value: value mismatch for -1_000");
   end Negative_Value;

   procedure Float_As_Overflow (T : in out Test_Fixture) is
      R : constant Int_Parser.Conv_Result := Int_Parser.Parse ("3.14");
   begin
      Assert (R.Status = RL.Error,
              "Float_As_Overflow: cannot narrow float to Integer");
      Assert (R.Reason = RL.Overflow,
              "Float_As_Overflow: expected Overflow reason");
   end Float_As_Overflow;

   procedure Error_Propagated (T : in out Test_Fixture) is
      R : constant Int_Parser.Conv_Result := Int_Parser.Parse ("0xG");
   begin
      Assert (R.Status = RL.Error,
              "Error_Propagated: expected Error");
      Assert (R.Reason = RL.Invalid_Digit_For_Base,
              "Error_Propagated: expected propagation of parse Reason");
      Assert (R.Position = 3,
              "Error_Propagated: expected propagation of Position");
   end Error_Propagated;

end Generic_Facade_Tests;
