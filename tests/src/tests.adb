--  Unit tests. Plain Ada, no framework, non-zero exit on failure.
--  Built on the null platform and the null GPU: no window, pixels are
--  read back from the software framebuffer.
--
--  Milestone gating: a check tagged with a milestone number above
--  Milestone prints TODO instead of FAIL and does not count. Raise
--  Milestone when you land one; CI then holds you to it.

with Bedrock;         use Bedrock;
with Bedrock.Buffers;
with Bedrock.Colors;  use Bedrock.Colors;
with Ada.Command_Line;
with Ada.Numerics.Discrete_Random;
with Ada.Text_IO;      use Ada.Text_IO;
with Bedrock.Input;    use Bedrock.Input;
with Yarlib;           use Yarlib;
with Yarlib.Batch;     use Yarlib.Batch;
with Yarlib.Collision; use Yarlib.Collision;
with Yarlib.Collision.Grid;
with Yarlib.Console;
with Yarlib.Core;      use Yarlib.Core;
with Yarlib.Font;
with Yarlib.Game_Loop;
with Yarlib.Renderer;
with Yarlib.Input;
with Yarlib.Raster;
with Yarlib.Replay;
with Test_Support;
with Yarlib.Shapes;    use Yarlib.Shapes;
with Yarlib.Textures;  use Yarlib.Textures;
with Yarlib.Text;

procedure Tests is

   Milestone : constant Natural := 1;
   --  0: seed as shipped. 1: batcher written.

   Failures : Natural := 0;
   Todos    : Natural := 0;

   procedure Check (Name : String; Cond : Boolean; Needs : Natural := 0);
   procedure Test_Raster;
   procedure Test_Batch;
   procedure Test_Collision;
   procedure Test_Collision_Grid;
   procedure Test_Input;
   procedure Test_Core;
   procedure Test_Camera;
   procedure Test_Loop_And_Replay;
   procedure Test_Console;
   procedure Test_Atlas;
   procedure Test_Text;
   procedure Test_Shapes;

   procedure Check (Name : String; Cond : Boolean; Needs : Natural := 0) is
   begin
      if Cond then
         Put_Line ("PASS  " & Name);
      elsif Needs > Milestone then
         Put_Line ("TODO  " & Name & "  (milestone" & Needs'Image & ")");
         Todos := Todos + 1;
      else
         Put_Line ("FAIL  " & Name);
         Failures := Failures + 1;
      end if;
   end Check;

   function Same (A, B : Color) return Boolean renames Bedrock.Colors.Same_RGB;

   ---------------------------------------------------------------------

   procedure Test_Collision is
      A : constant Rectangle := (0.0, 0.0, 10.0, 10.0);
      B : constant Rectangle := (5.0, 4.0, 10.0, 8.0);
      Touch : constant Rectangle := (10.0, 2.0, 5.0, 5.0);
      Empty : constant Rectangle := (5.0, 2.0, 0.0, 5.0);
      Corner : constant Rectangle := (10.0, 10.0, 2.0, 2.0);
   begin
      Check ("rectangles overlap", Check_Collision_Recs (A, B));
      Check ("rectangle symmetry overlap",
             Check_Collision_Recs (A, B) = Check_Collision_Recs (A => B, B => A));
      Check ("rectangle self collision", Check_Collision_Recs (A, A));
      Check ("edge touching is not collision", not Check_Collision_Recs (A, Touch));
      Check ("edge touching symmetry", not Check_Collision_Recs (Touch, A));
      Check ("corner touching is not collision", not Check_Collision_Recs (A, Corner));
      Check ("zero width disables collision", not Check_Collision_Recs (A, Empty));
      Check ("zero height disables collision",
             not Check_Collision_Recs (A, (2.0, 5.0, 5.0, 0.0)));
      Check ("overlap rectangle", Get_Collision_Rec (A, B) = (5.0, 4.0, 5.0, 6.0));
      Check ("no overlap rectangle", Get_Collision_Rec (A, Touch) = (0.0, 0.0, 0.0, 0.0));
      Check ("point on left top included", Check_Collision_Point_Rec ((0.0, 0.0), A));
      Check ("point on right excluded", not Check_Collision_Point_Rec ((10.0, 5.0), A));
      Check ("point in empty rectangle", not Check_Collision_Point_Rec ((5.0, 3.0), Empty));
      Check ("circle tangency", Check_Collision_Circles ((0.0, 0.0), 2.0, (4.0, 0.0), 2.0));
      Check ("circles separated", not Check_Collision_Circles ((0.0, 0.0), 2.0, (5.0, 0.0), 2.0));
      Check ("zero radius disables collision",
             not Check_Collision_Circles ((0.0, 0.0), 0.0, (0.0, 0.0), 2.0));
      Check ("circle rectangle tangency", Check_Collision_Circle_Rec ((12.0, 5.0), 2.0, A));
      Check ("circle rectangle corner miss",
             not Check_Collision_Circle_Rec ((12.0, 12.0), 2.0, A));
      Check ("circle empty rectangle", not Check_Collision_Circle_Rec ((5.0, 3.0), 2.0, Empty));
   end Test_Collision;

   procedure Test_Collision_Grid is
      package Small is new Yarlib.Collision.Grid
        (Origin_X => -16.0, Origin_Y => -16.0, Columns => 4, Rows => 4,
         Cell_Size => 8, Max_Per_Cell => 2, Max_Id => 4);
      Fixture : Small.Grid;
      Found   : Small.Id_List (3 .. 6);
      Short   : Small.Id_List (1 .. 1);
      Empty   : Small.Id_List (1 .. 0);
      Count   : Natural;
      Ok      : Boolean;
      West    : constant Rectangle := (-16.0, -16.0, 4.0, 4.0);
      East    : constant Rectangle := (-8.0, -16.0, 4.0, 4.0);
      Span    : constant Rectangle := (-12.0, -16.0, 8.0, 4.0);

      N : constant := 1_000;
      package Random_Grid is new Yarlib.Collision.Grid
        (Origin_X => -256.0, Origin_Y => -256.0, Columns => 32, Rows => 32,
         Cell_Size => 16, Max_Per_Cell => 64, Max_Id => N);
      G          : Random_Grid.Grid;
      Rects      : array (1 .. N) of Rectangle;
      Candidates : Random_Grid.Id_List (1 .. N);
      subtype Random_Value is Integer range 0 .. 479;
      package Random is new Ada.Numerics.Discrete_Random (Random_Value);
      Gen : Random.Generator;
      All_Inserted  : Boolean := True;
      All_Unique    : Boolean := True;
      All_Covered   : Boolean := True;
      Overlap_Count : Natural := 0;
   begin
      Small.Clear (Fixture);
      Small.Insert (Fixture, 1, Span, Ok);
      Check ("grid inserts rectangles crossing a negative cell boundary", Ok);
      Small.Query (Fixture, West, Found, Count, Ok);
      Check ("grid finds the ID west of the cell boundary",
             Ok and then Count = 1 and then Found (3) = 1);
      Small.Query (Fixture, East, Found, Count, Ok);
      Check ("grid finds the ID on the cell boundary",
             Ok and then Count = 1 and then Found (3) = 1);
      Small.Query (Fixture, Span, Found, Count, Ok);
      Check ("grid deduplicates multi-cell IDs", Ok and then Count = 1);
      Small.Insert (Fixture, 2, East, Ok);
      Check ("grid accepts the last entry in a cell", Ok);
      Small.Insert (Fixture, 3, Span, Ok);
      Check ("grid reports a full cell", not Ok);
      Small.Query (Fixture, West, Found, Count, Ok);
      Check ("grid rejects a full insert without writing earlier cells",
             Ok and then Count = 1 and then Found (3) = 1);
      Small.Query (Fixture, Span, Short, Count, Ok);
      Check ("grid reports a full result buffer",
             not Ok and then Count = 1 and then Short (1) = 1);
      Small.Query (Fixture, Span, Empty, Count, Ok);
      Check ("grid reports a zero-length result buffer", not Ok and then Count = 0);
      Small.Insert (Fixture, 3, (-17.0, -16.0, 2.0, 2.0), Ok);
      Check ("grid rejects a rectangle partly outside the origin", not Ok);
      Small.Insert (Fixture, 3, (14.0, 14.0, 2.0, 2.0), Ok);
      Check ("grid accepts a rectangle ending at the far edge", Ok);
      Small.Query (Fixture, (15.0, 15.0, 1.0, 1.0), Found, Count, Ok);
      Check ("grid finds the ID on the far edge",
             Ok and then Count = 1 and then Found (3) = 3);
      Small.Query (Fixture, (15.0, 15.0, 2.0, 1.0), Found, Count, Ok);
      Check ("grid rejects a query beyond the far edge", not Ok and then Count = 0);
      Small.Insert (Fixture, 5, West, Ok);
      Check ("grid rejects an ID above capacity", not Ok);
      Small.Clear (Fixture);
      Small.Insert (Fixture, 1, (-12.0, -12.0, 0.0, 4.0), Ok);
      Check ("grid accepts a zero-width rectangle as empty", Ok);
      Small.Query (Fixture, Span, Found, Count, Ok);
      Check ("grid clear and empty inserts leave no candidates", Ok and then Count = 0);

      Random.Reset (Gen, Initiator => 12);
      Random_Grid.Clear (G);
      for I in Rects'Range loop
         Rects (I).X := Scalar (Random.Random (Gen) - 256);
         Rects (I).Y := Scalar (Random.Random (Gen) - 256);
         Rects (I).Width := Scalar (1 + Random.Random (Gen) mod 32);
         Rects (I).Height := Scalar (1 + Random.Random (Gen) mod 32);
         Random_Grid.Insert (G, I, Rects (I), Ok);
         All_Inserted := All_Inserted and Ok;
      end loop;
      for I in Rects'Range loop
         declare
            Seen : array (Rects'Range) of Boolean := [others => False];
         begin
            Random_Grid.Query (G, Rects (I), Candidates, Count, Ok);
            All_Covered := All_Covered and Ok;
            for J in 1 .. Count loop
               if Candidates (J) in Seen'Range and then not Seen (Candidates (J)) then
                  Seen (Candidates (J)) := True;
               else
                  All_Unique := False;
               end if;
            end loop;
            for J in Rects'Range loop
               if I /= J and then Check_Collision_Recs (Rects (I), Rects (J)) then
                  Overlap_Count := Overlap_Count + 1;
                  All_Covered := All_Covered and Seen (J);
               end if;
            end loop;
         end;
      end loop;
      Check ("grid inserts all 1000 seeded rectangles", All_Inserted);
      Check ("grid seeded candidates are unique and valid", All_Unique);
      Check ("grid misses no seeded brute-force overlaps", All_Covered and Overlap_Count > 0);
   end Test_Collision_Grid;

   ---------------------------------------------------------------------

   procedure Test_Raster is
      use Yarlib.Raster;
      use Bedrock.Buffers;
      F : Framebuffer := Make (16, 16);
      V : constant Raster.Vertex := (0.0, 0.0, 0.0, 0.0, Red);
   begin
      Fill (F, Black);
      Check ("clear", Same (Get (F, 3, 3), Black));
      Fill_Triangle (F, (0.0, 0.0, 0.0, 0.0, Red), (16.0, 0.0, 0.0, 0.0, Red),
                     (0.0, 16.0, 0.0, 0.0, Red), null);
      Check ("upper-left triangle filled", Same (Get (F, 2, 2), Red));
      Check ("lower-right untouched", Same (Get (F, 14, 14), Black));
      Fill_Triangle (F, (16.0, 0.0, 0.0, 0.0, Red), (16.0, 16.0, 0.0, 0.0, Red),
                     (0.0, 16.0, 0.0, 0.0, Red), null);
      Check ("winding does not matter", Same (Get (F, 14, 14), Red));
      declare
         Img : Bedrock.Buffers.Image := Make (2, 2, White);
      begin
         Set (Img, 0, 0, Red);
         Set (Img, 1, 0, Green);
         Set (Img, 0, 1, Blue);
         Check ("sample 0,0", Same (Sample (Img, 0.1, 0.1), Red));
         Check ("sample 1,0", Same (Sample (Img, 0.9, 0.1), Green));
         Check ("sample 1,1", Same (Sample (Img, 1.0, 1.0), White));
      end;
      Check ("degenerate triangle is a no-op", V.C = Red);
   end Test_Raster;

   ---------------------------------------------------------------------

   procedure Test_Batch is
      B  : Yarlib.Batch.Batch;
      Ok : Boolean;
      P  : constant Quad_Corners := [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)];
   begin
      Reset (B);
      Check ("empty batch well formed", Well_Formed (B));
      Push_Quad (B, White_Texture, P, P, Red, Ok);
      Check ("push one quad", Ok and B.Vertex_Count = 6 and B.Call_Count = 1, Needs => 1);
      Push_Quad (B, White_Texture, P, P, Red, Ok);
      Check ("same texture, same call", Ok and B.Call_Count = 1 and B.Vertex_Count = 12,
             Needs => 1);
      Push_Quad (B, 1, P, P, Red, Ok);
      Check ("texture change starts a call",
             Ok and B.Call_Count = 2 and B.Calls (2).First = 13, Needs => 1);
      Check ("well formed after pushes", Well_Formed (B));
      Reset (B);
      for I in 1 .. Max_Quads loop
         Push_Quad (B, White_Texture, P, P, Red, Ok);
      end loop;
      Check ("fills to Max_Quads", Ok and B.Vertex_Count = Max_Vertices, Needs => 1);
      Push_Quad (B, White_Texture, P, P, Red, Ok);
      Check ("refuses when full", not Ok and B.Vertex_Count = Max_Vertices, Needs => 1);
      Check ("still well formed", Well_Formed (B));
   end Test_Batch;

   ---------------------------------------------------------------------

   procedure Test_Input is
      use Yarlib.Input;
      S : State;
   begin
      Apply (S, Key_Event (Key_A, Down => True));
      Check ("key down: down and pressed", S.Down (Key_A) and S.Pressed (Key_A));
      Begin_Frame (S);
      Check ("next frame: down, not pressed", S.Down (Key_A) and not S.Pressed (Key_A));
      Apply (S, Key_Event (Key_A, Down => True));
      Check ("repeat is not a press", not S.Pressed (Key_A));
      Apply (S, Key_Event (Key_A, Down => False));
      Check ("key up: released", not S.Down (Key_A) and S.Released (Key_A));
      Apply (S, Move_Event (10, 20));
      Check ("mouse move", S.Mouse_X = 10 and S.Mouse_Y = 20);
      Apply (S, Quit_Event);
      Check ("quit", S.Quit_Requested);
   end Test_Input;

   ---------------------------------------------------------------------

   procedure Test_Core is
      T : Texture;
   begin
      Init_Window (64, 32, "tests");
      Check ("window open", Window_Is_Open and Screen_Width = 64 and Screen_Height = 32);
      Begin_Drawing;
      Clear_Background (Blue);
      End_Drawing;
      Check ("clear background reaches the GPU", Same (Renderer.Read_Pixel (5, 5), Blue));

      Begin_Drawing;
      Clear_Background (Black);
      Draw_Rectangle (10, 10, 20, 10, Red);
      End_Drawing;
      Check ("rectangle inside", Same (Renderer.Read_Pixel (15, 15), Red), Needs => 1);
      Check ("rectangle outside", Same (Renderer.Read_Pixel (5, 5), Black));
      Check ("rectangle edge exclusive", Same (Renderer.Read_Pixel (30, 15), Black));

      T := Checkerboard (4, 4, 2, Green, Yellow);
      Check ("texture created", T.Id /= White_Texture and T.Width = 4);
      Begin_Drawing;
      Clear_Background (Black);
      Draw_Texture (T, 0, 0);
      End_Drawing;
      Check ("texture texel 0,0", Same (Renderer.Read_Pixel (0, 0), Green), Needs => 1);
      Check ("texture texel 2,0", Same (Renderer.Read_Pixel (2, 0), Yellow), Needs => 1);

      Begin_Drawing;
      Clear_Background (Black);
      Draw_Rectangle_Pro ((32.0, 16.0, 20.0, 4.0), (10.0, 2.0), 90.0, Red);
      End_Drawing;
      Check ("rotated 90: vertical bar", Same (Renderer.Read_Pixel (32, 24), Red), Needs => 1);
      Check ("rotated 90: not horizontal", Same (Renderer.Read_Pixel (40, 16), Black));

      Inject (Key_Event (Key_D, Down => True));
      Begin_Drawing;
      End_Drawing;
      Check ("injected key pressed", Is_Key_Pressed (Key_D) and Is_Key_Down (Key_D));
      Begin_Drawing;
      End_Drawing;
      Check ("held next frame", Is_Key_Down (Key_D) and not Is_Key_Pressed (Key_D));
      Check ("frame time non-negative", Get_Frame_Time >= 0.0);
      Check ("no close yet", not Window_Should_Close);
      Inject (Key_Event (Key_Escape, Down => True));
      Begin_Drawing;
      End_Drawing;
      Check ("escape closes", Window_Should_Close);
      Close_Window;
      Check ("window closed", not Window_Is_Open);
   end Test_Core;

   ---------------------------------------------------------------------

   procedure Test_Camera is
      Cam : constant Camera2D := (Offset => (400.0, 225.0), Target => (100.0, 50.0),
                                  Rotation => 0.0, Zoom => 2.0);
      P   : constant Vector2 := World_To_Screen (Cam, (110.0, 60.0));
      Q   : constant Vector2 := Screen_To_World (Cam, P);
   begin
      Check ("world to screen", P.X = 420.0 and P.Y = 245.0);
      Check ("screen to world round trip", abs (Q.X - 110.0) < 0.001 and abs (Q.Y - 60.0) < 0.001);
      Init_Window (64, 32, "cam");
      Begin_Drawing;
      Clear_Background (Black);
      Begin_Mode_2D ((Offset => (32.0, 0.0), Target => (0.0, 0.0), Rotation => 0.0, Zoom => 1.0));
      Draw_Rectangle (0, 0, 8, 8, Red);   --  world 0,0 lands at screen 32,0
      End_Mode_2D;
      End_Drawing;
      Check ("camera offsets the quad", Same (Get_Screen_Pixel (35, 3), Red), Needs => 1);
      Check ("camera: origin untouched", Same (Get_Screen_Pixel (3, 3), Black));
      Close_Window;
   end Test_Camera;

   ---------------------------------------------------------------------

   Counter : Natural := 0;
   Presses : Natural := 0;

   --  for the interp test cases
   Draw_Count : Natural := 0;
   Alpha_Ok : Boolean := True;

   procedure Update (Dt : Scalar);
   procedure Draw (Alpha : Scalar);
   procedure Update (Dt : Scalar) is
      pragma Unreferenced (Dt);
   begin
      Counter := Counter + 1;
      if Is_Key_Pressed (Key_Space) then
         Presses := Presses + 1;
      end if;
   end Update;
   procedure Draw (Alpha : Scalar) is
      --  pragma Unreferenced (Alpha);
   begin
      Draw_Count := Draw_Count + 1;
      Alpha_Ok := Alpha_Ok and then Alpha = 0.0;
      Clear_Background (Black);
   end Draw;
   package Test_Game is new Yarlib.Game_Loop (Update, Draw);

   procedure Test_Loop_And_Replay is
      Rec : Replay.Session;
      Ok  : Boolean;
   begin
      Init_Window (32, 32, "loop");
      Replay.Start_Recording (Rec, "test.rec", Ok);
      Check ("start recording", Ok);
      --  Press space on frames 2 and 5 while running 8 frames headless.
      --  Injected events are applied at the frame's End_Drawing, so the
      --  press is seen by Update on the following frame.
      Counter := 0;
      Presses := 0;
      Draw_Count := 0;
      Alpha_Ok := True;
      Inject (Key_Event (Key_Space, Down => True));   --  frame 0
      Test_Game.Run (Default.all, Rec, Max_Frames => 3);
      Inject (Key_Event (Key_Space, Down => False));
      Inject (Key_Event (Key_Space, Down => True));
      Test_Game.Run (Default.all, Rec, Max_Frames => 5);
      Replay.Stop (Rec, Default.all);
      Check ("8 frames, 8 steps", Counter = 8);
      Check ("two presses seen", Presses = 2);

      --  interp test cases
      Check ("8 frames, 8 draws", Draw_Count = 8);
      Check ("headless alpha is zero", Alpha_Ok);

      Close_Window;

      Init_Window (32, 32, "replay");
      Counter := 0;
      Presses := 0;
      Draw_Count := 0;
      Alpha_Ok := True;
      Replay.Start_Replay (Rec, Default.all, "test.rec", Ok);
      Check ("start replay", Ok);
      Test_Game.Run (Default.all, Rec, Max_Frames => 8);
      Check ("replay reproduces steps", Counter = 8);
      Check ("replay reproduces presses", Presses = 2);

      --  interp test cases:
      Check ("replay reproduces draws", Draw_Count = 8);
      Check ("replay reproduces zero alpha", Alpha_Ok);
      Replay.Stop (Rec, Default.all);
      Close_Window;
   end Test_Loop_And_Replay;

   ---------------------------------------------------------------------

   procedure Test_Console is
      R : Console.Response;
   begin
      Console.Register ("echo", Test_Support.Echo'Access, "repeat the arguments");
      Console.Execute ("echo hello  world", R);
      Check ("dispatch with args",
             R.Ok and Console.Image (R) = "ok hello  world" and Test_Support.Echoed = 1);
      Console.Execute ("   echo", R);
      Check ("leading spaces, empty args", R.Ok and Console.Image (R) = "ok ");
      Console.Execute ("nope 1 2", R);
      Check ("unknown command", not R.Ok);
      Console.Execute ("# comment", R);
      Check ("comment ok", R.Ok);
      Console.Execute ("help", R);
      Check ("help lists echo", R.Ok and Console.Image (R)'Length > 10);
      Console.Register ("echo", Test_Support.Echo'Access);
      Check ("re-register replaces", Console.Count = 1);
   end Test_Console;

   ---------------------------------------------------------------------

   procedure Test_Atlas is
      use Bedrock.Buffers;
      Atlas : constant Bitmap := Font.Build_Atlas;
      A     : constant Rectangle := Font.Source ('A');
   begin
      Check ("atlas is 128x64", Width (Atlas) = 128 and Height (Atlas) = 64);
      Check ("source of A", A = (8.0, 16.0, 8.0, 8.0));
      Check ("B sits one glyph right of A",
             Font.Source ('B').X = A.X + Scalar (Font.Glyph_Width));
      Check ("source of ~", Font.Source ('~') = (112.0, 40.0, 8.0, 8.0));
      Check ("A top-left pixel is clear", Get (Atlas, 8, 16) = Transparent);
      Check ("A is not mirrored", Get (Atlas, 10, 16) = White);
   end Test_Atlas;

   ---------------------------------------------------------------------

   procedure Test_Text is
   begin
      Check ("measure abc at 16", Text.Measure_Text ("abc", 16) = 48);
      Check ("measure abc at 12", Text.Measure_Text ("abc", 12) = 36);
      Check ("measure empty string", Text.Measure_Text ("", 16) = 0);

      Init_Window (64, 32, "text");
      Begin_Drawing;
      Clear_Background (Black);
      Text.Draw_Text ("AB", 0, 0, 8, Red);
      End_Drawing;
      --  Row 0 of 'A' is 16#0C#: pixels 2 and 3 set, 0 clear
      Check ("A row 0: pixel 2 set", Same (Get_Screen_Pixel (2, 0), Red));
      Check ("A row 0: pixel 0 clear", Same (Get_Screen_Pixel (0, 0), Black));
      --  Row 2 of 'A' is 16#33#: pixel 5 is the right edge, 6 is clear
      Check ("A right edge set", Same (Get_Screen_Pixel (5, 2), Red));
      Check ("A right edge does not bleed", Same (Get_Screen_Pixel (6, 2), Black));
      --  Row 0 of 'B' is 16#3F#: B starts one glyph (8 px) right of A
      Check ("B drawn one glyph right", Same (Get_Screen_Pixel (8, 0), Red));
      Check ("gap between A and B", Same (Get_Screen_Pixel (7, 0), Black));

      Begin_Drawing;
      Clear_Background (Black);
      Text.Draw_Text ("A", 0, 0, 16, Red);
      End_Drawing;
      --  Size 16 doubles every pixel: row 2, pixel 5 covers (10 .. 11, 4 .. 5)
      Check ("A at 16: right edge set", Same (Get_Screen_Pixel (11, 5), Red));
      Check ("A at 16: past the edge clear", Same (Get_Screen_Pixel (12, 5), Black));
      Close_Window;
   end Test_Text;
   ---------------------------------------------------------------------

   procedure Test_Shapes is
      function Px (X, Y : Natural) return Color renames Get_Screen_Pixel;
      procedure Frame_Start;
      procedure Frame_Start is
      begin
         Begin_Drawing;
         Clear_Background (Black);
      end Frame_Start;
   begin
      Init_Window (16, 16, "shapes");

      --  Filled circle: 12-gon, inradius 6 * cos 15 = 5.80.
      Frame_Start;
      Draw_Circle (8, 8, 6.0, Red);
      End_Drawing;
      Check ("circle: centre filled", Same (Px (8, 8), Red), Needs => 1);
      Check ("circle: corner 0,0 clear", Same (Px (0, 0), Black));
      Check ("circle: inside top edge", Same (Px (8, 2), Red), Needs => 1);
      Check ("circle: outside top edge", Same (Px (8, 1), Black));

      Frame_Start;
      Draw_Circle (8, 8, 0.0, Red);
      Draw_Circle (8, 8, -3.0, Red);
      End_Drawing;
      Check ("circle: radius <= 0 draws nothing", Same (Px (8, 8), Black));

      --  Outline: rim pixels lit, centre and interior not.
      Frame_Start;
      Draw_Circle_Lines (8, 8, 6.0, Red);
      End_Drawing;
      Check ("circle lines: rim", Same (Px (13, 8), Red), Needs => 1);
      Check ("circle lines: centre clear", Same (Px (8, 8), Black));
      Check ("circle lines: interior clear", Same (Px (11, 8), Black));

      --  Triangle, both windings.
      Frame_Start;
      Draw_Triangle ((0.0, 0.0), (16.0, 0.0), (0.0, 16.0), Red);
      End_Drawing;
      Check ("triangle: inside", Same (Px (2, 2), Red), Needs => 1);
      Check ("triangle: degenerate half not drawn", Same (Px (14, 14), Black));
      Frame_Start;
      Draw_Triangle ((0.0, 0.0), (0.0, 16.0), (16.0, 0.0), Red);
      End_Drawing;
      Check ("triangle: other winding", Same (Px (2, 2), Red), Needs => 1);
      Frame_Start;
      Draw_Triangle ((0.0, 0.0), (8.0, 8.0), (16.0, 16.0), Red);
      End_Drawing;
      Check ("triangle: collinear draws nothing", Same (Px (8, 8), Black));

      --  Square rotated 0: a diamond with corners on the axes, |dx|+|dy| <= 6.
      Frame_Start;
      Draw_Poly ((8.0, 8.0), 4, 6.0, 0.0, Red);
      End_Drawing;
      Check ("poly: centre", Same (Px (8, 8), Red), Needs => 1);
      Check ("poly: inside edge", Same (Px (10, 10), Red), Needs => 1);
      Check ("poly: outside edge", Same (Px (12, 12), Black));
      Frame_Start;
      Draw_Poly ((8.0, 8.0), 4, 6.0, 45.0, Red);
      End_Drawing;
      Check ("poly: rotated 45 is axis-aligned", Same (Px (11, 11), Red), Needs => 1);
      Frame_Start;
      Draw_Poly ((8.0, 8.0), 2, 6.0, 0.0, Red);
      End_Drawing;
      Check ("poly: fewer than 3 sides draws nothing", Same (Px (8, 8), Black));

      --  Ring 3 .. 6, full turn.
      Frame_Start;
      Draw_Ring ((8.0, 8.0), 3.0, 6.0, 0.0, 360.0, 0, Red);
      End_Drawing;
      Check ("ring: hole clear", Same (Px (8, 8), Black));
      Check ("ring: band filled", Same (Px (8, 3), Red), Needs => 1);
      Check ("ring: outside clear", Same (Px (8, 0), Black));

      --  Half ring 0 .. 180: clockwise from +X with y down is the lower half.
      Frame_Start;
      Draw_Ring ((8.0, 8.0), 3.0, 6.0, 0.0, 180.0, 0, Red);
      End_Drawing;
      Check ("ring 0..180: lower half drawn", Same (Px (8, 12), Red), Needs => 1);
      Check ("ring 0..180: upper half clear", Same (Px (8, 3), Black));

      --  Radii given backwards are swapped; equal radii draw nothing.
      Frame_Start;
      Draw_Ring ((8.0, 8.0), 6.0, 3.0, 0.0, 360.0, 0, Red);
      End_Drawing;
      Check ("ring: swapped radii", Same (Px (8, 3), Red), Needs => 1);
      Frame_Start;
      Draw_Ring ((8.0, 8.0), 4.0, 4.0, 0.0, 360.0, 0, Red);
      Draw_Ring ((8.0, 8.0), 3.0, 6.0, 90.0, 90.0, 0, Red);
      End_Drawing;
      Check ("ring: empty band or sweep draws nothing", Same (Px (8, 12), Black));

      --  Lines: a thick line covers its width and stops at its endpoints.
      Frame_Start;
      Draw_Line_Ex ((2.0, 8.0), (14.0, 8.0), 3.0, Red);
      End_Drawing;
      Check ("line ex: on the line", Same (Px (8, 8), Red), Needs => 1);
      Check ("line ex: within thickness", Same (Px (8, 7), Red), Needs => 1);
      Check ("line ex: beyond thickness", Same (Px (8, 11), Black));
      Check ("line ex: before start", Same (Px (1, 8), Black));
      Check ("line ex: past end", Same (Px (14, 8), Black));
      Frame_Start;
      Draw_Line (3, 3, 3, 3, Red);
      End_Drawing;
      Check ("line: zero length draws nothing", Same (Px (3, 3), Black));

      Close_Window;
   end Test_Shapes;
begin
   Test_Collision;
   Test_Collision_Grid;
   Test_Raster;
   Test_Batch;
   Test_Input;
   Test_Core;
   Test_Camera;
   Test_Loop_And_Replay;
   Test_Console;
   Test_Atlas;
   Test_Text;
   Test_Shapes;
   New_Line;
   if Todos > 0 then
      Put_Line (Todos'Image & " TODO (waiting on milestones above" & Milestone'Image & ")");
   end if;
   if Failures = 0 then
      Put_Line ("all tests passed");
   else
      Put_Line (Failures'Image & " failure(s)");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;
end Tests;
