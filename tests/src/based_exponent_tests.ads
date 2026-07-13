--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Based_Exponent_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Ada_Exponent_Base_16 (T : in out Test_Fixture);
   procedure Ada_Exponent_Base_2  (T : in out Test_Fixture);
   procedure Ada_Exponent_Base_10 (T : in out Test_Fixture);
   procedure Explicit_Plus_Exp    (T : in out Test_Fixture);
   procedure Negative_Exp_Rejected (T : in out Test_Fixture);
   procedure Overflow_Big_Digit_Limit (T : in out Test_Fixture);

end Based_Exponent_Tests;
