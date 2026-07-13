--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Radix_Literals;
with Radix_Literals.Integers;
with Vaton;

procedure Example is
   package RL renames Radix_Literals;
   use type RL.Parse_Status;
   use type Vaton.Number_Kind;
   package To_Int is new RL.Integers (Target => Integer);

   procedure Show (Label : String; Image : String) is
      R : constant RL.Parse_Result := RL.Parse (Image);
   begin
      Put (Label & " = " & Image & " -> ");
      case R.Status is
         when RL.Ok =>
            case R.Value.Kind is
               when Vaton.Integer =>
                  Put_Line ("Integer =" & Integer'Image (R.Value.Integer));
               when Vaton.Long_Integer =>
                  Put_Line ("Long_Integer ="
                    & Long_Integer'Image (R.Value.Long_Integer));
               when Vaton.Long_Long_Integer =>
                  Put_Line ("Long_Long_Integer ="
                    & Long_Long_Integer'Image
                        (R.Value.Long_Long_Integer));
               when Vaton.Float =>
                  Put_Line ("Float =" & Float'Image (R.Value.Float));
               when Vaton.Long_Float =>
                  Put_Line ("Long_Float ="
                    & Long_Float'Image (R.Value.Long_Float));
               when others =>
                  Put_Line ("Other kind");
            end case;
         when RL.Error =>
            Put_Line ("Error " & RL.Error_Kind'Image (R.Reason)
                      & " @" & Positive'Image (R.Position));
      end case;
   end Show;

   procedure Show_Int (Label : String; Image : String) is
      C : constant To_Int.Conv_Result := To_Int.Parse (Image);
   begin
      Put (Label & " = " & Image & " -> ");
      case C.Status is
         when RL.Ok =>
            Put_Line ("Integer =" & Integer'Image (C.Value));
         when RL.Error =>
            Put_Line ("Error " & RL.Error_Kind'Image (C.Reason));
      end case;
   end Show_Int;

begin
   Put_Line ("== Radix_Literals demo ==");
   Show ("hex prefix", "0xFF");
   Show ("Ada based + exp", "16#FF#E2");
   Show ("decimal grouped", "-1_000");
   Show ("decimal float", "3.14");
   New_Line;
   Put_Line ("== Radix_Literals.Integers demo ==");
   Show_Int ("Integer facade", "0xFF");
   Show_Int ("Integer facade", "16#FF#E2");
end Example;
