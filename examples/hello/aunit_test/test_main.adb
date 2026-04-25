with Ada.Command_Line;
with AUnit;            use AUnit;
with AUnit.Run;
with AUnit.Reporter.Text;
with Util_Suite;

procedure Test_Main is
   function Run is new AUnit.Run.Test_Runner_With_Status (Util_Suite.Suite);
   Reporter : AUnit.Reporter.Text.Text_Reporter;
begin
   if Run (Reporter) /= AUnit.Success then
      Ada.Command_Line.Set_Exit_Status (1);
   end if;
end Test_Main;
