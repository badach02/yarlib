--  Shapes: solid-colour primitives. raylib's rshapes. Every one is a
--  quad (or a few) on the white texture, pushed through Core.Submit.
--  Each has a Context form and a flat form over Core.Default.

with Bedrock;     use Bedrock;
with Yarlib.Core; use Yarlib.Core;

package Yarlib.Shapes is

   procedure Draw_Rectangle
     (Ctx : in out Context; X, Y, Width, Height : Integer; C : Color);
   procedure Draw_Rectangle_Rec
     (Ctx : in out Context; R : Rectangle; C : Color);
   procedure Draw_Rectangle_Pro
     (Ctx      : in out Context; R : Rectangle; Origin : Vector2;
      Rotation :        Degrees; C : Color);
   --  Rotation clockwise about R's position + Origin.
   procedure Draw_Rectangle_Lines
     (Ctx : in out Context; X, Y, Width, Height : Integer; C : Color);
   procedure Draw_Line
     (Ctx : in out Context; X1, Y1, X2, Y2 : Integer; C : Color);
   procedure Draw_Line_Ex
     (Ctx : in out Context; Start, Stop : Vector2; Thick : Scalar; C : Color);

   --  Circles, triangles, polygons, rings.
   --
   --  The batch only takes whole quads, so a triangle is a quad whose
   --  fourth corner repeats the third: the quad's second triangle has
   --  zero area and the rasterizer skips it. A filled circle or polygon
   --  is a fan of such triangles around its centre; a ring is a strip
   --  of real quads between its inner and outer arcs. Outlines are
   --  Draw_Line_Ex segments, one pixel thick, like Draw_Line.
   --
   --  Segments: circles and auto-segmented rings use
   --    N = Clamp (Round (2 * Pi * Radius / 4), 12, 36)
   --  i.e. about one segment per 4 pixels of circumference, never
   --  fewer than 12 (small circles stay round enough, and cheap) and
   --  never more than 36 (big circles stay within a few hundred
   --  vertices). A ring spanning less than 360 degrees gets the same
   --  segments-per-degree, at least 1.
   --
   --  Angles are Degrees, measured clockwise from +X (y is down), like
   --  every rotation in Bedrock.
   --
   --  Invalid or degenerate dimensions draw nothing and never raise:
   --    - Radius <= 0 (circles, polygons).
   --    - Sides < 3 (polygons).
   --    - Rings: a negative Inner_Radius counts as 0; if Inner_Radius
   --      > Outer_Radius they are swapped; equal radii, Outer_Radius
   --      <= 0, or Start_Angle = End_Angle draw nothing. End_Angle <
   --      Start_Angle sweeps the other way; a sweep beyond 360 degrees
   --      is clamped to one full turn. Segments = 0 picks N by the rule
   --      above.
   --    - Triangles with collinear corners submit a zero-area quad,
   --      which the rasterizer skips.

   procedure Draw_Circle
     (Ctx    : in out Context; Center_X, Center_Y : Integer;
      Radius :        Scalar; C : Color);
   procedure Draw_Circle_V
     (Ctx : in out Context; Center : Vector2; Radius : Scalar; C : Color);
   procedure Draw_Circle_Lines
     (Ctx    : in out Context; Center_X, Center_Y : Integer;
      Radius :        Scalar; C : Color);
   procedure Draw_Triangle
     (Ctx : in out Context; V1, V2, V3 : Vector2; C : Color);
   procedure Draw_Poly
     (Ctx    : in out Context; Center : Vector2; Sides : Natural;
      Radius :        Scalar; Rotation : Degrees; C : Color);
   procedure Draw_Ring
     (Ctx                        : in out Context; Center : Vector2;
      Inner_Radius, Outer_Radius :        Scalar;
      Start_Angle, End_Angle     :        Degrees; Segments : Natural;
      C                          :        Color);

   procedure Draw_Rectangle (X, Y, Width, Height : Integer; C : Color);
   procedure Draw_Rectangle_Rec (R : Rectangle; C : Color);
   procedure Draw_Rectangle_Pro
     (R : Rectangle; Origin : Vector2; Rotation : Degrees; C : Color);
   procedure Draw_Rectangle_Lines (X, Y, Width, Height : Integer; C : Color);
   procedure Draw_Line (X1, Y1, X2, Y2 : Integer; C : Color);
   procedure Draw_Line_Ex (Start, Stop : Vector2; Thick : Scalar; C : Color);
   
   procedure Draw_Circle
     (Center_X, Center_Y : Integer; Radius : Scalar; C : Color);
   procedure Draw_Circle_V (Center : Vector2; Radius : Scalar; C : Color);
   procedure Draw_Circle_Lines
     (Center_X, Center_Y : Integer; Radius : Scalar; C : Color);
   procedure Draw_Triangle (V1, V2, V3 : Vector2; C : Color);
   procedure Draw_Poly
     (Center   : Vector2; Sides : Natural; Radius : Scalar;
      Rotation : Degrees; C : Color);
   procedure Draw_Ring
     (Center                 : Vector2; Inner_Radius, Outer_Radius : Scalar;
      Start_Angle, End_Angle : Degrees; Segments : Natural; C : Color);

end Yarlib.Shapes;
