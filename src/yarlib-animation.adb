package body Yarlib.Animation with
   SPARK_Mode
is

   procedure Advance (A : in out Animation; Dt : Scalar) is
      --  How long each animation cycle should take
      Cycle : constant Scalar := Scalar (A.Frame_Count) / A.Frames_Per_Second;
   begin
      --  At most Max_Frames / Min_Frames_Per_Second = 80_000 s. Stated
      --  once here so the prover can use it for the Post
      pragma Assert (Cycle <= Max_Time);
      A.Time := A.Time + Dt;
      if A.Looping then
         while A.Time >= Cycle loop
            --  Tells the prover the clock never goes negative in here,
            --  which the Post needs after the loop
            pragma Loop_Invariant (A.Time >= 0.0);
            A.Time := A.Time - Cycle;
         end loop;
      else
         A.Time := Scalar'Min (A.Time, Cycle);
      end if;
      --  The clock's half of Valid, as two small steps for the prover
      pragma Assert (A.Time >= 0.0);
      pragma Assert (A.Time <= Max_Time);
   end Advance;

   function Source (A : Animation) return Rectangle is
      --  Frame number from the clock, before wrapping or clamping
      Raw_Frame : constant Natural :=
        Natural (Scalar'Floor (A.Time * A.Frames_Per_Second));

      --  The frame to show, 0 .. Frame_Count - 1
      Frame : constant Natural :=
        (if A.Looping then Raw_Frame mod A.Frame_Count
         else Natural'Min (Raw_Frame, A.Frame_Count - 1));

      --  Where that frame sits on the sheet's grid
      Col : constant Natural := Frame mod A.Columns;
      Row : constant Natural := Frame / A.Columns;
   begin
      --  Convert to Scalar before multiplying, so no Integer can overflow
      return (X      => Scalar (Col) * Scalar (A.Frame_Width),
              Y      => Scalar (Row) * Scalar (A.Frame_Height),
              Width  => Scalar (A.Frame_Width),
              Height => Scalar (A.Frame_Height));
   end Source;

   --  Advance caps Time at exactly this same expression, so >= is safe
   function Is_Finished (A : Animation) return Boolean is
     (not A.Looping
      and then A.Time >= Scalar (A.Frame_Count) / A.Frames_Per_Second);

end Yarlib.Animation;
