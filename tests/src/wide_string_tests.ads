--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit;
with AUnit.Test_Fixtures;

package Wide_String_Tests is

   type Test_Fixture is
     new AUnit.Test_Fixtures.Test_Fixture with null record;

   procedure Wide_Positive          (T : in out Test_Fixture);
   procedure Wide_Non_Ascii_Rejected (T : in out Test_Fixture);
   procedure Wide_Wide_Positive     (T : in out Test_Fixture);
   procedure Wide_Wide_Non_Ascii_Rejected
     (T : in out Test_Fixture);

end Wide_String_Tests;
