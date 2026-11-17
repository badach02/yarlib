with Bedrock; use Bedrock;

package Yarlib.Collision with
  SPARK_Mode
is
   --  Bounds keep intermediate floating-point calculations representable.
   Geometry_Limit : constant Scalar := 1.0E9;

   function Valid_Point (P : Vector2) return Boolean is
     (P.X in -Geometry_Limit .. Geometry_Limit
      and then P.Y in -Geometry_Limit .. Geometry_Limit);

   function Valid_Rectangle (R : Rectangle) return Boolean is
     (R.X in -Geometry_Limit .. Geometry_Limit
      and then R.Y in -Geometry_Limit .. Geometry_Limit
      and then R.Width in 0.0 .. Geometry_Limit
      and then R.Height in 0.0 .. Geometry_Limit);

   function Valid_Radius (R : Scalar) return Boolean is
     (R in 0.0 .. Geometry_Limit);

   --  Touching edges do not collide. Zero width or height disables collision.
   function Check_Collision_Recs (A, B : Rectangle) return Boolean is
     (A.Width > 0.0 and then A.Height > 0.0
      and then B.Width > 0.0 and then B.Height > 0.0
      and then Overlaps (A, B))
   with Pre => Valid_Rectangle (A) and then Valid_Rectangle (B);

   --  Positive dimensions can round away at large coordinates, so the
   --  self-collision property requires representable, distinct edges.
   procedure Prove_Rectangle_Symmetry (A, B : Rectangle)
   with Ghost,
     Pre => Valid_Rectangle (A) and then Valid_Rectangle (B),
     Post => Check_Collision_Recs (A, B) = Check_Collision_Recs (A => B, B => A);

   procedure Prove_Rectangle_Self_Collision (R : Rectangle)
   with Ghost,
     Pre => Valid_Rectangle (R)
       and then R.Width > 0.0 and then R.Height > 0.0
       and then R.X + R.Width > R.X and then R.Y + R.Height > R.Y,
     Post => Check_Collision_Recs (R, R);

   --  No collision returns (0, 0, 0, 0); otherwise return the intersection.
   function Get_Collision_Rec (A, B : Rectangle) return Rectangle
   with
     Pre => Valid_Rectangle (A) and then Valid_Rectangle (B),
     Post =>
       (if Check_Collision_Recs (A, B) then
           Get_Collision_Rec'Result.X >= A.X
           and then Get_Collision_Rec'Result.X >= B.X
           and then Get_Collision_Rec'Result.Y >= A.Y
           and then Get_Collision_Rec'Result.Y >= B.Y
           and then Get_Collision_Rec'Result.Width >= 0.0
           and then Get_Collision_Rec'Result.Height >= 0.0
           and then Get_Collision_Rec'Result.Width <= A.X + A.Width - Get_Collision_Rec'Result.X
           and then Get_Collision_Rec'Result.Width <= B.X + B.Width - Get_Collision_Rec'Result.X
           and then Get_Collision_Rec'Result.Height <= A.Y + A.Height - Get_Collision_Rec'Result.Y
           and then Get_Collision_Rec'Result.Height <= B.Y + B.Height - Get_Collision_Rec'Result.Y
        else Get_Collision_Rec'Result = (0.0, 0.0, 0.0, 0.0));

   --  Left/top are included, right/bottom excluded, as in Bedrock.Contains.
   function Check_Collision_Point_Rec (P : Vector2; R : Rectangle) return Boolean is
     (R.Width > 0.0 and then R.Height > 0.0 and then Contains (R, P))
   with Pre => Valid_Point (P) and then Valid_Rectangle (R);

   --  Zero radius disables collision. Circle tangency counts as collision.
   function Check_Collision_Circle_Rec
     (Center : Vector2; Radius : Scalar; R : Rectangle) return Boolean
   with Pre => Valid_Point (Center) and then Valid_Radius (Radius)
     and then Valid_Rectangle (R);

   function Check_Collision_Circles
     (Center_A : Vector2; Radius_A : Scalar;
      Center_B : Vector2; Radius_B : Scalar) return Boolean
   with Pre => Valid_Point (Center_A) and then Valid_Radius (Radius_A)
     and then Valid_Point (Center_B) and then Valid_Radius (Radius_B);
end Yarlib.Collision;
