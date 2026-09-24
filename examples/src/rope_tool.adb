--  rope_tool -- command-line demo of Ropes, the Ada port of
--  RopeTool.Mod (~/Repos/Oberon/Ropes/RopeTool.Mod). See
--  PLAN.md's "Command-line tool (rope_tool)" section for how this
--  fits the phased implementation plan, and Rope_Tool_Args for the
--  actual command definitions.

with Arg_Parser;     use Arg_Parser;
with Rope_Tool_Args; use Rope_Tool_Args;

procedure Rope_Tool is
begin
   Parse_Arguments (Main_Parser);
end Rope_Tool;
