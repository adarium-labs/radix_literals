--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Test_Support; use Test_Support;

package body Float_Tests is

   procedure Simple_Fraction (T : in out Test_Fixture) is
   begin
      Assert_Ok_Float_Approx ("3.14", 3.14, "3.14 approx");
      Assert_Ok_Float_Approx ("0.5", 0.5, "half");
   end Simple_Fraction;

   procedure Positive_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Ok_Float_Approx ("1e4", 1.0e4, "1e4");
      Assert_Ok_Float_Approx ("1E4", 1.0e4, "capital E");
   end Positive_Exponent;

   procedure Signed_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Ok_Float_Approx ("1.5e-3", 1.5e-3, "1.5e-3");
      Assert_Ok_Float_Approx ("2e+2", 200.0, "2e+2");
   end Signed_Exponent;

   procedure Negative_Float (T : in out Test_Fixture) is
   begin
      Assert_Ok_Float_Approx ("-3.14", -3.14, "negative 3.14");
      Assert_Ok_Float_Approx ("-1e2", -100.0, "negative 1e2");
   end Negative_Float;

   procedure Fraction_And_Exp (T : in out Test_Fixture) is
   begin
      Assert_Ok_Any_Float ("6.022e23", "Avogadro-ish");
      Assert_Ok_Float_Approx ("1_000.5", 1_000.5,
                              "grouped whole with fraction");
   end Fraction_And_Exp;

end Float_Tests;
