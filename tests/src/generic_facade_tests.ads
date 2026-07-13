--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Generic_Facade_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Integer_Round_Trip  (T : in out Test_Fixture);
   procedure Small_Range_In      (T : in out Test_Fixture);
   procedure Small_Range_Out     (T : in out Test_Fixture);
   procedure Negative_Value      (T : in out Test_Fixture);
   procedure Float_As_Overflow   (T : in out Test_Fixture);
   procedure Error_Propagated    (T : in out Test_Fixture);

end Generic_Facade_Tests;
