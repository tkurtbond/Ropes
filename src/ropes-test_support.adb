package body Ropes.Test_Support is

   function Depth (Source : Rope) return Natural is
   begin
      if Source.Ref.Data = null then
         return 0;
      end if;
      return Source.Ref.Data.Depth;
   end Depth;

end Ropes.Test_Support;
