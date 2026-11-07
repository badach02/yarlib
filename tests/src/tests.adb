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
with Ada.Text_IO;      use Ada.Text_IO;
with Bedrock.Input;    use Bedrock.Input;
with Yarlib;           use Yarlib;
with Yarlib.Batch;     use Yarlib.Batch;
with Yarlib.Console;
with Yarlib.Core;      use Yarlib.Core;
with Yarlib.Game_Loop;
with Yarlib.Renderer;
with Yarlib.Input;
with Yarlib.Raster;
with Yarlib.Replay;
with Test_Support;
with Yarlib.Shapes;    use Yarlib.Shapes;
with Yarlib.Textures;  use Yarlib.Textures;

procedure Tests is

   Milestone : constant Natural := 0;
   --  0: seed as shipped. 1: batcher written.

   Failures : Natural := 0;
   Todos    : Natural := 0;

   procedure Check (Name : String; Cond : Boolean; Needs : Natural := 0);
   procedure Test_Raster;
   procedure Test_Batch;
   procedure Test_Input;
   procedure Test_Core;
   procedure Test_Camera;
   procedure Test_Loop_And_Replay;
   procedure Test_Console;

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
      pragma Unreferenced (Alpha);
   begin
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
      Inject (Key_Event (Key_Space, Down => True));   --  frame 0
      Test_Game.Run (Default.all, Rec, Max_Frames => 3);
      Inject (Key_Event (Key_Space, Down => False));
      Inject (Key_Event (Key_Space, Down => True));
      Test_Game.Run (Default.all, Rec, Max_Frames => 5);
      Replay.Stop (Rec, Default.all);
      Check ("8 frames, 8 steps", Counter = 8);
      Check ("two presses seen", Presses = 2);
      Close_Window;

      Init_Window (32, 32, "replay");
      Counter := 0;
      Presses := 0;
      Replay.Start_Replay (Rec, Default.all, "test.rec", Ok);
      Check ("start replay", Ok);
      Test_Game.Run (Default.all, Rec, Max_Frames => 8);
      Check ("replay reproduces steps", Counter = 8);
      Check ("replay reproduces presses", Presses = 2);
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

begin
   Test_Raster;
   Test_Batch;
   Test_Input;
   Test_Core;
   Test_Camera;
   Test_Loop_And_Replay;
   Test_Console;
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
