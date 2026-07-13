--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with AUnit.Assertions; use AUnit.Assertions;
with Vaton;

package body Test_Support is

   use type RL.Parse_Status;
   use type RL.Error_Kind;
   use type Vaton.Number_Kind;

   ---------------------
   -- Helper: LLI_Of  --
   ---------------------

   function LLI_Of (R : RL.Parse_Result) return Long_Long_Integer is
   begin
      case R.Value.Kind is
         when Vaton.Integer =>
            return Long_Long_Integer (R.Value.Integer);
         when Vaton.Long_Integer =>
            return Long_Long_Integer (R.Value.Long_Integer);
         when Vaton.Long_Long_Integer =>
            return R.Value.Long_Long_Integer;
         when others =>
            return 0;
      end case;
   end LLI_Of;

   -----------------------
   -- Assert_Ok_Integer --
   -----------------------

   procedure Assert_Ok_Integer
     (Image    : String;
      Expected : Long_Long_Integer;
      Msg      : String)
   is
      R : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Assert (R.Status = RL.Ok,
              Msg & ": expected Ok, got Error " & Image);
      Assert (R.Value.Kind in Vaton.Integer | Vaton.Long_Integer
                | Vaton.Long_Long_Integer,
              Msg & ": expected integer Kind, got other " & Image);
      Assert (LLI_Of (R) = Expected,
              Msg & ": value mismatch for " & Image
              & " -- got " & Long_Long_Integer'Image (LLI_Of (R))
              & ", expected " & Long_Long_Integer'Image (Expected));
   end Assert_Ok_Integer;

   ------------------------------
   -- Assert_Ok_Float_Approx   --
   ------------------------------

   procedure Assert_Ok_Float_Approx
     (Image    : String;
      Expected : Long_Long_Float;
      Msg      : String)
   is
      R   : constant RL.Parse_Result := RL.Parse (Image);
      Got : Long_Long_Float := 0.0;
      Tol : constant Long_Long_Float := 1.0e-5;
   begin
      Assert (R.Status = RL.Ok,
              Msg & ": expected Ok float for " & Image);
      case R.Value.Kind is
         when Vaton.Float =>
            Got := Long_Long_Float (R.Value.Float);
         when Vaton.Long_Float =>
            Got := Long_Long_Float (R.Value.Long_Float);
         when Vaton.Long_Long_Float =>
            Got := R.Value.Long_Long_Float;
         when others =>
            Assert (False, Msg & ": expected float variant for " & Image);
      end case;
      Assert (abs (Got - Expected) <= Tol * abs Expected + Tol,
              Msg & ": float mismatch for " & Image);
   end Assert_Ok_Float_Approx;

   ---------------------------
   -- Assert_Ok_Any_Float   --
   ---------------------------

   procedure Assert_Ok_Any_Float (Image : String; Msg : String) is
      R : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Assert (R.Status = RL.Ok, Msg & ": expected Ok for " & Image);
      Assert (R.Value.Kind in Vaton.Float | Vaton.Long_Float
                | Vaton.Long_Long_Float | Vaton.Big_Real,
              Msg & ": expected float variant for " & Image);
   end Assert_Ok_Any_Float;

   -------------------
   -- Assert_Error  --
   -------------------

   procedure Assert_Error
     (Image       : String;
      Reason      : RL.Error_Kind;
      Position    : Positive;
      Msg         : String)
   is
      R : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Assert (R.Status = RL.Error,
              Msg & ": expected Error for " & Image
              & ", got Ok");
      Assert (R.Reason = Reason,
              Msg & ": wrong Reason for " & Image
              & " -- got " & RL.Error_Kind'Image (R.Reason)
              & ", expected " & RL.Error_Kind'Image (Reason));
      Assert (R.Position = Position,
              Msg & ": wrong Position for " & Image
              & " -- got " & Positive'Image (R.Position)
              & ", expected " & Positive'Image (Position));
   end Assert_Error;

end Test_Support;
