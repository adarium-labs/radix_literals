--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Assertions; use AUnit.Assertions;
with Radix_Literals;
with Test_Support; use Test_Support;

package body Based_Exponent_Tests is

   package RL renames Radix_Literals;
   use type RL.Parse_Status;
   use type RL.Error_Kind;

   procedure Ada_Exponent_Base_16 (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("16#FF#E2", 65_280,
                         "16#FF#E2 = 255 * 16**2");
      Assert_Ok_Integer ("16#1#E0", 1, "16#1#E0 = 1");
      Assert_Ok_Integer ("16#A#E1", 160, "16#A#E1 = 10 * 16");
   end Ada_Exponent_Base_16;

   procedure Ada_Exponent_Base_2 (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("2#1#E8", 256, "2#1#E8 = 1 * 2**8");
      Assert_Ok_Integer ("2#11#E4", 48, "2#11#E4 = 3 * 16");
   end Ada_Exponent_Base_2;

   procedure Ada_Exponent_Base_10 (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("10#5#E3", 5_000, "10#5#E3 = 5 * 1000");
   end Ada_Exponent_Base_10;

   procedure Explicit_Plus_Exp (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("16#FF#E+2", 65_280, "explicit + in exponent");
   end Explicit_Plus_Exp;

   procedure Negative_Exp_Rejected (T : in out Test_Fixture) is
   begin
      Assert_Error ("16#FF#E-1", RL.Unexpected_Exponent, 8,
                    "negative exponent rejected");
   end Negative_Exp_Rejected;

   procedure Overflow_Big_Digit_Limit (T : in out Test_Fixture) is
      --  Vaton rejects values whose whole part exceeds
      --  BIG_NUMBER_DIGIT_LIMIT (1900) digits via Is_Valid_Number,
      --  which the library surfaces as Overflow.
      Big_Length : constant Positive := 2_000;
      Big_Image  : constant String := [1 .. Big_Length => '1'];
      R          : constant RL.Parse_Result := RL.Parse (Big_Image);
   begin
      Assert (R.Status = RL.Error,
              "Overflow_Big_Digit_Limit: expected Error");
      Assert (R.Reason = RL.Overflow,
              "Overflow_Big_Digit_Limit: expected Overflow, got "
              & RL.Error_Kind'Image (R.Reason));
   end Overflow_Big_Digit_Limit;

end Based_Exponent_Tests;
