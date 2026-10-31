--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Float_Range_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Overflow_Float_Power (T : in out Test_Fixture);
   procedure Overflow_Float_Product (T : in out Test_Fixture);
   procedure Overflow_Long_Float (T : in out Test_Fixture);
   procedure Overflow_Long_Long_Float (T : in out Test_Fixture);
   procedure Threshold_Edges (T : in out Test_Fixture);
   procedure Decimal_Point_Comma_Class (T : in out Test_Fixture);
   procedure Never_Raises_Sweep (T : in out Test_Fixture);
   procedure Comma_Is_Not_Dropped (T : in out Test_Fixture);

end Float_Range_Tests;
