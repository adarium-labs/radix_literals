--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Float_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Simple_Fraction     (T : in out Test_Fixture);
   procedure Positive_Exponent   (T : in out Test_Fixture);
   procedure Signed_Exponent     (T : in out Test_Fixture);
   procedure Negative_Float      (T : in out Test_Fixture);
   procedure Fraction_And_Exp    (T : in out Test_Fixture);

end Float_Tests;
