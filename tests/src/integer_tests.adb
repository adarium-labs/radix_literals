--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Assertions; use AUnit.Assertions;
with Test_Support;    use Test_Support;
with Radix_Literals;
with Vaton;

package body Integer_Tests is

   use type Radix_Literals.Parse_Status;
   use type Vaton.Number_Kind;

   procedure Decimal_Positive (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("42", 42, "decimal integer");
   end Decimal_Positive;

   procedure Decimal_Negative (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("-1000", -1000, "negative decimal");
   end Decimal_Negative;

   procedure Decimal_Explicit_Plus (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("+42", 42, "explicit plus sign");
   end Decimal_Explicit_Plus;

   procedure Hex_Prefix_Lower (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("0xff", 255, "hex prefix lowercase");
      Assert_Ok_Integer ("0xdead_beef", 16#DEAD_BEEF#,
                         "hex prefix + underscore");
   end Hex_Prefix_Lower;

   procedure Hex_Prefix_Upper (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("0XFF", 255, "hex prefix uppercase");
      Assert_Ok_Integer ("0X10", 16, "hex prefix uppercase 0x10");
   end Hex_Prefix_Upper;

   procedure Hex_Mixed_Case (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("0xDeAdBeEf", 16#DEAD_BEEF#,
                         "hex mixed case");
   end Hex_Mixed_Case;

   procedure Oct_Prefix (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("0o377", 8#377#, "octal 0o377");
      Assert_Ok_Integer ("0O10", 8, "octal 0O10");
   end Oct_Prefix;

   procedure Bin_Prefix (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("0b1010_1010", 2#1010_1010#, "binary");
      Assert_Ok_Integer ("0B1", 1, "binary uppercase B");
   end Bin_Prefix;

   procedure Based_All_Bases (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("2#1010#", 10, "base 2");
      Assert_Ok_Integer ("3#12#", 5, "base 3");
      Assert_Ok_Integer ("4#33#", 15, "base 4");
      Assert_Ok_Integer ("5#44#", 24, "base 5");
      Assert_Ok_Integer ("6#55#", 35, "base 6");
      Assert_Ok_Integer ("7#66#", 48, "base 7");
      Assert_Ok_Integer ("8#77#", 63, "base 8");
      Assert_Ok_Integer ("9#88#", 80, "base 9");
      Assert_Ok_Integer ("10#42#", 42, "base 10");
      Assert_Ok_Integer ("11#AA#", 120, "base 11");
      Assert_Ok_Integer ("12#BB#", 143, "base 12");
      Assert_Ok_Integer ("13#CC#", 168, "base 13");
      Assert_Ok_Integer ("14#DD#", 195, "base 14");
      Assert_Ok_Integer ("15#EE#", 224, "base 15");
      Assert_Ok_Integer ("16#FF#", 255, "base 16");
      Assert_Ok_Integer ("16#DEAD_BEEF#", 16#DEAD_BEEF#,
                         "base 16 with underscore");
   end Based_All_Bases;

   procedure Negative_Prefixed (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("-0x10", -16, "negative hex");
      Assert_Ok_Integer ("-0b1010", -10, "negative binary");
      Assert_Ok_Integer ("-0o10", -8, "negative octal");
   end Negative_Prefixed;

   procedure Negative_Based (T : in out Test_Fixture) is
   begin
      Assert_Ok_Integer ("-2#1010#", -10, "negative base 2");
      Assert_Ok_Integer ("-16#FF#", -255, "negative base 16");
   end Negative_Based;

   procedure Prefix_Trailing_E_As_Hex (T : in out Test_Fixture) is
      --  Documented decision: 'e' after a prefixed hex literal is a hex
      --  digit, not the start of an exponent.  0xFFe2 parses as the
      --  hex integer 0xFFE2 = 65506, matching Ada based semantics for
      --  extended digits.  See README.md "Design decisions".
   begin
      Assert_Ok_Integer ("0xFFe2", 65506,
                         "0xFFe2 policy: treat e as hex digit");
      Assert_Ok_Integer ("0xE", 14, "single hex digit E");
      Assert_Ok_Integer ("0xe", 14, "single hex digit lowercase e");
   end Prefix_Trailing_E_As_Hex;

   procedure Big_Integer_Value (T : in out Test_Fixture) is
      --  A value that exceeds Long_Long_Integer should still parse
      --  successfully and come back as a Big_Integer variant.
      Large : constant String := "1_000_000_000_000_000_000_000";
      R     : constant Radix_Literals.Parse_Result :=
        Radix_Literals.Parse (Large);
   begin
      Assert (R.Status = Radix_Literals.Ok,
              "Big_Integer_Value: expected Ok for " & Large);
      Assert (R.Value.Kind = Vaton.Big_Integer,
              "Big_Integer_Value: expected Big_Integer kind");
   end Big_Integer_Value;

end Integer_Tests;
