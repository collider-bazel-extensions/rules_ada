with Ada.Command_Line;
with Util;
procedure Failing_Test is
begin
   if Util.Greeting = "this will never match" then
      Ada.Command_Line.Set_Exit_Status (0);
   else
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Failing_Test;
