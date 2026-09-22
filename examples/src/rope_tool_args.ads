--  Command definitions for rope_tool, the Ada port of RopeTool.Mod
--  (~/Repos/Oberon/oberon-tools/RopeTool.Mod): a git-style CLI
--  exposing Ropes operations as subcommands. Built on Arg_Parser
--  (~/Repos/Ada/arg_parser, installed under
--  /usr/local/sw/versions/ada/), modeled directly on its own
--  Compound_Args example (examples/src/compound_args.ads there) for
--  the multiple-commands-like-git pattern: each subcommand is its own
--  sub-parser whose Argument_Handler is called once per positional
--  argument, accumulating arguments until it has seen enough to act
--  -- the same shape RopeTool.Mod itself uses, there built on the
--  Oberon-2 ArgParser instead.
--
--  Only wraps what Ropes has implemented so far -- see PLAN.md's
--  phased plan and its "Command-line tool (rope_tool)" section. Add a
--  subcommand here in the same phase that adds its underlying Ropes
--  operation, not before and not as a stub for something unimplemented.

with Arg_Parser; use Arg_Parser;

package Rope_Tool_Args is

   function Do_Help return Boolean;
   function Main_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   Main_Options : aliased Option_Array := [Make_Option ("Display this help message and exit.", 'h', "help", Do_Help'Access)];

   --  --- cat A B ---
   function Cat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- len S ---
   function Len_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- fetch S I --- (I is 1-based, unlike RopeTool.Mod's 0-based Fetch)
   function Fetch_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- slice S LOW HIGH --- (1-based inclusive, unlike RopeTool.Mod's sub S START LEN)
   function Slice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- insert S BEFORE INS --- (1-based, unlike RopeTool.Mod's insert S POS INS)
   function Insert_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- delete S FROM THROUGH --- (1-based inclusive, unlike RopeTool.Mod's remove S POS LEN)
   function Delete_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- cmp A B --- (built from "="/"<" -- Ropes has no public Compare function; see PLAN.md's "Comparison")
   function Cmp_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   Commands : aliased Command_Array :=
     [Make_Command
       ("cat",
        Make_Parser
          (Description => "cat A B  Print the concatenation of A and B.", Handler => Cat_Argument_Handler'Access, Options => null)),
     Make_Command
       ("len",
        Make_Parser (Description => "len S  Print the length of S.", Handler => Len_Argument_Handler'Access, Options => null)),
     Make_Command
       ("fetch",
        Make_Parser
          (Description => "fetch S I  Print the character of S at index I (1-based).", Handler => Fetch_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("slice",
        Make_Parser
          (Description => "slice S LOW HIGH  Print the slice of S from LOW through HIGH, inclusive (1-based).",
           Handler     => Slice_Argument_Handler'Access, Options => null)),
     Make_Command
       ("insert",
        Make_Parser
          (Description => "insert S BEFORE INS  Print S with INS inserted before index BEFORE (1-based).",
           Handler     => Insert_Argument_Handler'Access, Options => null)),
     Make_Command
       ("delete",
        Make_Parser
          (Description => "delete S FROM THROUGH  Print S with FROM through THROUGH removed, inclusive (1-based).",
           Handler     => Delete_Argument_Handler'Access, Options => null)),
     Make_Command
       ("cmp",
        Make_Parser
          (Description => "cmp A B  Print -1, 0 or 1: how A compares to B.", Handler => Cmp_Argument_Handler'Access,
           Options     => null))];

   Main_Parser : Parser :=
     Make_Parser
       ("rope_tool [options] command arguments..." & ASCII.LF & ASCII.LF &
        "Command-line demo of Ropes: each subcommand builds one or two ropes " &
        "from its string arguments and prints the result of one Ropes operation.",
        Main_Argument_Handler'Access, Main_Options'Access, Commands'Access);

end Rope_Tool_Args;
