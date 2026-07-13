--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Integer_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Decimal_Positive        (T : in out Test_Fixture);
   procedure Decimal_Negative        (T : in out Test_Fixture);
   procedure Decimal_Explicit_Plus   (T : in out Test_Fixture);
   procedure Hex_Prefix_Lower        (T : in out Test_Fixture);
   procedure Hex_Prefix_Upper        (T : in out Test_Fixture);
   procedure Hex_Mixed_Case          (T : in out Test_Fixture);
   procedure Oct_Prefix              (T : in out Test_Fixture);
   procedure Bin_Prefix              (T : in out Test_Fixture);
   procedure Based_All_Bases         (T : in out Test_Fixture);
   procedure Negative_Prefixed       (T : in out Test_Fixture);
   procedure Negative_Based          (T : in out Test_Fixture);
   procedure Prefix_Trailing_E_As_Hex (T : in out Test_Fixture);
   procedure Big_Integer_Value       (T : in out Test_Fixture);

end Integer_Tests;
