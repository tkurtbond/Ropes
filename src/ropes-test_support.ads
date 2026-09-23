--  Test-only accessor for a Rope's internal tree depth. Not part of
--  Ropes's supported public API -- Depth is deliberately not exposed
--  there (see PLAN.md's "Core design"). Exists solely so test_*.adb
--  programs can directly confirm Balance actually bounds tree depth
--  (Phase 2's "Stress test: ... confirm depth stays bounded", in
--  PLAN.md's phased plan), instead of standing in a fragile
--  stack-overflow-detection or timing-based test for a direct check.

package Ropes.Test_Support is

   function Depth (Source : Rope) return Natural;

end Ropes.Test_Support;
