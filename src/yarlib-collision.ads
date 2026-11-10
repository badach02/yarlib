with Bedrock; use Bedrock;

package Yarlib.Collision with
   SPARK_Mode
is
   -- As described in fall.md, our edge touch rule will be touching edges are not colliding. 
   -- This was suggsted by my agent, since bedrock's overlap function does not consider touching edges as overlapping,
   -- and I think it is a good idea to be consistent with that.
   -- A rectangle with zero width or height does not collide.
   function Check_Collision_Recs (A, B : Rectangle) return Boolean;
   function Get_Collision_Rec (A, B : Rectangle) return Rectangle;
   function Check_Collision_Point_Rec
      (P : Vector2; R : Rectangle) return Boolean;

   function Check_Collision_Circle_Rec
      (Center : Vector2; Radius : Scalar; R : Rectangle) return Boolean;
   function Check_Collision_Circles
      (Center_A : Vector2; Radius_A : Scalar;
      Center_B : Vector2; Radius_B : Scalar) return Boolean;
end Yarlib.Collision;