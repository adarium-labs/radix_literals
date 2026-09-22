--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

with Ada.Numerics.Big_Numbers.Big_Integers;

package body Radix_Literals with SPARK_Mode => Off is

   package BI renames Ada.Numerics.Big_Numbers.Big_Integers;
   use type BI.Big_Integer;

   subtype Base_Range is Positive range 2 .. 16;

   type Format_Kind is (Format_Empty, Format_Decimal, Format_Prefixed,
                        Format_Based);

   type Detected_Format (Kind : Format_Kind := Format_Empty) is record
      case Kind is
         when Format_Empty =>
            null;
         when Format_Decimal =>
            null;
         when Format_Prefixed =>
            Prefix_Base : Base_Range;
         when Format_Based =>
            null;
      end case;
   end record;

   -----------------------------------------------------------------------
   --  Character helpers
   -----------------------------------------------------------------------

   function Is_Ascii_Digit (C : Character) return Boolean is
     (C in '0' .. '9');

   function Is_Hex_Letter (C : Character) return Boolean is
     (C in 'a' .. 'f' or else C in 'A' .. 'F');

   function Is_Ascii_Letter (C : Character) return Boolean is
     (C in 'a' .. 'z' or else C in 'A' .. 'Z');

   function Digit_Value (C : Character) return Natural is
     (case C is
        when '0' .. '9' => Character'Pos (C) - Character'Pos ('0'),
        when 'a' .. 'f' => 10 + Character'Pos (C) - Character'Pos ('a'),
        when 'A' .. 'F' => 10 + Character'Pos (C) - Character'Pos ('A'),
        when others     => 0);

   function Is_Digit_For_Base (C : Character; Base : Base_Range)
     return Boolean is
     ((Is_Ascii_Digit (C) or else Is_Hex_Letter (C))
      and then Digit_Value (C) < Base);

   function Widen (C : Character) return Wide_Character is
     (Wide_Character'Val (Character'Pos (C)));

   -----------------------------------------------------------------------
   --  Sign strip + format detection
   -----------------------------------------------------------------------

   procedure Strip_Sign
     (Image       : String;
      Is_Negative : out Boolean;
      Body_First  : out Positive;
      Body_Last   : out Natural)
   is
   begin
      Is_Negative := False;
      Body_First  := Image'First;
      Body_Last   := Image'Last;
      if Image'Length = 0 then
         return;
      end if;
      case Image (Image'First) is
         when '+' =>
            Body_First := Image'First + 1;
         when '-' =>
            Is_Negative := True;
            Body_First := Image'First + 1;
         when others =>
            null;
      end case;
   end Strip_Sign;

   function Detect_Format (Body_Slice : String) return Detected_Format is
   begin
      if Body_Slice'Length = 0 then
         return (Kind => Format_Empty);
      end if;

      if Body_Slice'Length >= 2
        and then Body_Slice (Body_Slice'First) = '0'
      then
         case Body_Slice (Body_Slice'First + 1) is
            when 'x' | 'X' =>
               return (Kind => Format_Prefixed, Prefix_Base => 16);
            when 'o' | 'O' =>
               return (Kind => Format_Prefixed, Prefix_Base => 8);
            when 'b' | 'B' =>
               return (Kind => Format_Prefixed, Prefix_Base => 2);
            when others =>
               null;
         end case;
      end if;

      for I in Body_Slice'Range loop
         if Body_Slice (I) = '#' then
            return (Kind => Format_Based);
         end if;
      end loop;

      return (Kind => Format_Decimal);
   end Detect_Format;

   -----------------------------------------------------------------------
   --  Decimal path: hand off directly to vaton, position-mapped.
   -----------------------------------------------------------------------

   type Decimal_State is
     (Whole_Start, Whole_Digit, Whole_Us,
      Frac_Start, Frac_Digit, Frac_Us,
      Exp_Sign, Exp_Start, Exp_Digit, Exp_Us);

   function Parse_Decimal_Path
     (Image         : String;
      Slice_Offset  : Natural;   --  Image (I) has input pos = Slice_Offset+I
      Is_Negative   : Boolean;
      Decimal_Point : Wide_Character) return Parse_Result
   is
      P         : Vaton.Number_Pieces;
      Append_Ok : Boolean;
      State     : Decimal_State := Whole_Start;

      --  The exponent part ('e', sign, digits, underscores) is held back
      --  until the end of input instead of being streamed: vaton returns 1
      --  for an explicit zero exponent (Combine and Convert_Big_Real both
      --  short-circuit on it), so a zero exponent must never reach it.
      Exponent_Part    : String (1 .. Image'Length);
      Exponent_Last    : Natural := 0;
      Exponent_Is_Zero : Boolean := True;
      Has_Fraction     : Boolean := False;

      function Input_Pos (I : Integer) return Positive is
        (Slice_Offset + (I - Image'First + 1));
   begin
      Vaton.Reset (P);

      if Image'Length = 0 then
         return (Status   => Error, Reason => Empty_Digits,
                 Position => Positive'Max (1, Slice_Offset + 1));
      end if;

      --  Inject a leading '-' into vaton so it records Whole_Is_Negative.
      if Is_Negative then
         Vaton.Append (P, '-', Append_Ok, Decimal_Point);
         if not Append_Ok then
            return (Status => Error, Reason => Storage_Exhausted,
                    Position => 1);
         end if;
      end if;

      --  Validate each character against the decimal grammar (state machine
      --  encodes: numeral [ '.' numeral ] [ (e|E) [+|-] numeral ], with a
      --  single '_' allowed between digits) and stream it into vaton.
      for I in Image'Range loop
         declare
            C   : constant Character := Image (I);
            Pos : constant Positive  := Input_Pos (I);
         begin
            if Character'Pos (C) > 127 then
               return (Status => Error, Reason => Invalid_Character,
                       Position => Pos);
            end if;

            case State is
               when Whole_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Whole_Digit;
                  elsif C = '_' then
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position => Pos);
                  end if;

               when Whole_Digit =>
                  if Is_Ascii_Digit (C) then
                     null;
                  elsif C = '_' then
                     State := Whole_Us;
                  elsif C = '.' then
                     State := Frac_Start;
                  elsif C = 'e' or else C = 'E' then
                     State := Exp_Sign;
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position => Pos);
                  end if;

               when Whole_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Whole_Digit;
                  else
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  end if;

               when Frac_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Frac_Digit;
                  elsif C = '_' then
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  else
                     return (Status => Error, Reason => Empty_Digits,
                             Position => Pos);
                  end if;

               when Frac_Digit =>
                  if Is_Ascii_Digit (C) then
                     null;
                  elsif C = '_' then
                     State := Frac_Us;
                  elsif C = 'e' or else C = 'E' then
                     State := Exp_Sign;
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position => Pos);
                  end if;

               when Frac_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Frac_Digit;
                  else
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  end if;

               when Exp_Sign =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  elsif C = '+' or else C = '-' then
                     State := Exp_Start;
                  elsif C = '_' then
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position => Pos);
                  end if;

               when Exp_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  elsif C = '_' then
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  else
                     return (Status => Error, Reason => Empty_Digits,
                             Position => Pos);
                  end if;

               when Exp_Digit =>
                  if Is_Ascii_Digit (C) then
                     null;
                  elsif C = '_' then
                     State := Exp_Us;
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position => Pos);
                  end if;

               when Exp_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  else
                     return (Status => Error, Reason => Bad_Underscore,
                             Position => Pos);
                  end if;
            end case;

            --  Character is grammatically valid: feed to vaton, or hold it
            --  back when it belongs to the exponent part.  Success is only
            --  False on storage / capacity trouble, never on syntax.
            if State in Exp_Sign .. Exp_Us then
               Exponent_Last := Exponent_Last + 1;
               Exponent_Part (Exponent_Last) := C;
               if State = Exp_Digit and then C /= '0' then
                  Exponent_Is_Zero := False;
               end if;
            else
               Has_Fraction := Has_Fraction or else State = Frac_Start;
               Vaton.Append (P, Widen (C), Append_Ok, Decimal_Point);
               if not Append_Ok then
                  return (Status => Error, Reason => Storage_Exhausted,
                          Position => Pos);
               end if;
            end if;
         end;
      end loop;

      --  End-of-input acceptance check.
      case State is
         when Whole_Start | Frac_Start | Exp_Sign | Exp_Start =>
            return (Status => Error, Reason => Empty_Digits,
                    Position => Slice_Offset + Image'Length);
         when Whole_Us | Frac_Us | Exp_Us =>
            return (Status => Error, Reason => Bad_Underscore,
                    Position => Slice_Offset + Image'Length);
         when Whole_Digit | Frac_Digit | Exp_Digit =>
            null;
      end case;

      --  Stream the held-back exponent unless it is zero (x * 10**0 = x).
      --  A dropped zero exponent on a numeral without fraction becomes ".0"
      --  so that "7e0" stays a floating-point value, like "7e1".
      Append_Ok := True;
      if Exponent_Last > 0 then
         if not Exponent_Is_Zero then
            for I in 1 .. Exponent_Last loop
               Vaton.Append
                 (P, Widen (Exponent_Part (I)), Append_Ok, Decimal_Point);
               exit when not Append_Ok;
            end loop;
         elsif not Has_Fraction then
            Vaton.Append (P, Widen ('.'), Append_Ok, Decimal_Point);
            if Append_Ok then
               Vaton.Append (P, Widen ('0'), Append_Ok, Decimal_Point);
            end if;
         end if;
      end if;
      if not Append_Ok then
         return (Status => Error, Reason => Storage_Exhausted,
                 Position => Slice_Offset + Image'Length);
      end if;

      if not Vaton.Is_Valid_Number (P) then
         --  State machine ruled out empty parts and dangling underscores,
         --  so the only remaining reason is length above vaton's digit
         --  limit (Is_Valid_Partial_Number -> Overflow).
         return (Status => Error, Reason => Overflow,
                 Position => Slice_Offset + Image'Length);
      end if;

      return (Status => Ok, Value => Vaton.To_Number (P));
   end Parse_Decimal_Path;

   -----------------------------------------------------------------------
   --  Underscore state machine + digit validation for a non-decimal run.
   --
   --  Digits (a stream of Character in Image (First..Last)) must satisfy:
   --    * first and last characters are digits valid in Base;
   --    * '_' occurs only between two such digits;
   --    * no other character is permitted.
   --
   --  Reports the FIRST offending position (1-based, in original input
   --  coordinates via Slice_Offset), or 0 in Bad_Pos on success.
   -----------------------------------------------------------------------

   procedure Validate_Digit_Run
     (Image        : String;
      First, Last  : Integer;
      Base         : Base_Range;
      Slice_Offset : Natural;
      Bad_Pos      : out Natural;
      Bad_Reason   : out Error_Kind)
   is
      Prev_Was_Digit : Boolean := False;
      Any_Digit_Seen : Boolean := False;
   begin
      Bad_Pos := 0;
      Bad_Reason := None;

      if First > Last then
         Bad_Pos := Slice_Offset + Positive'Max (1, First - Image'First + 1);
         Bad_Reason := Empty_Digits;
         return;
      end if;

      for I in First .. Last loop
         declare
            C   : constant Character := Image (I);
            Pos : constant Positive  := Slice_Offset + (I - Image'First + 1);
         begin
            if C = '_' then
               if not Prev_Was_Digit then
                  Bad_Pos := Pos; Bad_Reason := Bad_Underscore; return;
               end if;
               Prev_Was_Digit := False;
            elsif Is_Ascii_Digit (C) then
               if not Is_Digit_For_Base (C, Base) then
                  Bad_Pos := Pos; Bad_Reason := Invalid_Digit_For_Base;
                  return;
               end if;
               Prev_Was_Digit := True;
               Any_Digit_Seen := True;
            elsif Is_Ascii_Letter (C) then
               --  Any ASCII letter here is an attempted extended digit.
               --  If it is not a valid one for the current base, report
               --  Invalid_Digit_For_Base (covers 'G' in a hex/base-16
               --  literal, 'a' in an octal literal, ...).
               if not Is_Digit_For_Base (C, Base) then
                  Bad_Pos := Pos; Bad_Reason := Invalid_Digit_For_Base;
                  return;
               end if;
               Prev_Was_Digit := True;
               Any_Digit_Seen := True;
            else
               Bad_Pos := Pos; Bad_Reason := Invalid_Character; return;
            end if;
         end;
      end loop;

      if not Any_Digit_Seen then
         Bad_Pos := Slice_Offset + (First - Image'First + 1);
         Bad_Reason := Empty_Digits;
         return;
      end if;

      if not Prev_Was_Digit then
         Bad_Pos := Slice_Offset + (Last - Image'First + 1);
         Bad_Reason := Bad_Underscore;
      end if;
   end Validate_Digit_Run;

   -----------------------------------------------------------------------
   --  Fast Long_Long_Integer accumulator (no exponent applied here).
   --  Reports Overflowed = True if we cannot represent the magnitude.
   -----------------------------------------------------------------------

   procedure Fast_Accumulate
     (Image       : String;
      First, Last : Integer;
      Base        : Base_Range;
      Value       : out Long_Long_Integer;
      Overflowed  : out Boolean)
   is
      Acc  : Long_Long_Integer := 0;
      LB   : constant Long_Long_Integer := Long_Long_Integer (Base);
      Lim  : constant Long_Long_Integer := Long_Long_Integer'Last;
   begin
      Value := 0;
      Overflowed := False;
      for I in First .. Last loop
         declare
            C : constant Character := Image (I);
         begin
            if C = '_' then
               null;
            else
               declare
                  D : constant Long_Long_Integer :=
                    Long_Long_Integer (Digit_Value (C));
               begin
                  if Acc > Lim / LB then
                     Overflowed := True; return;
                  end if;
                  Acc := Acc * LB;
                  if Acc > Lim - D then
                     Overflowed := True; return;
                  end if;
                  Acc := Acc + D;
               end;
            end if;
         end;
      end loop;
      Value := Acc;
   end Fast_Accumulate;

   -----------------------------------------------------------------------
   --  Big_Integer accumulator with optional Ada based exponent.
   -----------------------------------------------------------------------

   procedure Big_Accumulate
     (Image       : String;
      First, Last : Integer;
      Base        : Base_Range;
      Exponent    : Natural;
      Big         : out BI.Big_Integer)
   is
      BI_Base : constant BI.Big_Integer := BI.To_Big_Integer (Integer (Base));
      Acc     : BI.Big_Integer := BI.To_Big_Integer (0);
   begin
      for I in First .. Last loop
         if Image (I) /= '_' then
            Acc := Acc * BI_Base
                   + BI.To_Big_Integer (Digit_Value (Image (I)));
         end if;
      end loop;
      if Exponent > 0 then
         declare
            Factor : BI.Big_Integer := BI.To_Big_Integer (1);
         begin
            for I in 1 .. Exponent loop
               Factor := Factor * BI_Base;
            end loop;
            Acc := Acc * Factor;
         end;
      end if;
      Big := Acc;
   end Big_Accumulate;

   -----------------------------------------------------------------------
   --  Number construction: from a Long_Long_Integer, pick the smallest
   --  standard type that fits, then wrap into Vaton.Number directly.
   -----------------------------------------------------------------------

   function LLI_To_Vaton_Number (V : Long_Long_Integer) return Vaton.Number is
   begin
      if V in Long_Long_Integer (Integer'First) ..
              Long_Long_Integer (Integer'Last)
      then
         return (Kind => Vaton.Integer, Integer => Integer (V));
      elsif V in Long_Long_Integer (Long_Integer'First) ..
                 Long_Long_Integer (Long_Integer'Last)
      then
         return (Kind => Vaton.Long_Integer, Long_Integer => Long_Integer (V));
      else
         return (Kind => Vaton.Long_Long_Integer, Long_Long_Integer => V);
      end if;
   end LLI_To_Vaton_Number;

   -----------------------------------------------------------------------
   --  Feed a plain decimal digit stream (already validated) through vaton
   --  and produce a Parse_Result, honouring the outer sign.  Used by the
   --  Big_Integer fall-back path.
   -----------------------------------------------------------------------

   function Feed_Decimal_String
     (Digits_Image  : String;
      Is_Negative   : Boolean;
      Fail_Position : Positive) return Parse_Result
   is
      P         : Vaton.Number_Pieces;
      Append_Ok : Boolean;
      Wide      : Wide_Character;
   begin
      Vaton.Reset (P);
      if Is_Negative then
         Wide := '-';
         Vaton.Append (P, Wide, Append_Ok, '.');
         if not Append_Ok then
            return (Status => Error, Reason => Storage_Exhausted,
                    Position => Fail_Position);
         end if;
      end if;
      for I in Digits_Image'Range loop
         Wide := Widen (Digits_Image (I));
         Vaton.Append (P, Wide, Append_Ok, '.');
         if not Append_Ok then
            return (Status => Error, Reason => Storage_Exhausted,
                    Position => Fail_Position);
         end if;
      end loop;
      if not Vaton.Is_Valid_Number (P) then
         return (Status => Error, Reason => Overflow,
                 Position => Fail_Position);
      end if;
      return (Status => Ok, Value => Vaton.To_Number (P));
   end Feed_Decimal_String;

   -----------------------------------------------------------------------
   --  Convert a non-negative Big_Integer into its decimal string form
   --  (digits '0'..'9' only, no sign).
   -----------------------------------------------------------------------

   function Big_To_Decimal_String (Big : BI.Big_Integer) return String is
      Img : constant String := BI.To_String (Big, Width => 0, Base => 10);
      --  BI.To_String may prefix a leading space for non-negative values.
      First : Positive := Img'First;
   begin
      while First <= Img'Last and then Img (First) = ' ' loop
         First := First + 1;
      end loop;
      if First <= Img'Last and then Img (First) = '+' then
         First := First + 1;
      end if;
      return Img (First .. Img'Last);
   end Big_To_Decimal_String;

   -----------------------------------------------------------------------
   --  Common back-end for the non-decimal paths: given a validated digit
   --  run and an optional Ada based exponent, produce a Parse_Result.
   -----------------------------------------------------------------------

   function Finish_Non_Decimal
     (Image       : String;
      First, Last : Integer;
      Base        : Base_Range;
      Exponent    : Natural;
      Is_Negative : Boolean;
      End_Pos     : Positive) return Parse_Result
   is
      Value  : Long_Long_Integer;
      Blew   : Boolean;
   begin
      if Exponent = 0 then
         Fast_Accumulate (Image, First, Last, Base, Value, Blew);
         if not Blew then
            declare
               Signed : Long_Long_Integer;
            begin
               if Is_Negative then
                  Signed := -Value;
               else
                  Signed := Value;
               end if;
               return (Status => Ok, Value => LLI_To_Vaton_Number (Signed));
            end;
         end if;
      end if;

      declare
         Big : BI.Big_Integer;
      begin
         Big_Accumulate (Image, First, Last, Base, Exponent, Big);
         return Feed_Decimal_String
                  (Big_To_Decimal_String (Big), Is_Negative, End_Pos);
      end;
   end Finish_Non_Decimal;

   -----------------------------------------------------------------------
   --  Prefixed path: 0x / 0o / 0b, no exponent grammar.  A trailing
   --  'e'/'E' on a hex literal is accepted as a hex digit.
   -----------------------------------------------------------------------

   function Parse_Prefixed_Path
     (Image        : String;   --  the entire un-signed body slice
      Slice_Offset : Natural;  --  input pos of Image (Image'First) is +1
      Base         : Base_Range;
      Is_Negative  : Boolean) return Parse_Result
   is
      Digits_First : constant Integer := Image'First + 2;
      Digits_Last  : constant Integer := Image'Last;
      Bad_Pos      : Natural;
      Bad_Reason   : Error_Kind;
   begin
      if Digits_First > Digits_Last then
         return (Status => Error, Reason => Empty_Digits,
                 Position => Slice_Offset + 2);
      end if;
      Validate_Digit_Run
        (Image, Digits_First, Digits_Last, Base, Slice_Offset,
         Bad_Pos, Bad_Reason);
      if Bad_Pos /= 0 then
         return (Status => Error, Reason => Bad_Reason, Position => Bad_Pos);
      end if;
      return Finish_Non_Decimal
               (Image, Digits_First, Digits_Last, Base, 0, Is_Negative,
                End_Pos => Slice_Offset + Image'Length);
   end Parse_Prefixed_Path;

   -----------------------------------------------------------------------
   --  Based path:  base '#' digits '#' [ ('e'|'E') ['+'] digits ]
   -----------------------------------------------------------------------

   function Parse_Based_Path
     (Image        : String;
      Slice_Offset : Natural;
      Is_Negative  : Boolean) return Parse_Result
   is
      First_Hash    : Integer := 0;
      Second_Hash   : Integer := 0;
      Base_Value    : Natural := 0;
      Base_First    : constant Integer := Image'First;
      Base_Last     : Integer;
      Digits_First  : Integer;
      Digits_Last   : Integer;
      Exp_Value     : Natural := 0;
      Bad_Pos       : Natural;
      Bad_Reason    : Error_Kind;
   begin
      for I in Image'Range loop
         if Image (I) = '#' then
            First_Hash := I;
            exit;
         end if;
      end loop;
      if First_Hash = 0 then
         return (Status => Error, Reason => Malformed_Based_Literal,
                 Position => Slice_Offset + Image'Length);
      end if;
      Base_Last := First_Hash - 1;

      if Base_Last < Base_First then
         return (Status => Error, Reason => Empty_Digits,
                 Position => Slice_Offset + 1);
      end if;
      for I in Base_First .. Base_Last loop
         if not Is_Ascii_Digit (Image (I)) then
            return (Status => Error, Reason => Invalid_Character,
                    Position => Slice_Offset + (I - Image'First + 1));
         end if;
         if Base_Value > (Natural'Last - Digit_Value (Image (I))) / 10 then
            return (Status => Error, Reason => Base_Out_Of_Range,
                    Position => Slice_Offset + (I - Image'First + 1));
         end if;
         Base_Value := Base_Value * 10 + Digit_Value (Image (I));
      end loop;
      if Base_Value not in 2 .. 16 then
         return (Status => Error, Reason => Base_Out_Of_Range,
                 Position => Slice_Offset + (Base_Last - Image'First + 1));
      end if;

      for I in First_Hash + 1 .. Image'Last loop
         if Image (I) = '#' then
            Second_Hash := I;
            exit;
         end if;
         if Image (I) = '.' then
            return (Status => Error, Reason => Invalid_Character,
                    Position => Slice_Offset + (I - Image'First + 1));
         end if;
      end loop;
      if Second_Hash = 0 then
         return (Status => Error, Reason => Malformed_Based_Literal,
                 Position => Slice_Offset + Image'Length);
      end if;
      Digits_First := First_Hash + 1;
      Digits_Last  := Second_Hash - 1;

      Validate_Digit_Run
        (Image, Digits_First, Digits_Last, Base_Range (Base_Value),
         Slice_Offset, Bad_Pos, Bad_Reason);
      if Bad_Pos /= 0 then
         return (Status => Error, Reason => Bad_Reason, Position => Bad_Pos);
      end if;

      if Second_Hash < Image'Last then
         declare
            I    : Integer := Second_Hash + 1;
            Ch   : Character := Image (I);
         begin
            if Ch /= 'e' and then Ch /= 'E' then
               return (Status => Error, Reason => Malformed_Based_Literal,
                       Position => Slice_Offset + (I - Image'First + 1));
            end if;
            I := I + 1;
            if I > Image'Last then
               return (Status => Error, Reason => Empty_Digits,
                       Position => Slice_Offset + (I - Image'First + 1));
            end if;
            if Image (I) = '+' then
               I := I + 1;
            elsif Image (I) = '-' then
               return (Status => Error, Reason => Unexpected_Exponent,
                       Position => Slice_Offset + (I - Image'First + 1));
            end if;
            if I > Image'Last then
               return (Status => Error, Reason => Empty_Digits,
                       Position => Slice_Offset + (I - Image'First + 1));
            end if;
            declare
               Prev_Was_Digit : Boolean := False;
               Any_Seen       : Boolean := False;
            begin
               while I <= Image'Last loop
                  Ch := Image (I);
                  if Ch = '_' then
                     if not Prev_Was_Digit then
                        return (Status => Error, Reason => Bad_Underscore,
                                Position =>
                                  Slice_Offset + (I - Image'First + 1));
                     end if;
                     Prev_Was_Digit := False;
                  elsif Is_Ascii_Digit (Ch) then
                     if Exp_Value > (Natural'Last - Digit_Value (Ch)) / 10
                     then
                        return (Status => Error, Reason => Overflow,
                                Position =>
                                  Slice_Offset + (I - Image'First + 1));
                     end if;
                     Exp_Value := Exp_Value * 10 + Digit_Value (Ch);
                     Prev_Was_Digit := True;
                     Any_Seen := True;
                  else
                     return (Status => Error, Reason => Invalid_Character,
                             Position =>
                               Slice_Offset + (I - Image'First + 1));
                  end if;
                  I := I + 1;
               end loop;
               if not Any_Seen then
                  return (Status => Error, Reason => Empty_Digits,
                          Position => Slice_Offset + Image'Length);
               end if;
               if not Prev_Was_Digit then
                  return (Status => Error, Reason => Bad_Underscore,
                          Position => Slice_Offset + Image'Length);
               end if;
            end;
         end;
      end if;

      return Finish_Non_Decimal
               (Image, Digits_First, Digits_Last,
                Base_Range (Base_Value), Exp_Value, Is_Negative,
                End_Pos => Slice_Offset + Image'Length);
   end Parse_Based_Path;

   -----------------------------------------------------------------------
   --  Public String entry point
   -----------------------------------------------------------------------

   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Is_Negative : Boolean;
      Body_First  : Positive;
      Body_Last   : Natural;
   begin
      if Image'Length = 0 then
         return (Status => Error, Reason => Empty_Input, Position => 1);
      end if;
      Strip_Sign (Image, Is_Negative, Body_First, Body_Last);
      if Body_First > Body_Last then
         return (Status => Error, Reason => Empty_Digits,
                 Position => Body_First - Image'First + 1);
      end if;

      declare
         Body_Slice : constant String := Image (Body_First .. Body_Last);
         Slice_Off  : constant Natural := Body_First - Image'First;
         Fmt        : constant Detected_Format := Detect_Format (Body_Slice);
      begin
         case Fmt.Kind is
            when Format_Empty =>
               return (Status => Error, Reason => Empty_Digits,
                       Position => Slice_Off + 1);
            when Format_Decimal =>
               return Parse_Decimal_Path
                        (Image => Body_Slice, Slice_Offset => Slice_Off,
                         Is_Negative => Is_Negative,
                         Decimal_Point => Decimal_Point);
            when Format_Prefixed =>
               return Parse_Prefixed_Path
                        (Image => Body_Slice, Slice_Offset => Slice_Off,
                         Base => Fmt.Prefix_Base,
                         Is_Negative => Is_Negative);
            when Format_Based =>
               return Parse_Based_Path
                        (Image => Body_Slice, Slice_Offset => Slice_Off,
                         Is_Negative => Is_Negative);
         end case;
      end;
   end Parse;

   -----------------------------------------------------------------------
   --  Wide_String and Wide_Wide_String overloads
   -----------------------------------------------------------------------

   function Parse
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Narrow : String (1 .. Image'Length);
   begin
      for I in Image'Range loop
         declare
            Pos : constant Natural :=
              Wide_Character'Pos (Image (I));
         begin
            if Pos > 127 then
               return (Status => Error, Reason => Invalid_Character,
                       Position => I - Image'First + 1);
            end if;
            Narrow (I - Image'First + 1) := Character'Val (Pos);
         end;
      end loop;
      return Parse (Narrow, Decimal_Point);
   end Parse;

   function Parse
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Narrow : String (1 .. Image'Length);
   begin
      for I in Image'Range loop
         declare
            Pos : constant Natural :=
              Wide_Wide_Character'Pos (Image (I));
         begin
            if Pos > 127 then
               return (Status => Error, Reason => Invalid_Character,
                       Position => I - Image'First + 1);
            end if;
            Narrow (I - Image'First + 1) := Character'Val (Pos);
         end;
      end loop;
      return Parse (Narrow, Decimal_Point);
   end Parse;

end Radix_Literals;
