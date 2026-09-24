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

   --  --- repeat S N --- (Ropes."*", N * S, String S since Phase 23)
   function Repeat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- make LEN CH --- (Ropes."*", LEN * CH)
   function Make_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- bigcat N1 CH1 N2 CH2 --- (prints Length (N1 * CH1 & N2 * CH2); Ropes."*"/"&" share subtrees, so even huge N1/N2 stay cheap)
   function Bigcat_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- contains S CH FROM --- (Ropes.Index, Character pattern, Going => Forward, /= 0)
   function Contains_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- escaped S --- (Ropes.Escape)
   function Escaped_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- overwrite S POS NEW --- (Ropes.Overwrite; 1-based, no Rope.Mod/RopeTool.Mod counterpart -- see PLAN.md's "Deferred / stretch")
   function Overwrite_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- head S COUNT --- (Ropes.Head, default Pad; no Rope.Mod/RopeTool.Mod counterpart)
   function Head_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- tail S COUNT --- (Ropes.Tail, default Pad; no Rope.Mod/RopeTool.Mod counterpart)
   function Tail_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- lines FILE --- (Ropes.Text_IO.Get_Line, File and Current_Input overloads; no Rope.Mod/RopeTool.Mod counterpart)
   function Lines_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- readfile FILE --- (Ropes.Stream_IO.Read_File; no Rope.Mod/RopeTool.Mod counterpart before Phase 13)
   function Readfile_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- copyslice S LOW HIGH T POS --- (Ropes.Copy_Slice, Rope.Mod's Blit; Phase 15)
   function Copyslice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- replaceslice S LOW HIGH BY --- (Ropes.Replace_Slice, String By; Phase 17)
   function Replaceslice_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- count S PATTERN --- (Ropes.Count, String pattern; Phase 17)
   function Count_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- countset S CHARS --- (Ropes.Count, Character_Set To_Set (CHARS); Phase 17)
   function Countset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- indexset / rindexset S CHARS FROM --- (Ropes.Index, Character_Set To_Set (CHARS), Test => Inside,
   --  Going => Forward/Backward; Phase 17)
   function Indexset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;
   function Rindexset_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- nonblank / rnonblank S FROM --- (Ropes.Index_Non_Blank, Going => Forward/Backward; Phase 19)
   function Nonblank_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;
   function Rnonblank_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- findtoken S CHARS FROM --- (Ropes.Find_Token, Character_Set To_Set (CHARS), Test => Inside; Phase 19)
   function Findtoken_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- translate S FROM TO --- (Ropes.Translate, Ada.Strings.Maps.To_Mapping (FROM, TO); Phase 22)
   function Translate_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- replaceelement S INDEX CH --- (Ropes.Replace_Element; Phase 23)
   function Replaceelement_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- cmpci A B --- (built from Equal_Case_Insensitive/Less_Case_Insensitive, as cmp is from "="/"<"; Phase 24)
   function Cmpci_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- hash S / hashci S --- (Ropes.Hash / Ropes.Hash_Case_Insensitive; Phase 24)
   function Hash_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;
   function Hashci_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

   --  --- indexci S PATTERN / countci S PATTERN --- (Ropes.Index/Count with a Mapping, function and table forms; Phase 25)
   function Indexci_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;
   function Countci_Argument_Handler (Start_With : Positive; Arg : String) return Boolean;

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
           Handler     => Uncapitalize_Argument_Handler'Access, Options => null)),
     Make_Command
       ("repeat",
        Make_Parser
          (Description => "repeat S N  Print N concatenated copies of S.", Handler => Repeat_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("make",
        Make_Parser
          (Description => "make LEN CH  Print a rope of LEN copies of CH.", Handler => Make_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("bigcat",
        Make_Parser
          (Description => "bigcat N1 CH1 N2 CH2  Print the length of N1 copies of CH1 concatenated with N2 copies of CH2.",
           Handler     => Bigcat_Argument_Handler'Access, Options => null)),
     Make_Command
       ("contains",
        Make_Parser
          (Description => "contains S CH FROM  Print TRUE or FALSE: whether CH occurs in S at or after FROM.",
           Handler     => Contains_Argument_Handler'Access, Options => null)),
     Make_Command
       ("escaped",
        Make_Parser
          (Description => "escaped S  Print S with special and non-printable characters escaped.",
           Handler     => Escaped_Argument_Handler'Access, Options => null)),
     Make_Command
       ("overwrite",
        Make_Parser
          (Description => "overwrite S POS NEW  Print S with NEW overwriting it starting at index POS (1-based).",
           Handler     => Overwrite_Argument_Handler'Access, Options => null)),
     Make_Command
       ("head",
        Make_Parser
          (Description => "head S COUNT  Print the first COUNT characters of S, space-padded if S is shorter.",
           Handler     => Head_Argument_Handler'Access, Options => null)),
     Make_Command
       ("tail",
        Make_Parser
          (Description => "tail S COUNT  Print the last COUNT characters of S, space-padded if S is shorter.",
           Handler     => Tail_Argument_Handler'Access, Options => null)),
     Make_Command
       ("lines",
        Make_Parser
          (Description =>
             "lines FILE  Read FILE (standard input if FILE is -) and print each line's length, a space, and the line.",
           Handler     => Lines_Argument_Handler'Access, Options => null)),
     Make_Command
       ("readfile",
        Make_Parser
          (Description =>
             "readfile FILE  Read all of FILE, byte for byte, and print its length, a space, and its contents escaped.",
           Handler     => Readfile_Argument_Handler'Access, Options => null)),
     Make_Command
       ("copyslice",
        Make_Parser
          (Description =>
             "copyslice S LOW HIGH T POS  Print T with S's characters LOW through HIGH (1-based, inclusive) copied into it at POS.",
           Handler     => Copyslice_Argument_Handler'Access, Options => null)),
     Make_Command
       ("replaceslice",
        Make_Parser
          (Description =>
             "replaceslice S LOW HIGH BY  Print S with its characters LOW through HIGH (1-based, inclusive) replaced by BY.",
           Handler     => Replaceslice_Argument_Handler'Access, Options => null)),
     Make_Command
       ("count",
        Make_Parser
          (Description => "count S PATTERN  Print the number of nonoverlapping occurrences of PATTERN in S.",
           Handler     => Count_Argument_Handler'Access, Options => null)),
     Make_Command
       ("countset",
        Make_Parser
          (Description => "countset S CHARS  Print the number of characters of S that are any of CHARS.",
           Handler     => Countset_Argument_Handler'Access, Options => null)),
     Make_Command
       ("indexset",
        Make_Parser
          (Description =>
             "indexset S CHARS FROM  Print the index of the first character at or after FROM in S that is any of CHARS, or 0.",
           Handler     => Indexset_Argument_Handler'Access, Options => null)),
     Make_Command
       ("rindexset",
        Make_Parser
          (Description =>
             "rindexset S CHARS FROM  Print the index of the last character at or before FROM in S that is any of CHARS, or 0.",
           Handler     => Rindexset_Argument_Handler'Access, Options => null)),
     Make_Command
       ("nonblank",
        Make_Parser
          (Description => "nonblank S FROM  Print the index of the first non-space character at or after FROM in S, or 0.",
           Handler     => Nonblank_Argument_Handler'Access, Options => null)),
     Make_Command
       ("rnonblank",
        Make_Parser
          (Description => "rnonblank S FROM  Print the index of the last non-space character at or before FROM in S, or 0.",
           Handler     => Rnonblank_Argument_Handler'Access, Options => null)),
     Make_Command
       ("findtoken",
        Make_Parser
          (Description =>
             "findtoken S CHARS FROM  Print FIRST LAST: the first run of characters that are any of CHARS, at or after FROM in S.",
           Handler     => Findtoken_Argument_Handler'Access, Options => null)),
     Make_Command
       ("translate",
        Make_Parser
          (Description => "translate S FROM TO  Print S with each character in FROM replaced by the one at the same place in TO.",
           Handler     => Translate_Argument_Handler'Access, Options => null)),
     Make_Command
       ("replaceelement",
        Make_Parser
          (Description => "replaceelement S INDEX CH  Print S with its character at INDEX (1-based) replaced by CH.",
           Handler     => Replaceelement_Argument_Handler'Access, Options => null)),
     Make_Command
       ("cmpci",
        Make_Parser
          (Description => "cmpci A B  Print -1, 0 or 1: how A compares to B, ignoring case.",
           Handler     => Cmpci_Argument_Handler'Access, Options => null)),
     Make_Command
       ("hash",
        Make_Parser (Description => "hash S  Print the hash of S.", Handler => Hash_Argument_Handler'Access, Options => null)),
     Make_Command
       ("hashci",
        Make_Parser
          (Description => "hashci S  Print the case-insensitive hash of S.", Handler => Hashci_Argument_Handler'Access,
           Options     => null)),
     Make_Command
       ("indexci",
        Make_Parser
          (Description => "indexci S PATTERN  Print the index of the first occurrence of PATTERN in S, ignoring case, or 0.",
           Handler     => Indexci_Argument_Handler'Access, Options => null)),
     Make_Command
       ("countci",
        Make_Parser
          (Description => "countci S PATTERN  Print the number of nonoverlapping occurrences of PATTERN in S, ignoring case.",
           Handler     => Countci_Argument_Handler'Access, Options => null))];

   Main_Parser : Parser :=
     Make_Parser
       ("rope_tool [options] command arguments..." & ASCII.LF & ASCII.LF &
        "Command-line demo of Ropes: each subcommand builds one or two ropes " &
        "from its string arguments and prints the result of one Ropes operation.",
        Main_Argument_Handler'Access, Main_Options'Access, Commands'Access);

end Rope_Tool_Args;
