package body Yarlib.Collision with SPARK_Mode is

   procedure Prove_Rectangle_Symmetry (A, B : Rectangle) is
   begin
      null;
   end Prove_Rectangle_Symmetry;

   procedure Prove_Rectangle_Self_Collision (R : Rectangle) is
   begin
      null;
   end Prove_Rectangle_Self_Collision;

   function Get_Collision_Rec (A, B : Rectangle) return Rectangle is
   begin
      if not Check_Collision_Recs (A, B) then
         return (0.0, 0.0, 0.0, 0.0);
      end if;

      declare
         Left   : constant Scalar := Scalar'Max (A.X, B.X);
         Top    : constant Scalar := Scalar'Max (A.Y, B.Y);
         Width  : constant Scalar :=
           Scalar'Min (A.X + A.Width - Left, B.X + B.Width - Left);
         Height : constant Scalar :=
           Scalar'Min (A.Y + A.Height - Top, B.Y + B.Height - Top);
      begin
         return (Left, Top, Width, Height);
      end;
   end Get_Collision_Rec;

   function Check_Collision_Circle_Rec
     (Center : Vector2; Radius : Scalar; R : Rectangle) return Boolean
   is
      Closest_X : constant Scalar := Scalar'Max (R.X, Scalar'Min (Center.X, R.X + R.Width));
      Closest_Y : constant Scalar := Scalar'Max (R.Y, Scalar'Min (Center.Y, R.Y + R.Height));
      DX : constant Scalar := Center.X - Closest_X;
      DY : constant Scalar := Center.Y - Closest_Y;
   begin
      return Radius > 0.0 and then R.Width > 0.0 and then R.Height > 0.0
        and then DX * DX + DY * DY <= Radius * Radius;
   end Check_Collision_Circle_Rec;

   function Check_Collision_Circles
     (Center_A : Vector2; Radius_A : Scalar;
      Center_B : Vector2; Radius_B : Scalar) return Boolean
   is
      DX : constant Scalar := Center_A.X - Center_B.X;
      DY : constant Scalar := Center_A.Y - Center_B.Y;
      Sum : constant Scalar := Radius_A + Radius_B;
   begin
      return Radius_A > 0.0 and then Radius_B > 0.0
        and then DX * DX + DY * DY <= Sum * Sum;
   end Check_Collision_Circles;
end Yarlib.Collision;
