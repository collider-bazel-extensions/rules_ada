package Ada_Greet is

   function Compute (X : Integer) return Integer
     with Export        => True,
          Convention    => C,
          External_Name => "ada_compute";

end Ada_Greet;
