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

   --  x * 10**0 = x. Vaton's Big_Real path (more significant digits than
   --  Long_Long_Float'Digits: 15 on aarch64, 18 on x86_64) returns 1 for an
   --  explicit zero exponent, dropping both value and sign. The 20+ digit
   --  cases below take that path on every platform.
   procedure Zero_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Ok_Float_Approx ("2.5e0", 2.5, "fraction, e0");
      Assert_Ok_Float_Approx ("2.5E+0", 2.5, "fraction, E+0");
      Assert_Ok_Float_Approx ("2.5e-0_0", 2.5, "fraction, grouped e-00");
      Assert_Ok_Float_Approx ("7e0", 7.0, "no fraction stays a float");
      Assert_Ok_Float_Approx
        ("3.14159265358979323846e0", 3.14159265358979323846,
         "Big_Real path, fraction, e0");
      Assert_Ok_Float_Approx
        ("-12345678901234567890.5e0", -12345678901234567890.5,
         "Big_Real path keeps the sign");
      Assert_Ok_Float_Approx
        ("12345678901234567890e+00", 12345678901234567890.0,
         "Big_Real path, no fraction");
      Assert_Ok_Float_Approx
        ("1.2345678901234567890123e2", 123.45678901234567890123,
         "Big_Real path, non-zero exponent still applied");
   end Zero_Exponent;

end Float_Tests;
