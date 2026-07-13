--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Radix_Literals;
with Test_Support; use Test_Support;

package body Underscore_Tests is

   package RL renames Radix_Literals;

   procedure Valid_Underscores (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("1_000", 1000, "decimal grouped");
      Assert_Ok_Integer ("1_000_000", 1_000_000,
                         "multiple decimal groups");
      Assert_Ok_Integer ("0xFF_00", 16#FF00#, "hex grouped");
      Assert_Ok_Integer ("16#DEAD_BEEF#", 16#DEAD_BEEF#,
                         "based hex grouped");
      Assert_Ok_Integer ("2#1010_1010#", 2#1010_1010#,
                         "based binary grouped");
   end Valid_Underscores;

   procedure Leading_Underscore (T : in out Test_Fixture) is
   begin
      Assert_Error ("_1", RL.Bad_Underscore, 1, "leading _");
   end Leading_Underscore;

   procedure Trailing_Underscore (T : in out Test_Fixture) is
   begin
      Assert_Error ("1_", RL.Bad_Underscore, 2, "trailing _");
      Assert_Error ("0xFF_", RL.Bad_Underscore, 5, "trailing _ in hex");
   end Trailing_Underscore;

   procedure Doubled_Underscore (T : in out Test_Fixture) is
   begin
      Assert_Error ("1__0", RL.Bad_Underscore, 3, "double __");
      Assert_Error ("0xF__F", RL.Bad_Underscore, 5, "double __ in hex");
   end Doubled_Underscore;

   procedure Adjacent_To_Prefix (T : in out Test_Fixture) is
   begin
      Assert_Error ("0x_1", RL.Bad_Underscore, 3, "_ right after 0x");
      Assert_Error ("0b_1", RL.Bad_Underscore, 3, "_ right after 0b");
      Assert_Error ("0o_1", RL.Bad_Underscore, 3, "_ right after 0o");
   end Adjacent_To_Prefix;

   procedure Adjacent_To_Hash (T : in out Test_Fixture) is
   begin
      Assert_Error ("16#_F#", RL.Bad_Underscore, 4,
                    "_ right after #");
      Assert_Error ("16#F_#", RL.Bad_Underscore, 5,
                    "_ right before #");
   end Adjacent_To_Hash;

   procedure Adjacent_To_Dot (T : in out Test_Fixture) is
   begin
      Assert_Error ("1_.0", RL.Bad_Underscore, 3, "_ before .");
      Assert_Error ("1._5", RL.Bad_Underscore, 3, "_ after .");
   end Adjacent_To_Dot;

   procedure Underscore_In_Exponent (T : in out Test_Fixture) is
   begin
      Assert_Error ("1e_2", RL.Bad_Underscore, 3,
                    "_ right after e");
      Assert_Error ("1e2_", RL.Bad_Underscore, 4,
                    "trailing _ in exponent");
   end Underscore_In_Exponent;

end Underscore_Tests;
