--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Budget_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Big_Denominator_Repros (T : in out Test_Fixture);
   procedure Digit_Budget_Repros (T : in out Test_Fixture);
   procedure Digit_Budget_Boundary (T : in out Test_Fixture);
   procedure Big_Real_Safe_Operations (T : in out Test_Fixture);
   procedure Exponent_Digits_Repros (T : in out Test_Fixture);
   procedure Based_Power_Repros (T : in out Test_Fixture);
   procedure Denominator_Budget_Boundary (T : in out Test_Fixture);
   procedure Budget_Sweep (T : in out Test_Fixture);

end Budget_Tests;
