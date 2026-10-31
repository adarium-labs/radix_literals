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
with Exact_Tests;
with Float_Range_Tests;
with Budget_Tests;
with Bounds_Tests;

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
   package Exa_Caller is new
     AUnit.Test_Caller (Exact_Tests.Test_Fixture);
   package Flr_Caller is new
     AUnit.Test_Caller (Float_Range_Tests.Test_Fixture);
   package Bnd_Caller is new
     AUnit.Test_Caller (Bounds_Tests.Test_Fixture);
   package Bud_Caller is new
     AUnit.Test_Caller (Budget_Tests.Test_Fixture);

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

      --  Parse_Exact tests
      S.Add_Test (Exa_Caller.Create
        ("Exact: Decimal_16_To_18_Digits",
         Exact_Tests.Decimal_16_To_18_Digits'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Decimal_Fraction_And_Exponent",
         Exact_Tests.Decimal_Fraction_And_Exponent'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Negative_Zero",
         Exact_Tests.Negative_Zero'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Huge_And_Tiny_Exponents",
         Exact_Tests.Huge_And_Tiny_Exponents'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Based_Exact_Forms",
         Exact_Tests.Based_Exact_Forms'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Based_Exponent_At_Natural_Max",
         Exact_Tests.Based_Exponent_At_Natural_Max'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Prefixed_Exact_Forms",
         Exact_Tests.Prefixed_Exact_Forms'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Underscores_And_Signs",
         Exact_Tests.Underscores_And_Signs'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Decimal_Point_Comma",
         Exact_Tests.Decimal_Point_Comma'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Invalid_Decimal_Point",
         Exact_Tests.Invalid_Decimal_Point'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Wide_Overloads",
         Exact_Tests.Wide_Overloads'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Errors_Match_Parse",
         Exact_Tests.Errors_Match_Parse'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Overflow_Matches_Parse",
         Exact_Tests.Overflow_Matches_Parse'Access));
      S.Add_Test (Exa_Caller.Create
        ("Exact: Corpus_Agrees_With_Parse",
         Exact_Tests.Corpus_Agrees_With_Parse'Access));

      --  Float range tests (Vaton overflow guard)
      S.Add_Test (Flr_Caller.Create
        ("Float range: Overflow_Float_Power",
         Float_Range_Tests.Overflow_Float_Power'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Overflow_Float_Product",
         Float_Range_Tests.Overflow_Float_Product'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Overflow_Long_Float",
         Float_Range_Tests.Overflow_Long_Float'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Overflow_Long_Long_Float",
         Float_Range_Tests.Overflow_Long_Long_Float'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Threshold_Edges",
         Float_Range_Tests.Threshold_Edges'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Decimal_Point_Comma_Class",
         Float_Range_Tests.Decimal_Point_Comma_Class'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Comma_Is_Not_Dropped",
         Float_Range_Tests.Comma_Is_Not_Dropped'Access));
      S.Add_Test (Flr_Caller.Create
        ("Float range: Never_Raises_Sweep",
         Float_Range_Tests.Never_Raises_Sweep'Access));

      --  Budget tests (no raise; Overflow beyond budget)
      S.Add_Test (Bud_Caller.Create
        ("Budget: Big_Denominator_Repros",
         Budget_Tests.Big_Denominator_Repros'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Big_Real_Safe_Operations",
         Budget_Tests.Big_Real_Safe_Operations'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Digit_Budget_Boundary",
         Budget_Tests.Digit_Budget_Boundary'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Digit_Budget_Repros",
         Budget_Tests.Digit_Budget_Repros'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Exponent_Digits_Repros",
         Budget_Tests.Exponent_Digits_Repros'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Based_Power_Repros",
         Budget_Tests.Based_Power_Repros'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Denominator_Budget_Boundary",
         Budget_Tests.Denominator_Budget_Boundary'Access));
      S.Add_Test (Bud_Caller.Create
        ("Budget: Budget_Sweep",
         Budget_Tests.Budget_Sweep'Access));

      --  Bounds tests (decimal point, Positive'Last, huge input, budgets)
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Exact_Based_Exponent_Beyond_Natural",
         Bounds_Tests.Exact_Based_Exponent_Beyond_Natural'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Zero_Exponent_Uses_Decimal_Point",
         Bounds_Tests.Zero_Exponent_Uses_Decimal_Point'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Strings_Ending_At_Positive_Last",
         Bounds_Tests.Strings_Ending_At_Positive_Last'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Huge_Inputs_Are_Bounded",
         Bounds_Tests.Huge_Inputs_Are_Bounded'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Synthetic_Digit_Not_Charged",
         Bounds_Tests.Synthetic_Digit_Not_Charged'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Syntax_Before_Limits",
         Bounds_Tests.Syntax_Before_Limits'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Leading_Zeros_Are_Normalised",
         Bounds_Tests.Leading_Zeros_Are_Normalised'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: No_Digit_Array_Leak",
         Bounds_Tests.No_Digit_Array_Leak'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Positive_Scale_Boundary",
         Bounds_Tests.Positive_Scale_Boundary'Access));
      S.Add_Test (Bnd_Caller.Create
        ("Bounds: Format_Delimiter_Decimal_Points",
         Bounds_Tests.Format_Delimiter_Decimal_Points'Access));

      return S;
   end Suite;

end Main_Suite;
