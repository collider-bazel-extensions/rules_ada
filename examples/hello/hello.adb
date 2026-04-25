with Ada.Text_IO;
with Util;
package body Hello is
   procedure Say is
   begin
      Ada.Text_IO.Put_Line (Util.Greeting);
   end Say;
end Hello;
