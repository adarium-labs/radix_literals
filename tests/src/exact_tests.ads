--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Exact_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Decimal_16_To_18_Digits (T : in out Test_Fixture);
   procedure Decimal_Fraction_And_Exponent (T : in out Test_Fixture);
   procedure Negative_Zero (T : in out Test_Fixture);
   procedure Huge_And_Tiny_Exponents (T : in out Test_Fixture);
   procedure Based_Exact_Forms (T : in out Test_Fixture);
   procedure Based_Exponent_At_Natural_Max (T : in out Test_Fixture);
   procedure Prefixed_Exact_Forms (T : in out Test_Fixture);
   procedure Underscores_And_Signs (T : in out Test_Fixture);
   procedure Decimal_Point_Comma (T : in out Test_Fixture);
   procedure Wide_Overloads (T : in out Test_Fixture);
   procedure Errors_Match_Parse (T : in out Test_Fixture);
   procedure Overflow_Matches_Parse (T : in out Test_Fixture);
   procedure Corpus_Agrees_With_Parse (T : in out Test_Fixture);

end Exact_Tests;
