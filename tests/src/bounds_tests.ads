--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Bounds_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Exact_Based_Exponent_Beyond_Natural (T : in out Test_Fixture);
   procedure Zero_Exponent_Uses_Decimal_Point (T : in out Test_Fixture);
   procedure Strings_Ending_At_Positive_Last (T : in out Test_Fixture);
   procedure Huge_Inputs_Are_Bounded (T : in out Test_Fixture);
   procedure Synthetic_Digit_Not_Charged (T : in out Test_Fixture);
   procedure Syntax_Before_Limits (T : in out Test_Fixture);
   procedure Leading_Zeros_Are_Normalised (T : in out Test_Fixture);
   procedure No_Digit_Array_Leak (T : in out Test_Fixture);
   procedure Positive_Scale_Boundary (T : in out Test_Fixture);
   procedure Format_Delimiter_Decimal_Points (T : in out Test_Fixture);

end Bounds_Tests;
