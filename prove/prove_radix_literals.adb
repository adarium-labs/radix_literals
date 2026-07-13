--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Interfaces;
with Radix_Literals;
with Radix_Literals.Integers;

---  @summary Instantiation harness that exposes the ``Radix_Literals``
---  generic to ``gnatprove``. Not intended to be called at run-time.
procedure Prove_Radix_Literals with SPARK_Mode is

   package Signed_16 is new
     Radix_Literals.Integers (Target => Interfaces.Integer_16);

   package Signed_32 is new
     Radix_Literals.Integers (Target => Integer);

   package Signed_LLI is new
     Radix_Literals.Integers (Target => Long_Long_Integer);

   R_A : constant Signed_16.Conv_Result := Signed_16.Parse ("42");
   R_B : constant Signed_32.Conv_Result := Signed_32.Parse ("0xff");
   R_C : constant Signed_LLI.Conv_Result :=
     Signed_LLI.Parse ("16#FF#E2");

begin
   pragma Unreferenced (R_A);
   pragma Unreferenced (R_B);
   pragma Unreferenced (R_C);
   null;
end Prove_Radix_Literals;
