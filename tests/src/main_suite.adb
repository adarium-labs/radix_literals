--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Test_Caller;
with AUnit.Test_Suites; use AUnit.Test_Suites;

with Integer_Tests;
with Float_Tests;
with Error_Tests;
with Underscore_Tests;
with Based_Exponent_Tests;
with Generic_Facade_Tests;
with Wide_String_Tests;

package body Main_Suite is

   package Int_Caller is new AUnit.Test_Caller (Integer_Tests.Test_Fixture);
   package Flt_Caller is new AUnit.Test_Caller (Float_Tests.Test_Fixture);
   package Err_Caller is new AUnit.Test_Caller (Error_Tests.Test_Fixture);
   package Und_Caller is new
     AUnit.Test_Caller (Underscore_Tests.Test_Fixture);
   package Bex_Caller is new
     AUnit.Test_Caller (Based_Exponent_Tests.Test_Fixture);
   package Gen_Caller is new
     AUnit.Test_Caller (Generic_Facade_Tests.Test_Fixture);
   package Wid_Caller is new
     AUnit.Test_Caller (Wide_String_Tests.Test_Fixture);

   function Suite return Access_Test_Suite is
      S : constant Access_Test_Suite := new Test_Suite;
   begin
      --  Integer tests
      S.Add_Test (Int_Caller.Create
        ("Integer: Decimal_Positive",
         Integer_Tests.Decimal_Positive'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Decimal_Negative",
         Integer_Tests.Decimal_Negative'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Decimal_Explicit_Plus",
         Integer_Tests.Decimal_Explicit_Plus'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Hex_Prefix_Lower",
         Integer_Tests.Hex_Prefix_Lower'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Hex_Prefix_Upper",
         Integer_Tests.Hex_Prefix_Upper'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Hex_Mixed_Case",
         Integer_Tests.Hex_Mixed_Case'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Oct_Prefix",
         Integer_Tests.Oct_Prefix'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Bin_Prefix",
         Integer_Tests.Bin_Prefix'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Based_All_Bases",
         Integer_Tests.Based_All_Bases'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Negative_Prefixed",
         Integer_Tests.Negative_Prefixed'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Negative_Based",
         Integer_Tests.Negative_Based'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Prefix_Trailing_E_As_Hex",
         Integer_Tests.Prefix_Trailing_E_As_Hex'Access));
      S.Add_Test (Int_Caller.Create
        ("Integer: Big_Integer_Value",
         Integer_Tests.Big_Integer_Value'Access));

      --  Float tests
      S.Add_Test (Flt_Caller.Create
        ("Float: Simple_Fraction",
         Float_Tests.Simple_Fraction'Access));
      S.Add_Test (Flt_Caller.Create
        ("Float: Positive_Exponent",
         Float_Tests.Positive_Exponent'Access));
      S.Add_Test (Flt_Caller.Create
        ("Float: Signed_Exponent",
         Float_Tests.Signed_Exponent'Access));
      S.Add_Test (Flt_Caller.Create
        ("Float: Negative_Float",
         Float_Tests.Negative_Float'Access));
      S.Add_Test (Flt_Caller.Create
        ("Float: Fraction_And_Exp",
         Float_Tests.Fraction_And_Exp'Access));
      S.Add_Test (Flt_Caller.Create
        ("Float: Zero_Exponent",
         Float_Tests.Zero_Exponent'Access));

      --  Error tests
      S.Add_Test (Err_Caller.Create
        ("Error: Empty_Input_Case",
         Error_Tests.Empty_Input_Case'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Prefix_No_Digits",
         Error_Tests.Prefix_No_Digits'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Based_Empty_Digits",
         Error_Tests.Based_Empty_Digits'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Based_Missing_Second_Hash",
         Error_Tests.Based_Missing_Second_Hash'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Based_Empty_Exponent",
         Error_Tests.Based_Empty_Exponent'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Invalid_Digit_For_Base_Cases",
         Error_Tests.Invalid_Digit_For_Base_Cases'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Base_Out_Of_Range_Cases",
         Error_Tests.Base_Out_Of_Range_Cases'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Based_Real_Rejected",
         Error_Tests.Based_Real_Rejected'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: C_Hex_Float_Rejected",
         Error_Tests.C_Hex_Float_Rejected'Access));
      S.Add_Test (Err_Caller.Create
        ("Error: Empty_Digits_On_Decimal",
         Error_Tests.Empty_Digits_On_Decimal'Access));

      --  Underscore tests
      S.Add_Test (Und_Caller.Create
        ("Underscore: Valid_Underscores",
         Underscore_Tests.Valid_Underscores'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Leading_Underscore",
         Underscore_Tests.Leading_Underscore'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Trailing_Underscore",
         Underscore_Tests.Trailing_Underscore'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Doubled_Underscore",
         Underscore_Tests.Doubled_Underscore'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Adjacent_To_Prefix",
         Underscore_Tests.Adjacent_To_Prefix'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Adjacent_To_Hash",
         Underscore_Tests.Adjacent_To_Hash'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Adjacent_To_Dot",
         Underscore_Tests.Adjacent_To_Dot'Access));
      S.Add_Test (Und_Caller.Create
        ("Underscore: Underscore_In_Exponent",
         Underscore_Tests.Underscore_In_Exponent'Access));

      --  Based-exponent tests
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Ada_Exponent_Base_16",
         Based_Exponent_Tests.Ada_Exponent_Base_16'Access));
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Ada_Exponent_Base_2",
         Based_Exponent_Tests.Ada_Exponent_Base_2'Access));
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Ada_Exponent_Base_10",
         Based_Exponent_Tests.Ada_Exponent_Base_10'Access));
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Explicit_Plus_Exp",
         Based_Exponent_Tests.Explicit_Plus_Exp'Access));
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Negative_Exp_Rejected",
         Based_Exponent_Tests.Negative_Exp_Rejected'Access));
      S.Add_Test (Bex_Caller.Create
        ("Based_Exp: Overflow_Big_Digit_Limit",
         Based_Exponent_Tests.Overflow_Big_Digit_Limit'Access));

      --  Generic facade tests
      S.Add_Test (Gen_Caller.Create
        ("Facade: Integer_Round_Trip",
         Generic_Facade_Tests.Integer_Round_Trip'Access));
      S.Add_Test (Gen_Caller.Create
        ("Facade: Small_Range_In",
         Generic_Facade_Tests.Small_Range_In'Access));
      S.Add_Test (Gen_Caller.Create
        ("Facade: Small_Range_Out",
         Generic_Facade_Tests.Small_Range_Out'Access));
      S.Add_Test (Gen_Caller.Create
        ("Facade: Negative_Value",
         Generic_Facade_Tests.Negative_Value'Access));
      S.Add_Test (Gen_Caller.Create
        ("Facade: Float_As_Overflow",
         Generic_Facade_Tests.Float_As_Overflow'Access));
      S.Add_Test (Gen_Caller.Create
        ("Facade: Error_Propagated",
         Generic_Facade_Tests.Error_Propagated'Access));

      --  Wide_String tests
      S.Add_Test (Wid_Caller.Create
        ("Wide: Wide_Positive",
         Wide_String_Tests.Wide_Positive'Access));
      S.Add_Test (Wid_Caller.Create
        ("Wide: Wide_Non_Ascii_Rejected",
         Wide_String_Tests.Wide_Non_Ascii_Rejected'Access));
      S.Add_Test (Wid_Caller.Create
        ("Wide: Wide_Wide_Positive",
         Wide_String_Tests.Wide_Wide_Positive'Access));
      S.Add_Test (Wid_Caller.Create
        ("Wide: Wide_Wide_Non_Ascii_Rejected",
         Wide_String_Tests.Wide_Wide_Non_Ascii_Rejected'Access));

      return S;
   end Suite;

end Main_Suite;
