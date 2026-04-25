with AUnit;            use AUnit;
with AUnit.Test_Cases;  use AUnit.Test_Cases;

package Util_Tests is
   type Util_Test is new Test_Case with null record;
   procedure Register_Tests (T : in out Util_Test);
   function Name (T : Util_Test) return Message_String;
end Util_Tests;
