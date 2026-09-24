--  Phase 22 checks: Translate with a Character_Mapping or a
--  Character_Mapping_Function, Ada.Strings.Unbounded.Translate's two
--  function forms. No Rope.Mod
--  counterpart. The oracle is Ada.Strings.Fixed.Translate on the same
--  text, over a rope of 9-character leaves (9 + 9 > 16, the short-leaf
--  merge threshold, so they stay separate) and one built by "*", whose
--  subtrees are shared.

with Ada.Characters.Handling;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Fixed;
with Ada.Strings.Maps; use Ada.Strings.Maps;
with Ada.Strings.Maps.Constants;
with Ada.Text_IO;      use Ada.Text_IO;
with Ropes;            use Ropes;
with Ropes.Test_Support;

procedure Test_Translate is

   Passed, Failed : Natural := 0;

   procedure Check (Cond : Boolean; Name : String) is
   begin
      if Cond then
         Put_Line ("ok   - " & Name);
         Passed := Passed + 1;
      else
         Put_Line ("FAIL - " & Name);
         Failed := Failed + 1;
      end if;
   end Check;

   --  Source in 9-character leaves.
   function Chunked (Source : String) return Rope is
      Result : Rope;
      I      : Positive := Source'First;
   begin
      while I <= Source'Last loop
         Result := Result & From_String (Source (I .. Natural'Min (I + 8, Source'Last)));
         I      := I + 9;
      end loop;
      return Result;
   end Chunked;

   Text   : constant String := "The Quick Brown Fox, 1234567890, jumps over the lazy dog; THE END.";
   Chunks : constant Rope   := Chunked (Text);

   Swap        : constant Character_Mapping := To_Mapping ("abcxyz", "xyzabc");
   Upper       : Character_Mapping renames Ada.Strings.Maps.Constants.Upper_Case_Map;
   Hide_Digits : constant Character_Mapping := To_Mapping ("0123456789", "##########");

   function Agrees (R : Rope; O : String; Mapping : Character_Mapping) return Boolean is
     (To_String (Translate (R, Mapping)) = Ada.Strings.Fixed.Translate (O, Mapping));

   --  A Character_Mapping_Function must designate a library-level
   --  function (its access type is library-level), such as this one.
   Upper_Function : constant Character_Mapping_Function := Ada.Characters.Handling.To_Upper'Access;

   --  A constant null actual for a not null formal draws a
   --  compile-time warning; this call is meant to raise.
   pragma Warnings (Off, "*null-excluding formal*");
   pragma Warnings (Off, "Constraint_Error will be raised at run time");

   function Null_Function_Raises return Boolean is
      No_Function : constant Character_Mapping_Function := null;
      Unused      : Rope;
   begin
      Unused := Translate (Chunks, No_Function);
      return False;
   exception
      when Constraint_Error =>
         return True;
   end Null_Function_Raises;

   Period  : constant String := "abc,xyz;";
   Starred : constant Rope   := 1_000 * Chunked (Period);
begin
   Check (To_String (Chunks) = Text, "the test rope has the expected text");
   Check (Agrees (Chunks, Text, Swap), "To_Mapping: agrees with Ada.Strings.Fixed.Translate across leaves");
   Check (Agrees (Chunks, Text, Upper), "Constants.Upper_Case_Map: agrees with Ada.Strings.Fixed.Translate");
   Check (Agrees (Chunks, Text, Hide_Digits), "a many-to-one mapping: agrees with Ada.Strings.Fixed.Translate");
   Check (Translate (Chunks, Identity) = Chunks, "Identity leaves the text unchanged");
   Check (Translate (Null_Rope, Swap) = Null_Rope and then Is_Empty (Translate (Null_Rope, Swap)), "Null_Rope gives Null_Rope");
   Check
     (Ropes.Test_Support.Depth (Translate (Chunks, Swap)) = Ropes.Test_Support.Depth (Chunks),
      "the result keeps Source's tree shape (the same depth), as Map's does");
   Check
     (Length (Translate (Starred, Swap)) = 8_000
      and then To_String (Slice (Translate (Starred, Swap), 7_993, 8_000)) = Ada.Strings.Fixed.Translate (Period, Swap),
      "a ""*""-built rope, whose subtrees are shared");
   Check
     (To_String (Translate (Chunks, Upper_Function)) = Ada.Strings.Fixed.Translate (Text, Upper_Function),
      "Character_Mapping_Function: agrees with Ada.Strings.Fixed.Translate across leaves");
   Check
     (Translate (Chunks, Upper_Function) = Translate (Chunks, Upper)
      and then Translate (Chunks, Upper_Function) = Map (Chunks, Upper_Function),
      "Character_Mapping_Function: the same as the Character_Mapping form, and as Map");
   Check
     (Ropes.Test_Support.Depth (Translate (Chunks, Upper_Function)) = Ropes.Test_Support.Depth (Chunks)
      and then Is_Empty (Translate (Null_Rope, Upper_Function)),
      "Character_Mapping_Function: keeps Source's tree shape; Null_Rope gives Null_Rope");
   Check (Null_Function_Raises, "a null Character_Mapping_Function raises Constraint_Error");

   New_Line;
   Put_Line (Passed'Image & " /" & Natural'Image (Passed + Failed) & " tests passed.");
   if Failed > 0 then
      Set_Exit_Status (Failure);
   end if;
end Test_Translate;
