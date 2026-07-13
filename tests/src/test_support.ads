--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Radix_Literals;

package Test_Support is

   package RL renames Radix_Literals;

   procedure Assert_Ok_Integer
     (Image    : String;
      Expected : Long_Long_Integer;
      Msg      : String);

   procedure Assert_Ok_Float_Approx
     (Image    : String;
      Expected : Long_Long_Float;
      Msg      : String);

   procedure Assert_Ok_Any_Float (Image : String; Msg : String);

   procedure Assert_Error
     (Image       : String;
      Reason      : RL.Error_Kind;
      Position    : Positive;
      Msg         : String);

   function LLI_Of (R : RL.Parse_Result) return Long_Long_Integer;
   --  Convenience: reads any integer variant back as Long_Long_Integer.
   --  Precondition (checked): R.Status = Ok and R.Value.Kind is an
   --  integer variant.

end Test_Support;
