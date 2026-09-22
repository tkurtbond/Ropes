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

   --  --- index S PATTERN FROM --- (1-based; Ropes.Index, Rope pattern, Going => Forward -- RopeTool.Mod's find)
   function Index_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- rindex S PATTERN FROM --- (1-based; Ropes.Index, Rope pattern, Going => Backward -- RopeTool.Mod's rfind)
   function Rindex_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- indexchar S CH FROM --- (1-based; Ropes.Index, Character pattern, Going => Forward)
   function Indexchar_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- rindexchar S CH FROM --- (1-based; Ropes.Index, Character pattern, Going => Backward)
   function Rindexchar_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- split S SEP --- (Ropes.Split, Rope separator; one piece per line)
   function Split_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- chars S --- (Ropes.Cursor/Iterable, via "for Ch of S loop"; one character per line)
   function Chars_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- trim S --- (Ropes.Trim, default Whitespace both sides)
   function Trim_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- triml S --- (Ropes.Trim, Right => Ada.Strings.Maps.Null_Set)
   function Triml_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- trimr S --- (Ropes.Trim, Left => Ada.Strings.Maps.Null_Set)
   function Trimr_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- upper S --- (Ropes.To_Upper)
   function Upper_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- lower S --- (Ropes.To_Lower)
   function Lower_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- capitalize S --- (Ropes.Capitalize)
   function Capitalize_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- uncapitalize S --- (Ropes.Uncapitalize)
   function Uncapitalize_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

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
           Options     => null)),
     Make_Command
       ("index",
        Make_Parser
          (Description => "index S PATTERN FROM  Print the index of PATTERN in S at or after FROM (1-based), or 0.",
           Handler     => Index_Argument_Handler'Access, Options => null)),
     Make_Command
       ("rindex",
        Make_Parser
          (Description => "rindex S PATTERN FROM  Print the index of the last PATTERN in S at or before FROM (1-based), or 0.",
           Handler     => Rindex_Argument_Handler'Access, Options => null)),
     Make_Command
       ("indexchar",
        Make_Parser
          (Description => "indexchar S CH FROM  Print the index of CH in S at or after FROM (1-based), or 0.",
           Handler     => Indexchar_Argument_Handler'Access, Options => null)),
     Make_Command
       ("rindexchar",
        Make_Parser
          (Description => "rindexchar S CH FROM  Print the index of CH in S at or before FROM (1-based), or 0.",
           Handler     => Rindexchar_Argument_Handler'Access, Options => null)),
     Make_Command
       ("split",
        Make_Parser
          (Description => "split S SEP  Print each piece of S split on SEP, one per line.",
           Handler     => Split_Argument_Handler'Access, Options => null)),
     Make_Command
       ("chars",
        Make_Parser
          (Description => "chars S  Print each character of S, one per line (""for Ch of S loop"").",
           Handler     => Chars_Argument_Handler'Access, Options => null)),
     Make_Command
       ("trim",
        Make_Parser
          (Description => "trim S  Print S with leading and trailing whitespace removed.", Handler => Trim_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("triml",
        Make_Parser
          (Description => "triml S  Print S with leading whitespace removed.", Handler => Triml_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("trimr",
        Make_Parser
          (Description => "trimr S  Print S with trailing whitespace removed.", Handler => Trimr_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("upper",
        Make_Parser
          (Description => "upper S  Print S with ASCII letters uppercased.", Handler => Upper_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("lower",
        Make_Parser
          (Description => "lower S  Print S with ASCII letters lowercased.", Handler => Lower_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("capitalize",
        Make_Parser
          (Description => "capitalize S  Print S with its first character uppercased (ASCII only).",
           Handler     => Capitalize_Argument_Handler'Access, Options => null)),
     Make_Command
       ("uncapitalize",
        Make_Parser
          (Description => "uncapitalize S  Print S with its first character lowercased (ASCII only).",
           Handler     => Uncapitalize_Argument_Handler'Access, Options => null))];

   Main_Parser : Parser :=
     Make_Parser
       ("rope_tool [options] command arguments..." & ASCII.LF & ASCII.LF &
        "Command-line demo of Ropes: each subcommand builds one or two ropes " &
        "from its string arguments and prints the result of one Ropes operation.",
        Main_Argument_Handler'Access, Main_Options'Access, Commands'Access);

end Rope_Tool_Args;
