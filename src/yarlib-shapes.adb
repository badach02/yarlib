with Ada.Numerics.Elementary_Functions;
with Yarlib.Batch;

package body Yarlib.Shapes is

   Unit_UV : constant Batch.Quad_Corners :=
     [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)];

   procedure Draw_Rectangle
     (Ctx : in out Context; X, Y, Width, Height : Integer; C : Color)
   is
   begin
      Draw_Rectangle_Rec
        (Ctx, (Scalar (X), Scalar (Y), Scalar (Width), Scalar (Height)), C);
   end Draw_Rectangle;

   procedure Draw_Rectangle_Rec
     (Ctx : in out Context; R : Rectangle; C : Color)
   is
      P : constant Batch.Quad_Corners :=
        [(R.X, R.Y), (R.X + R.Width, R.Y), (R.X + R.Width, R.Y + R.Height),
        (R.X, R.Y + R.Height)];
   begin
      Submit (Ctx, White_Texture, P, Unit_UV, C);
   end Draw_Rectangle_Rec;

   procedure Draw_Rectangle_Pro
     (Ctx      : in out Context; R : Rectangle; Origin : Vector2;
      Rotation :        Degrees; C : Color)
   is
      use Ada.Numerics.Elementary_Functions;
      Rad : constant Float  := Float (Rotation) * (Ada.Numerics.Pi / 180.0);
      Cs  : constant Scalar := Scalar (Cos (Rad));
      Sn  : constant Scalar := Scalar (Sin (Rad));
      function Rot (LX, LY : Scalar) return Vector2 is
        ((R.X + LX * Cs - LY * Sn, R.Y + LX * Sn + LY * Cs));
      P : constant Batch.Quad_Corners :=
        [Rot (-Origin.X, -Origin.Y), Rot (R.Width - Origin.X, -Origin.Y),
        Rot (R.Width - Origin.X, R.Height - Origin.Y),
        Rot (-Origin.X, R.Height - Origin.Y)];
   begin
      Submit (Ctx, White_Texture, P, Unit_UV, C);
   end Draw_Rectangle_Pro;

   procedure Draw_Rectangle_Lines
     (Ctx : in out Context; X, Y, Width, Height : Integer; C : Color)
   is
   begin
      Draw_Rectangle (Ctx, X, Y, Width, 1, C);
      Draw_Rectangle (Ctx, X, Y + Height - 1, Width, 1, C);
      Draw_Rectangle (Ctx, X, Y, 1, Height, C);
      Draw_Rectangle (Ctx, X + Width - 1, Y, 1, Height, C);
   end Draw_Rectangle_Lines;

   procedure Draw_Line
     (Ctx : in out Context; X1, Y1, X2, Y2 : Integer; C : Color)
   is
   begin
      Draw_Line_Ex
        (Ctx, (Scalar (X1), Scalar (Y1)), (Scalar (X2), Scalar (Y2)), 1.0, C);
   end Draw_Line;

   procedure Draw_Line_Ex
     (Ctx : in out Context; Start, Stop : Vector2; Thick : Scalar; C : Color)
   is
      use Ada.Numerics.Elementary_Functions;
      D   : constant Vector2 := Stop - Start;
      Len : constant Scalar  := Scalar (Sqrt (Float (D.X * D.X + D.Y * D.Y)));
   begin
      if Len <= 0.0 then
         return;
      end if;
      declare
         N : constant Vector2            :=
           (-D.Y / Len * Thick / 2.0, D.X / Len * Thick / 2.0);
         P : constant Batch.Quad_Corners :=
           [Start - N, Stop - N, Stop + N, Start + N];
      begin
         Submit (Ctx, White_Texture, P, Unit_UV, C);
      end;
   end Draw_Line_Ex;

   ---------------------------------------
   -- Triangles, circles, polygons, rings --
   ---------------------------------------

   Min_Segments : constant := 12;
   Max_Segments : constant := 36;

   procedure Submit_Triangle
     (Ctx : in out Context; A, B, C : Vector2; Col : Color)
   is
      --  Fourth corner repeats the third: the quad's second triangle
      --  (P1 P3 P4) has zero area. Still a whole quad for Well_Formed.
      P : constant Batch.Quad_Corners := [A, B, C, C];
   begin
      Submit (Ctx, White_Texture, P, Unit_UV, Col);
   end Submit_Triangle;

   function Segments_For (Radius : Scalar) return Positive is
      Arc : constant Float := 2.0 * Ada.Numerics.Pi * Float (Radius) / 4.0;
   begin
      if Arc <= Float (Min_Segments) then
         return Min_Segments;
      elsif Arc >= Float (Max_Segments) then
         return Max_Segments;
      else
         return Positive (Float'Rounding (Arc));
      end if;
   end Segments_For;

   function On_Circle
     (Center : Vector2; Radius : Scalar; Angle : Float) return Vector2
   is
      use Ada.Numerics.Elementary_Functions;
   begin
      return
        (Center.X + Radius * Scalar (Cos (Angle)),
         Center.Y + Radius * Scalar (Sin (Angle)));
   end On_Circle;

   --  Fan of N triangles around Center, first corner at Phase radians.
   procedure Fill_Fan
     (Ctx   : in out Context; Center : Vector2; Radius : Scalar;
      N     : Positive; Phase : Float; C : Color)
   is
      Step : constant Float := (2.0 * Ada.Numerics.Pi) / Float (N);
      Prev : Vector2        := On_Circle (Center, Radius, Phase);
   begin
      for I in 1 .. N loop
         declare
            Next : constant Vector2 :=
              (if I = N then On_Circle (Center, Radius, Phase)
               else On_Circle (Center, Radius, Phase + Float (I) * Step));
         begin
            Submit_Triangle (Ctx, Center, Prev, Next, C);
            Prev := Next;
         end;
      end loop;
   end Fill_Fan;

   procedure Draw_Circle
     (Ctx    : in out Context; Center_X, Center_Y : Integer;
      Radius :        Scalar; C : Color)
   is
   begin
      Draw_Circle_V (Ctx, (Scalar (Center_X), Scalar (Center_Y)), Radius, C);
   end Draw_Circle;

   procedure Draw_Circle_V
     (Ctx : in out Context; Center : Vector2; Radius : Scalar; C : Color)
   is
   begin
      if Radius <= 0.0 then
         return;
      end if;
      Fill_Fan (Ctx, Center, Radius, Segments_For (Radius), 0.0, C);
   end Draw_Circle_V;

   procedure Draw_Circle_Lines
     (Ctx    : in out Context; Center_X, Center_Y : Integer;
      Radius :        Scalar; C : Color)
   is
      Center : constant Vector2  := (Scalar (Center_X), Scalar (Center_Y));
      N      : constant Positive := Segments_For (Radius);
      Step   : constant Float    := 2.0 * Ada.Numerics.Pi / Float (N);
      Prev   : Vector2           := On_Circle (Center, Radius, 0.0);
   begin
      if Radius <= 0.0 then
         return;
      end if;
      for I in 1 .. N loop
         declare
            Next : constant Vector2 :=
              (if I = N then On_Circle (Center, Radius, 0.0)
               else On_Circle (Center, Radius, Float (I) * Step));
         begin
            Draw_Line_Ex (Ctx, Prev, Next, 1.0, C);
            Prev := Next;
         end;
      end loop;
   end Draw_Circle_Lines;

   procedure Draw_Triangle
     (Ctx : in out Context; V1, V2, V3 : Vector2; C : Color)
   is
   begin
      Submit_Triangle (Ctx, V1, V2, V3, C);
   end Draw_Triangle;

   procedure Draw_Poly
     (Ctx    : in out Context; Center : Vector2; Sides : Natural;
      Radius :        Scalar; Rotation : Degrees; C : Color)
   is
   begin
      if Sides < 3 or else Radius <= 0.0 then
         return;
      end if;
      Fill_Fan
        (Ctx, Center, Radius, Sides,
         Float (Rotation) * (Ada.Numerics.Pi / 180.0), C);
   end Draw_Poly;

   procedure Draw_Ring
     (Ctx                        : in out Context; Center : Vector2;
      Inner_Radius, Outer_Radius :        Scalar;
      Start_Angle, End_Angle     :        Degrees; Segments : Natural;
      C                          :        Color)
   is
      Inner : Scalar  := Scalar'Max (0.0, Inner_Radius);
      Outer : Scalar  := Outer_Radius;
      Sweep : Degrees := End_Angle - Start_Angle;
      Full  : Boolean;
      N     : Positive;
   begin
      if Inner > Outer then
         declare
            T : constant Scalar := Inner;
         begin
            Inner := Outer;
            Outer := T;
         end;
      end if;
      if Outer <= 0.0 or else Inner = Outer or else Sweep = 0.0 then
         return;
      end if;
      Sweep := Degrees'Max (-360.0, Degrees'Min (360.0, Sweep));
      Full  := abs Sweep = 360.0;

      if Segments > 0 then
         N := Segments;
      else
         N :=
           Positive'Max (1, Positive (Float'Ceiling (Float (Segments_For (Outer)) * Float (abs Sweep) / 360.0)));
      end if;

      declare
         Start : constant Float :=
           Float (Start_Angle) * (Ada.Numerics.Pi / 180.0);
         Step  : constant Float :=
           Float (Sweep) * (Ada.Numerics.Pi / 180.0) / Float (N);
         function Angle (I : Natural) return Float is
           (if Full and then I = N then Start else Start + Float (I) * Step);
         --  A full turn closes on exactly the first corners, no seam.
         Prev_In  : Vector2 := On_Circle (Center, Inner, Angle (0));
         Prev_Out : Vector2 := On_Circle (Center, Outer, Angle (0));
      begin
         for I in 1 .. N loop
            declare
               Next_In  : constant Vector2 :=
                 On_Circle (Center, Inner, Angle (I));
               Next_Out : constant Vector2 :=
                 On_Circle (Center, Outer, Angle (I));
               P        : constant Batch.Quad_Corners :=
                 [Prev_Out, Next_Out, Next_In, Prev_In];
            begin
               --  Inner = 0 collapses Next_In and Prev_In onto the
               --  centre: a triangle, still a whole quad.
               Submit (Ctx, White_Texture, P, Unit_UV, C);
               Prev_In  := Next_In;
               Prev_Out := Next_Out;
            end;
         end loop;
      end;
   end Draw_Ring;

   ----------
   -- Flat --
   ----------

   procedure Draw_Rectangle (X, Y, Width, Height : Integer; C : Color) is
   begin
      Draw_Rectangle (Default.all, X, Y, Width, Height, C);
   end Draw_Rectangle;
   procedure Draw_Rectangle_Rec (R : Rectangle; C : Color) is
   begin
      Draw_Rectangle_Rec (Default.all, R, C);
   end Draw_Rectangle_Rec;
   procedure Draw_Rectangle_Pro
     (R : Rectangle; Origin : Vector2; Rotation : Degrees; C : Color)
   is
   begin
      Draw_Rectangle_Pro (Default.all, R, Origin, Rotation, C);
   end Draw_Rectangle_Pro;
   procedure Draw_Rectangle_Lines (X, Y, Width, Height : Integer; C : Color) is
   begin
      Draw_Rectangle_Lines (Default.all, X, Y, Width, Height, C);
   end Draw_Rectangle_Lines;
   procedure Draw_Line (X1, Y1, X2, Y2 : Integer; C : Color) is
   begin
      Draw_Line (Default.all, X1, Y1, X2, Y2, C);
   end Draw_Line;
   procedure Draw_Line_Ex (Start, Stop : Vector2; Thick : Scalar; C : Color) is
   begin
      Draw_Line_Ex (Default.all, Start, Stop, Thick, C);
   end Draw_Line_Ex;
   procedure Draw_Circle
     (Center_X, Center_Y : Integer; Radius : Scalar; C : Color)
   is
   begin
      Draw_Circle (Default.all, Center_X, Center_Y, Radius, C);
   end Draw_Circle;
   procedure Draw_Circle_V (Center : Vector2; Radius : Scalar; C : Color) is
   begin
      Draw_Circle_V (Default.all, Center, Radius, C);
   end Draw_Circle_V;
   procedure Draw_Circle_Lines
     (Center_X, Center_Y : Integer; Radius : Scalar; C : Color)
   is
   begin
      Draw_Circle_Lines (Default.all, Center_X, Center_Y, Radius, C);
   end Draw_Circle_Lines;
   procedure Draw_Triangle (V1, V2, V3 : Vector2; C : Color) is
   begin
      Draw_Triangle (Default.all, V1, V2, V3, C);
   end Draw_Triangle;
   procedure Draw_Poly
     (Center   : Vector2; Sides : Natural; Radius : Scalar;
      Rotation : Degrees; C : Color)
   is
   begin
      Draw_Poly (Default.all, Center, Sides, Radius, Rotation, C);
   end Draw_Poly;
   procedure Draw_Ring
     (Center                 : Vector2; Inner_Radius, Outer_Radius : Scalar;
      Start_Angle, End_Angle : Degrees; Segments : Natural; C : Color)
   is
   begin
      Draw_Ring
        (Default.all, Center, Inner_Radius, Outer_Radius, Start_Angle,
         End_Angle, Segments, C);
   end Draw_Ring;

end Yarlib.Shapes;
