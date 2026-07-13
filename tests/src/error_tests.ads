--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Error_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Empty_Input_Case          (T : in out Test_Fixture);
   procedure Prefix_No_Digits          (T : in out Test_Fixture);
   procedure Based_Empty_Digits        (T : in out Test_Fixture);
   procedure Based_Missing_Second_Hash (T : in out Test_Fixture);
   procedure Based_Empty_Exponent      (T : in out Test_Fixture);
   procedure Invalid_Digit_For_Base_Cases (T : in out Test_Fixture);
   procedure Base_Out_Of_Range_Cases   (T : in out Test_Fixture);
   procedure Based_Real_Rejected       (T : in out Test_Fixture);
   procedure C_Hex_Float_Rejected      (T : in out Test_Fixture);
   procedure Empty_Digits_On_Decimal   (T : in out Test_Fixture);

end Error_Tests;
