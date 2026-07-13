--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Integers;
with Vaton;

package body Radix_Literals.Integers with SPARK_Mode => Off is

   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   package LLI_Conv is new BI.Signed_Conversions
     (Int => Long_Long_Integer);

   function In_Target_Range (V : Long_Long_Integer) return Boolean is
     (V >= Long_Long_Integer (Target'First)
      and then V <= Long_Long_Integer (Target'Last));

   function Overflow_Result return Conv_Result is
     ((Status => Error, Reason => Overflow, Position => 1));

   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Conv_Result
   is
      R : constant Parse_Result :=
        Radix_Literals.Parse (Image, Decimal_Point);
   begin
      case R.Status is
         when Error =>
            return (Status   => Error,
                    Reason   => R.Reason,
                    Position => R.Position);
         when Ok =>
            case R.Value.Kind is
               when Vaton.Integer =>
                  declare
                     V : constant Long_Long_Integer :=
                       Long_Long_Integer (R.Value.Integer);
                  begin
                     if In_Target_Range (V) then
                        return (Status => Ok, Value => Target (V));
                     end if;
                  end;
               when Vaton.Long_Integer =>
                  declare
                     V : constant Long_Long_Integer :=
                       Long_Long_Integer (R.Value.Long_Integer);
                  begin
                     if In_Target_Range (V) then
                        return (Status => Ok, Value => Target (V));
                     end if;
                  end;
               when Vaton.Long_Long_Integer =>
                  if In_Target_Range (R.Value.Long_Long_Integer) then
                     return (Status => Ok,
                             Value  => Target (R.Value.Long_Long_Integer));
                  end if;
               when Vaton.Big_Integer =>
                  declare
                     Low  : constant BI.Big_Integer :=
                       LLI_Conv.To_Big_Integer (Long_Long_Integer'First);
                     High : constant BI.Big_Integer :=
                       LLI_Conv.To_Big_Integer (Long_Long_Integer'Last);
                  begin
                     if BI."<=" (Low, R.Value.Big_Integer)
                       and then BI."<=" (R.Value.Big_Integer, High)
                     then
                        declare
                           V : constant Long_Long_Integer :=
                             LLI_Conv.From_Big_Integer (R.Value.Big_Integer);
                        begin
                           if In_Target_Range (V) then
                              return (Status => Ok, Value => Target (V));
                           end if;
                        end;
                     end if;
                  end;
               when Vaton.Float
                  | Vaton.Long_Float
                  | Vaton.Long_Long_Float
                  | Vaton.Big_Real
                  | Vaton.NaN =>
                  null;
            end case;
            return Overflow_Result;
      end case;
   end Parse;

end Radix_Literals.Integers;
