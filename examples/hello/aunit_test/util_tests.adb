with AUnit.Assertions; use AUnit.Assertions;
with AUnit.Test_Cases;
with Util;

package body Util_Tests is

   procedure Test_Greeting (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
   begin
      Assert (Util.Greeting = "hello from rules_ada (v2)",
              "Util.Greeting did not match expected value");
   end Test_Greeting;

   procedure Register_Tests (T : in out Util_Test) is
   begin
      AUnit.Test_Cases.Registration.Register_Routine
        (T, Test_Greeting'Access, "Greeting returns expected string");
   end Register_Tests;

   function Name (T : Util_Test) return Message_String is
      pragma Unreferenced (T);
   begin
      return Format ("Util_Tests");
   end Name;

end Util_Tests;
