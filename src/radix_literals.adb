--  SPDX-License-Identifier: Apache-2.0
--  Copyright (C) 2026 The radix_literals authors

pragma Ada_2022;

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

   --  Outcome of a scanner. Failed = False means the literal is valid
   --  according to its grammar; the scanned facts are returned separately.
   type Scan_Result (Failed : Boolean := True) is record
      case Failed is
         when True =>
            Reason   : Error_Kind;
            Position : Positive;
         when False =>
            null;
      end case;
   end record;

   function Failed_At (Reason : Error_Kind; Position : Positive)
     return Scan_Result is
     ((Failed => True, Reason => Reason, Position => Position));

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
   --  Decimal scanner: validates the decimal grammar and streams the
   --  literal into vaton, with the exponent part held back.
   -----------------------------------------------------------------------

   type Decimal_State is
     (Whole_Start, Whole_Digit, Whole_Us,
      Frac_Start, Frac_Digit, Frac_Us,
      Exp_Sign, Exp_Start, Exp_Digit, Exp_Us);

   procedure Scan_Decimal
     (Image         : String;
      Slice_Offset  : Natural;   --  Image (I) has input pos = Slice_Offset+I
      Is_Negative   : Boolean;
      Decimal_Point : Wide_Character;
      P             : out Vaton.Number_Pieces;
      Outcome       : out Scan_Result)
   is
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

      --  Inject a leading '-' into vaton so it records Whole_Is_Negative.
      if Is_Negative then
         Vaton.Append (P, '-', Append_Ok, Decimal_Point);
         if not Append_Ok then
            Outcome := Failed_At (Storage_Exhausted, 1);
            return;
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
               Outcome := Failed_At (Invalid_Character, Pos);
               return;
            end if;

            case State is
               when Whole_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Whole_Digit;
                  elsif C = '_' then
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  else
                     Outcome := Failed_At (Invalid_Character, Pos);
                     return;
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
                     Outcome := Failed_At (Invalid_Character, Pos);
                     return;
                  end if;

               when Whole_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Whole_Digit;
                  else
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  end if;

               when Frac_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Frac_Digit;
                  elsif C = '_' then
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  else
                     Outcome := Failed_At (Empty_Digits, Pos);
                     return;
                  end if;

               when Frac_Digit =>
                  if Is_Ascii_Digit (C) then
                     null;
                  elsif C = '_' then
                     State := Frac_Us;
                  elsif C = 'e' or else C = 'E' then
                     State := Exp_Sign;
                  else
                     Outcome := Failed_At (Invalid_Character, Pos);
                     return;
                  end if;

               when Frac_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Frac_Digit;
                  else
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  end if;

               when Exp_Sign =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  elsif C = '+' or else C = '-' then
                     State := Exp_Start;
                  elsif C = '_' then
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  else
                     Outcome := Failed_At (Invalid_Character, Pos);
                     return;
                  end if;

               when Exp_Start =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  elsif C = '_' then
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
                  else
                     Outcome := Failed_At (Empty_Digits, Pos);
                     return;
                  end if;

               when Exp_Digit =>
                  if Is_Ascii_Digit (C) then
                     null;
                  elsif C = '_' then
                     State := Exp_Us;
                  else
                     Outcome := Failed_At (Invalid_Character, Pos);
                     return;
                  end if;

               when Exp_Us =>
                  if Is_Ascii_Digit (C) then
                     State := Exp_Digit;
                  else
                     Outcome := Failed_At (Bad_Underscore, Pos);
                     return;
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
                  Outcome := Failed_At (Storage_Exhausted, Pos);
                  return;
               end if;
            end if;
         end;
      end loop;

      --  End-of-input acceptance check.
      case State is
         when Whole_Start | Frac_Start | Exp_Sign | Exp_Start =>
            Outcome := Failed_At (Empty_Digits, Slice_Offset + Image'Length);
            return;
         when Whole_Us | Frac_Us | Exp_Us =>
            Outcome := Failed_At (Bad_Underscore, Slice_Offset + Image'Length);
            return;
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
         Outcome := Failed_At (Storage_Exhausted, Slice_Offset + Image'Length);
         return;
      end if;

      if not Vaton.Is_Valid_Number (P) then
         --  State machine ruled out empty parts and dangling underscores,
         --  so the only remaining reason is length above vaton's digit
         --  limit (Is_Valid_Partial_Number -> Overflow).
         Outcome := Failed_At (Overflow, Slice_Offset + Image'Length);
         return;
      end if;

      Outcome := (Failed => False);
   end Scan_Decimal;

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
   --  Big_Integer accumulator with optional Ada based exponent.  Exponent
   --  = 0 yields the digit value alone; a positive exponent multiplies by
   --  Base ** Exponent (only the Parse path asks for that).
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
      --  Where Long_Integer is as wide as Long_Long_Integer (x86_64 Linux)
      --  the second range test is statically true; GNAT reports that as
      --  dead code.  The test is kept so the kind choice stays the same on
      --  targets where the widths differ.
      pragma Warnings (Off, "range test optimized away");
      pragma Warnings (Off, "value is known to be in range");
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
   --  Prefixed scanner: 0x / 0o / 0b, no exponent grammar.  A trailing
   --  'e'/'E' on a hex literal is accepted as a hex digit.
   -----------------------------------------------------------------------

   procedure Scan_Prefixed
     (Image        : String;   --  the entire un-signed body slice
      Slice_Offset : Natural;  --  input pos of Image (Image'First) is +1
      Base         : Base_Range;
      Digits_First : out Integer;
      Digits_Last  : out Integer;
      Outcome      : out Scan_Result)
   is
      Bad_Pos    : Natural;
      Bad_Reason : Error_Kind;
   begin
      Digits_First := Image'First + 2;
      Digits_Last  := Image'Last;
      if Digits_First > Digits_Last then
         Outcome := Failed_At (Empty_Digits, Slice_Offset + 2);
         return;
      end if;
      Validate_Digit_Run
        (Image, Digits_First, Digits_Last, Base, Slice_Offset,
         Bad_Pos, Bad_Reason);
      if Bad_Pos /= 0 then
         Outcome := Failed_At (Bad_Reason, Bad_Pos);
         return;
      end if;
      Outcome := (Failed => False);
   end Scan_Prefixed;

   -----------------------------------------------------------------------
   --  Based scanner:  base '#' digits '#' [ ('e'|'E') ['+'] digits ]
   -----------------------------------------------------------------------

   procedure Scan_Based
     (Image        : String;
      Slice_Offset : Natural;
      Base         : out Base_Range;
      Digits_First : out Integer;
      Digits_Last  : out Integer;
      Exponent     : out Natural;
      Outcome      : out Scan_Result)
   is
      First_Hash    : Integer := 0;
      Second_Hash   : Integer := 0;
      Base_Value    : Natural := 0;
      Base_First    : constant Integer := Image'First;
      Base_Last     : Integer;
      Exp_Value     : Natural := 0;
      Bad_Pos       : Natural;
      Bad_Reason    : Error_Kind;
   begin
      Base := 2;
      Digits_First := 1;
      Digits_Last  := 0;
      Exponent     := 0;

      for I in Image'Range loop
         if Image (I) = '#' then
            First_Hash := I;
            exit;
         end if;
      end loop;
      if First_Hash = 0 then
         Outcome := Failed_At (Malformed_Based_Literal,
                               Slice_Offset + Image'Length);
         return;
      end if;
      Base_Last := First_Hash - 1;

      if Base_Last < Base_First then
         Outcome := Failed_At (Empty_Digits, Slice_Offset + 1);
         return;
      end if;
      for I in Base_First .. Base_Last loop
         if not Is_Ascii_Digit (Image (I)) then
            Outcome := Failed_At (Invalid_Character,
                                  Slice_Offset + (I - Image'First + 1));
            return;
         end if;
         if Base_Value > (Natural'Last - Digit_Value (Image (I))) / 10 then
            Outcome := Failed_At (Base_Out_Of_Range,
                                  Slice_Offset + (I - Image'First + 1));
            return;
         end if;
         Base_Value := Base_Value * 10 + Digit_Value (Image (I));
      end loop;
      if Base_Value not in 2 .. 16 then
         Outcome := Failed_At (Base_Out_Of_Range,
                               Slice_Offset + (Base_Last - Image'First + 1));
         return;
      end if;

      for I in First_Hash + 1 .. Image'Last loop
         if Image (I) = '#' then
            Second_Hash := I;
            exit;
         end if;
         if Image (I) = '.' then
            Outcome := Failed_At (Invalid_Character,
                                  Slice_Offset + (I - Image'First + 1));
            return;
         end if;
      end loop;
      if Second_Hash = 0 then
         Outcome := Failed_At (Malformed_Based_Literal,
                               Slice_Offset + Image'Length);
         return;
      end if;
      Digits_First := First_Hash + 1;
      Digits_Last  := Second_Hash - 1;

      Validate_Digit_Run
        (Image, Digits_First, Digits_Last, Base_Range (Base_Value),
         Slice_Offset, Bad_Pos, Bad_Reason);
      if Bad_Pos /= 0 then
         Outcome := Failed_At (Bad_Reason, Bad_Pos);
         return;
      end if;

      if Second_Hash < Image'Last then
         declare
            I    : Integer := Second_Hash + 1;
            Ch   : Character := Image (I);
         begin
            if Ch /= 'e' and then Ch /= 'E' then
               Outcome := Failed_At (Malformed_Based_Literal,
                                     Slice_Offset + (I - Image'First + 1));
               return;
            end if;
            I := I + 1;
            if I > Image'Last then
               Outcome := Failed_At (Empty_Digits,
                                     Slice_Offset + (I - Image'First + 1));
               return;
            end if;
            if Image (I) = '+' then
               I := I + 1;
            elsif Image (I) = '-' then
               Outcome := Failed_At (Unexpected_Exponent,
                                     Slice_Offset + (I - Image'First + 1));
               return;
            end if;
            if I > Image'Last then
               Outcome := Failed_At (Empty_Digits,
                                     Slice_Offset + (I - Image'First + 1));
               return;
            end if;
            declare
               Prev_Was_Digit : Boolean := False;
               Any_Seen       : Boolean := False;
            begin
               while I <= Image'Last loop
                  Ch := Image (I);
                  if Ch = '_' then
                     if not Prev_Was_Digit then
                        Outcome := Failed_At (Bad_Underscore,
                                              Slice_Offset
                                                + (I - Image'First + 1));
                        return;
                     end if;
                     Prev_Was_Digit := False;
                  elsif Is_Ascii_Digit (Ch) then
                     if Exp_Value > (Natural'Last - Digit_Value (Ch)) / 10
                     then
                        Outcome := Failed_At (Overflow,
                                              Slice_Offset
                                                + (I - Image'First + 1));
                        return;
                     end if;
                     Exp_Value := Exp_Value * 10 + Digit_Value (Ch);
                     Prev_Was_Digit := True;
                     Any_Seen := True;
                  else
                     Outcome := Failed_At (Invalid_Character,
                                           Slice_Offset
                                             + (I - Image'First + 1));
                     return;
                  end if;
                  I := I + 1;
               end loop;
               if not Any_Seen then
                  Outcome := Failed_At (Empty_Digits,
                                        Slice_Offset + Image'Length);
                  return;
               end if;
               if not Prev_Was_Digit then
                  Outcome := Failed_At (Bad_Underscore,
                                        Slice_Offset + Image'Length);
                  return;
               end if;
            end;
         end;
      end if;

      Base     := Base_Range (Base_Value);
      Exponent := Exp_Value;
      Outcome  := (Failed => False);
   end Scan_Based;

   -----------------------------------------------------------------------
   --  Shared front end for Parse and Parse_Exact: sign, empty checks and
   --  format dispatch to the scanners.  On success, Lit describes the
   --  literal: for Format_Decimal the digits and exponent live in P; for
   --  the other formats they are the digit run [Digits_First .. Digits_Last]
   --  of Image (absolute indices) and the Ada based exponent.
   -----------------------------------------------------------------------

   type Scanned_Literal is record
      Kind         : Format_Kind := Format_Empty;
      Is_Negative  : Boolean := False;
      Base         : Base_Range := 2;
      Digits_First : Integer := 1;
      Digits_Last  : Integer := 0;
      Exponent     : Natural := 0;
   end record;

   procedure Scan_Literal
     (Image         : String;
      Decimal_Point : Wide_Character;
      P             : out Vaton.Number_Pieces;
      Lit           : out Scanned_Literal;
      Outcome       : out Scan_Result)
   is
      Is_Negative : Boolean;
      Body_First  : Positive;
      Body_Last   : Natural;
   begin
      Lit := (others => <>);
      if Image'Length = 0 then
         Outcome := Failed_At (Empty_Input, 1);
         return;
      end if;
      Strip_Sign (Image, Is_Negative, Body_First, Body_Last);
      Lit.Is_Negative := Is_Negative;
      if Body_First > Body_Last then
         Outcome := Failed_At (Empty_Digits, Body_First - Image'First + 1);
         return;
      end if;

      declare
         Body_Slice : constant String := Image (Body_First .. Body_Last);
         Slice_Off  : constant Natural := Body_First - Image'First;
         Fmt        : constant Detected_Format := Detect_Format (Body_Slice);
      begin
         case Fmt.Kind is
            when Format_Empty =>
               Outcome := Failed_At (Empty_Digits, Slice_Off + 1);
            when Format_Decimal =>
               Lit.Kind := Format_Decimal;
               Scan_Decimal (Body_Slice, Slice_Off, Is_Negative,
                             Decimal_Point, P, Outcome);
            when Format_Prefixed =>
               Lit.Kind := Format_Prefixed;
               Lit.Base := Fmt.Prefix_Base;
               Scan_Prefixed (Body_Slice, Slice_Off, Lit.Base,
                              Lit.Digits_First, Lit.Digits_Last, Outcome);
            when Format_Based =>
               Lit.Kind := Format_Based;
               Scan_Based (Body_Slice, Slice_Off, Lit.Base,
                           Lit.Digits_First, Lit.Digits_Last,
                           Lit.Exponent, Outcome);
         end case;
      end;
   end Scan_Literal;

   -----------------------------------------------------------------------
   --  Exact value construction (never evaluates a power of the radix).
   -----------------------------------------------------------------------

   --  Acc := Acc * Radix + each digit of Pieces, in order.
   procedure Append_Digits
     (Acc    : in out BI.Big_Integer;
      Radix  : BI.Big_Integer;
      Pieces : Vaton.Digit_Array.Unbound_Array)
   is
      Len : constant Natural := Vaton.Digit_Array.Length (Pieces);
      First : constant Positive := Vaton.Digit_Array.First_Index (Pieces);
   begin
      for K in 0 .. Len - 1 loop
         Acc := Acc * Radix
                + BI.To_Big_Integer
                    (Integer (Vaton.Digit_Array.Element (Pieces, First + K)));
      end loop;
   end Append_Digits;

   function Decimal_Exact
     (P : Vaton.Number_Pieces; Is_Negative : Boolean) return Exact_Value
   is
      Ten         : constant BI.Big_Integer := BI.To_Big_Integer (10);
      Significand : BI.Big_Integer := BI.To_Big_Integer (0);
      Scale       : BI.Big_Integer := BI.To_Big_Integer (0);
   begin
      Append_Digits (Significand, Ten, P.Whole);
      Append_Digits (Significand, Ten, P.Fraction);

      if P.Has_Exponent then
         Append_Digits (Scale, Ten, P.Exponent);
         if P.Exponent_Is_Negative then
            Scale := -Scale;
         end if;
      end if;
      Scale := Scale
               - BI.To_Big_Integer
                   (Vaton.Digit_Array.Length (P.Fraction));

      return (Negative    => Is_Negative,
              Significand => Significand,
              Radix       => 10,
              Scale       => Scale);
   end Decimal_Exact;

   function Based_Exact
     (Image : String; Lit : Scanned_Literal) return Exact_Value
   is
      Significand : BI.Big_Integer;
   begin
      --  Exponent 0: digits only; the Ada exponent is carried as Scale.
      Big_Accumulate (Image, Lit.Digits_First, Lit.Digits_Last, Lit.Base,
                      0, Significand);
      return (Negative    => Lit.Is_Negative,
              Significand => Significand,
              Radix       => Lit.Base,
              Scale       => BI.To_Big_Integer (Integer (Lit.Exponent)));
   end Based_Exact;

   -----------------------------------------------------------------------
   --  Public String entry points
   -----------------------------------------------------------------------

   function Parse
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      P       : Vaton.Number_Pieces;
      Lit     : Scanned_Literal;
      Outcome : Scan_Result;
   begin
      Scan_Literal (Image, Decimal_Point, P, Lit, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;

      case Lit.Kind is
         when Format_Empty =>
            return (Status => Error, Reason => Empty_Digits, Position => 1);
         when Format_Decimal =>
            return (Status => Ok, Value => Vaton.To_Number (P));
         when Format_Prefixed | Format_Based =>
            return Finish_Non_Decimal
                     (Image, Lit.Digits_First, Lit.Digits_Last, Lit.Base,
                      Lit.Exponent, Lit.Is_Negative,
                      End_Pos => Image'Length);
      end case;
   end Parse;

   function Parse_Exact
     (Image         : String;
      Decimal_Point : Wide_Character := '.') return Exact_Result
   is
      P       : Vaton.Number_Pieces;
      Lit     : Scanned_Literal;
      Outcome : Scan_Result;
   begin
      Scan_Literal (Image, Decimal_Point, P, Lit, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;

      case Lit.Kind is
         when Format_Empty =>
            return (Status => Error, Reason => Empty_Digits, Position => 1);
         when Format_Decimal =>
            return (Status => Ok,
                    Value  => Decimal_Exact (P, Lit.Is_Negative));
         when Format_Prefixed | Format_Based =>
            return (Status => Ok, Value => Based_Exact (Image, Lit));
      end case;
   end Parse_Exact;

   -----------------------------------------------------------------------
   --  Wide_String and Wide_Wide_String overloads
   -----------------------------------------------------------------------

   procedure Narrow_Image
     (Image   : Wide_String;
      Narrow  : out String;
      Outcome : out Scan_Result)
   is
   begin
      for I in Image'Range loop
         declare
            Pos : constant Natural := Wide_Character'Pos (Image (I));
         begin
            if Pos > 127 then
               Outcome := Failed_At (Invalid_Character, I - Image'First + 1);
               return;
            end if;
            Narrow (I - Image'First + 1) := Character'Val (Pos);
         end;
      end loop;
      Outcome := (Failed => False);
   end Narrow_Image;

   procedure Narrow_Image
     (Image   : Wide_Wide_String;
      Narrow  : out String;
      Outcome : out Scan_Result)
   is
   begin
      for I in Image'Range loop
         declare
            Pos : constant Natural := Wide_Wide_Character'Pos (Image (I));
         begin
            if Pos > 127 then
               Outcome := Failed_At (Invalid_Character, I - Image'First + 1);
               return;
            end if;
            Narrow (I - Image'First + 1) := Character'Val (Pos);
         end;
      end loop;
      Outcome := (Failed => False);
   end Narrow_Image;

   function Parse
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Narrow  : String (1 .. Image'Length);
      Outcome : Scan_Result;
   begin
      Narrow_Image (Image, Narrow, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;
      return Parse (Narrow, Decimal_Point);
   end Parse;

   function Parse
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Parse_Result
   is
      Narrow  : String (1 .. Image'Length);
      Outcome : Scan_Result;
   begin
      Narrow_Image (Image, Narrow, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;
      return Parse (Narrow, Decimal_Point);
   end Parse;

   function Parse_Exact
     (Image         : Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result
   is
      Narrow  : String (1 .. Image'Length);
      Outcome : Scan_Result;
   begin
      Narrow_Image (Image, Narrow, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;
      return Parse_Exact (Narrow, Decimal_Point);
   end Parse_Exact;

   function Parse_Exact
     (Image         : Wide_Wide_String;
      Decimal_Point : Wide_Character := '.') return Exact_Result
   is
      Narrow  : String (1 .. Image'Length);
      Outcome : Scan_Result;
   begin
      Narrow_Image (Image, Narrow, Outcome);
      if Outcome.Failed then
         return (Status => Error, Reason => Outcome.Reason,
                 Position => Outcome.Position);
      end if;
      return Parse_Exact (Narrow, Decimal_Point);
   end Parse_Exact;

end Radix_Literals;
