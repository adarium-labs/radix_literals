--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Underscore_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Valid_Underscores      (T : in out Test_Fixture);
   procedure Leading_Underscore     (T : in out Test_Fixture);
   procedure Trailing_Underscore    (T : in out Test_Fixture);
   procedure Doubled_Underscore     (T : in out Test_Fixture);
   procedure Adjacent_To_Prefix     (T : in out Test_Fixture);
   procedure Adjacent_To_Hash       (T : in out Test_Fixture);
   procedure Adjacent_To_Dot        (T : in out Test_Fixture);
   procedure Underscore_In_Exponent (T : in out Test_Fixture);

end Underscore_Tests;
