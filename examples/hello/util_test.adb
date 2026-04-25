with Ada.Command_Line;
with Util;
procedure Util_Test is
   Expected : constant String := "hello from rules_ada (v2)";
begin
   if Util.Greeting /= Expected then
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Util_Test;
