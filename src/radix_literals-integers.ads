--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

---  @summary Range-checked narrowing from Radix_Literals.Parse to a
---  caller-chosen signed integer target.
---  @description
---    Instantiate with any Ada signed integer type. Parse calls the
---    Radix_Literals.Parse (String, ...) primary entry point and then
---    narrows the resulting Vaton.Number to Target. Values that
---    parse but do not fit Target'Range are reported as
---    Reason => Overflow. Float and Big_Real variants (which cannot be
---    an integer target) are likewise reported as Overflow.
generic
   type Target is range <>;
package Radix_Literals.Integers with SPARK_Mode is

   ---  @summary Outcome of a facade Parse call.
   type Conv_Result (Status : Parse_Status := Error) is record
      case Status is
         when Ok =>
            Value : Target;
         when Error =>
            Reason   : Error_Kind;
            Position : Positive;
      end case;
   end record;

   ---  @summary Parse Image and narrow to Target.
   ---  @param Image The literal to parse (ASCII).
   ---  @param Decimal_Point Passed through to Radix_Literals.Parse.
   ---  @return Conv_Result; out-of-range values report Overflow.
   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Conv_Result;

end Radix_Literals.Integers;
