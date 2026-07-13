--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Reporter.Text;
with AUnit.Run;
with GNAT.OS_Lib;
with Main_Suite;

procedure Tests is
   use type AUnit.Status;
   Reporter : AUnit.Reporter.Text.Text_Reporter;
   function Runner is new AUnit.Run.Test_Runner_With_Status
     (Main_Suite.Suite);
   Status : constant AUnit.Status := Runner (Reporter);
begin
   if Status = AUnit.Success then
      GNAT.OS_Lib.OS_Exit (0);
   else
      GNAT.OS_Lib.OS_Exit (1);
   end if;
end Tests;
