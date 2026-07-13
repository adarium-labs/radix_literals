--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Radix_Literals;
with Test_Support; use Test_Support;

package body Error_Tests is

   package RL renames Radix_Literals;

   procedure Empty_Input_Case (T : in out Test_Fixture) is
   begin
      Assert_Error ("", RL.Empty_Input, 1, "empty input");
   end Empty_Input_Case;

   procedure Prefix_No_Digits (T : in out Test_Fixture) is
   begin
      Assert_Error ("0x", RL.Empty_Digits, 2, "0x no digits");
      Assert_Error ("0o", RL.Empty_Digits, 2, "0o no digits");
      Assert_Error ("0b", RL.Empty_Digits, 2, "0b no digits");
   end Prefix_No_Digits;

   procedure Based_Empty_Digits (T : in out Test_Fixture) is
   begin
      Assert_Error ("16##", RL.Empty_Digits, 4, "16## empty digits");
   end Based_Empty_Digits;

   procedure Based_Missing_Second_Hash (T : in out Test_Fixture) is
   begin
      Assert_Error ("16#FF", RL.Malformed_Based_Literal, 5,
                    "16#FF no closing #");
   end Based_Missing_Second_Hash;

   procedure Based_Empty_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Error ("16#FF#E", RL.Empty_Digits, 8,
                    "16#FF#E no exponent digits");
   end Based_Empty_Exponent;

   procedure Invalid_Digit_For_Base_Cases (T : in out Test_Fixture) is
   begin
      Assert_Error ("16#G#", RL.Invalid_Digit_For_Base, 4,
                    "G not valid in base 16");
      Assert_Error ("0o8", RL.Invalid_Digit_For_Base, 3,
                    "8 not valid in octal");
      Assert_Error ("0b2", RL.Invalid_Digit_For_Base, 3,
                    "2 not valid in binary");
      Assert_Error ("0xG", RL.Invalid_Digit_For_Base, 3,
                    "G not valid in hex prefix");
   end Invalid_Digit_For_Base_Cases;

   procedure Base_Out_Of_Range_Cases (T : in out Test_Fixture) is
   begin
      Assert_Error ("1#0#", RL.Base_Out_Of_Range, 1,
                    "base 1 too low");
      Assert_Error ("17#0#", RL.Base_Out_Of_Range, 2,
                    "base 17 too high");
   end Base_Out_Of_Range_Cases;

   procedure Based_Real_Rejected (T : in out Test_Fixture) is
      --  Based real literals are out of scope for v0.1.0.  A '.' inside
      --  '#...#' is rejected as Invalid_Character.
   begin
      Assert_Error ("16#F.8#", RL.Invalid_Character, 5,
                    "based real 16#F.8# rejected");
   end Based_Real_Rejected;

   procedure C_Hex_Float_Rejected (T : in out Test_Fixture) is
      --  C hex-float 'p' notation is out of scope.  '.' after the hex
      --  digits terminates the digit run and yields Invalid_Character.
   begin
      Assert_Error ("0x1.8p3", RL.Invalid_Character, 4,
                    "0x1.8p3 rejected");
   end C_Hex_Float_Rejected;

   procedure Empty_Digits_On_Decimal (T : in out Test_Fixture) is
      --  A sign followed by nothing yields Empty_Digits.
   begin
      Assert_Error ("-", RL.Empty_Digits, 2, "just minus");
      Assert_Error ("+", RL.Empty_Digits, 2, "just plus");
   end Empty_Digits_On_Decimal;

end Error_Tests;
