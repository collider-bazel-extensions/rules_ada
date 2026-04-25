with Util_Tests;

package body Util_Suite is

   Util_Tc : aliased Util_Tests.Util_Test;
   Result  : aliased Test_Suite;

   function Suite return Access_Test_Suite is
   begin
      Result.Add_Test (Util_Tc'Access);
      return Result'Access;
   end Suite;

end Util_Suite;
