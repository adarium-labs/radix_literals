--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Vaton;

package body Wide_String_Tests is

   package RL renames Radix_Literals;
   use type RL.Parse_Status;
   use type RL.Error_Kind;
   use type Vaton.Number_Kind;

   procedure Wide_Positive (T : in out Test_Fixture) is
      W : constant Wide_String := "42";
      R : constant RL.Parse_Result := RL.Parse (W);
   begin
      Assert (R.Status = RL.Ok, "Wide_Positive: expected Ok");
      Assert (R.Value.Kind = Vaton.Integer,
              "Wide_Positive: expected Integer kind");
      Assert (R.Value.Integer = 42, "Wide_Positive: expected 42");
   end Wide_Positive;

   procedure Wide_Non_Ascii_Rejected (T : in out Test_Fixture) is
      Non_Ascii : constant Wide_Character := Wide_Character'Val (16#00E9#);
      W : constant Wide_String := "42" & Non_Ascii;
      R : constant RL.Parse_Result := RL.Parse (W);
   begin
      Assert (R.Status = RL.Error,
              "Wide_Non_Ascii_Rejected: expected Error");
      Assert (R.Reason = RL.Invalid_Character,
              "Wide_Non_Ascii_Rejected: expected Invalid_Character");
      Assert (R.Position = 3,
              "Wide_Non_Ascii_Rejected: expected position 3");
   end Wide_Non_Ascii_Rejected;

   procedure Wide_Wide_Positive (T : in out Test_Fixture) is
      W : constant Wide_Wide_String := "0xFF";
      R : constant RL.Parse_Result := RL.Parse (W);
   begin
      Assert (R.Status = RL.Ok, "Wide_Wide_Positive: expected Ok");
      Assert (R.Value.Kind = Vaton.Integer,
              "Wide_Wide_Positive: expected Integer");
      Assert (R.Value.Integer = 255,
              "Wide_Wide_Positive: expected 255");
   end Wide_Wide_Positive;

   procedure Wide_Wide_Non_Ascii_Rejected
     (T : in out Test_Fixture)
   is
      Non_Ascii : constant Wide_Wide_Character :=
        Wide_Wide_Character'Val (16#0001_F600#);
      W : constant Wide_Wide_String := "1" & Non_Ascii;
      R : constant RL.Parse_Result := RL.Parse (W);
   begin
      Assert (R.Status = RL.Error,
              "Wide_Wide_Non_Ascii_Rejected: expected Error");
      Assert (R.Reason = RL.Invalid_Character,
              "Wide_Wide_Non_Ascii_Rejected: Invalid_Character");
      Assert (R.Position = 2,
              "Wide_Wide_Non_Ascii_Rejected: expected position 2");
   end Wide_Wide_Non_Ascii_Rejected;

end Wide_String_Tests;
