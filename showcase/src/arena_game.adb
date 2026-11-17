with Ada.Directories;
with Ada.Strings;
with Ada.Strings.Fixed;
with Bedrock.Colors;   use Bedrock.Colors;
with Bedrock.Input;    use Bedrock.Input;
with Yarlib.Core;      use Yarlib.Core;
with Yarlib.Shapes;    use Yarlib.Shapes;
with Yarlib.Textures;  use Yarlib.Textures;
with Yarlib.Collision.Grid;
with Yarlib.Text; use Yarlib.Text;
with Yarlib.Console_View;
package body Arena_Game is

   type Block is record
      Pos, Prev_Pos, Vel : Vector2;
      Size     : Scalar;
   end record;

   Stress_Blocks : constant := 2_000;
   Max_Regular_Blocks : constant := 256;
   Blocks : array (1 .. Stress_Blocks) of Block;
   N      : Natural := 0;

   --  Padding covers the overshoot on a bounce at either screen edge.
   package Block_Grid is new Collision.Grid
     (Origin_X => -32.0, Origin_Y => -32.0, Columns => 27, Rows => 17,
      Cell_Size => 32, Max_Per_Cell => 128, Max_Id => Stress_Blocks);
   Grid           : Block_Grid.Grid;
   Stress         : Boolean := False;
   Colliding      : array (Blocks'Range) of Boolean := [others => False];
   Pair_Count     : Natural := 0;
   Grid_Fallback  : Boolean := False;
   Warmup_Frames  : constant := 30;
   Sample_Frames  : constant := 120;
   Target_Ms      : constant := 16.0;
   Warmup_Left    : Natural := 0;
   Samples        : Natural := 0;
   Total_Ms       : Scalar := 0.0;
   Peak_Ms        : Scalar := 0.0;
   Missed_Target  : Natural := 0;

   Prev_Ship : Rectangle; -- to store previous ship location for interp
   Speed  : constant Scalar := 260.0;
   Wall   : constant Rectangle := (600.0, 135.0, 24.0, 180.0);
   Backdrop, Ship_Sprite, Asteroid : Texture;
   Facing_Left : Boolean := False;

   function Block_Count return Natural is (N);
   function Stress_Active return Boolean is (Stress);

   procedure Add_Block (X, Y, Size : Scalar);
   procedure Find_Block_Collisions;
   procedure Sample_Stress_Frame;
   procedure Cmd_Stress (Args : String; R : out Console.Response);
   procedure Numbers (Args : String; A, B, C : out Scalar; Want : Positive; Ok : out Boolean);
   procedure Draw_Sprite
     (Sprite : Texture; Dest : Rectangle; Tint : Color := White; Flip_X : Boolean := False);

   procedure Add_Block (X, Y, Size : Scalar) is
   begin
      if N < Blocks'Length then
         N := N + 1;
         Blocks (N) :=
           (Pos  => (X, Y),
            Vel  => (Scalar (40 + 15 * (N mod 7)) * (if N mod 2 = 0 then 1.0 else -1.0),
                     Scalar (30 + 11 * (N mod 5)) * (if N mod 3 = 0 then 1.0 else -1.0)),
            --  Initialize both positions in case drawing happens before the first update.
            Prev_Pos => (X, Y),
            Size => Size);
      end if;
   end Add_Block;

   procedure Find_Block_Collisions is
      Rects : array (Blocks'Range) of Rectangle;
      Candidates : Block_Grid.Id_List (Blocks'Range);
      Count : Natural;
      Ok : Boolean := True;

      procedure Check_Pair (I, J : Positive);
      procedure Check_Pair (I, J : Positive) is
      begin
         if Collision.Check_Collision_Recs (Rects (I), Rects (J)) then
            Pair_Count := Pair_Count + 1;
            Colliding (I) := True;
            Colliding (J) := True;
         end if;
      end Check_Pair;
   begin
      Colliding := [others => False];
      Pair_Count := 0;
      Block_Grid.Clear (Grid);
      for I in 1 .. N loop
         Rects (I) := (Blocks (I).Pos.X, Blocks (I).Pos.Y, Blocks (I).Size, Blocks (I).Size);
      end loop;
      for I in 1 .. N loop
         Block_Grid.Insert (Grid, I, Rects (I), Ok);
         exit when not Ok;
      end loop;
      if Ok then
         for I in 1 .. N loop
            Block_Grid.Query (Grid, Rects (I), Candidates, Count, Ok);
            exit when not Ok;
            for J in 1 .. Count loop
               if Candidates (J) > I then
                  Check_Pair (I, Candidates (J));
               end if;
            end loop;
         end loop;
      end if;
      if not Ok then
         --  Keep exact results even if the scene exceeds the grid's capacity.
         Grid_Fallback := True;
         Colliding := [others => False];
         Pair_Count := 0;
         for I in 1 .. N loop
            for J in I + 1 .. N loop
               Check_Pair (I, J);
            end loop;
         end loop;
      end if;
   end Find_Block_Collisions;

   procedure Sample_Stress_Frame is
      Ms : constant Scalar := Get_Frame_Time * 1_000.0;
   begin
      if Warmup_Left > 0 then
         Warmup_Left := Warmup_Left - 1;
      elsif Samples < Sample_Frames then
         Samples := Samples + 1;
         Total_Ms := Total_Ms + Ms;
         Peak_Ms := Scalar'Max (Peak_Ms, Ms);
         if Ms >= Target_Ms then
            Missed_Target := Missed_Target + 1;
         end if;
      end if;
   end Sample_Stress_Frame;

   ----------
   --  Init --
   ----------

   procedure Init (Asset_Directory : String := "assets/space") is
      use Ada.Directories;
   begin
      Ship := (Scalar (W) / 2.0 - 32.0, Scalar (H) / 2.0 - 32.0, 64.0, 64.0);
      --  Set previous location of ship on creation
      Prev_Ship := Ship;
      Facing_Left := False;
      Backdrop := Load_Texture (Compose (Asset_Directory, "space-backdrop.qoi"));
      Ship_Sprite := Load_Texture (Compose (Asset_Directory, "ship.qoi"));
      Asteroid := Load_Texture (Compose (Asset_Directory, "asteroid.qoi"));
      N := 0;
      Stress := False;
      for I in 1 .. 12 loop
         Add_Block (Scalar (60 * I mod W), Scalar (37 * I mod H), Scalar (12 + I * 2));
      end loop;
      Console.Register ("spawn", Cmd_Spawn'Access, "X Y SIZE");
      Console.Register ("clear", Cmd_Clear'Access, "remove all blocks");
      Console.Register ("ship", Cmd_Ship'Access, "X Y");
      Console.Register ("list", Cmd_List'Access);
      Console.Register ("stress", Cmd_Stress'Access, "2000 | stats; clear to stop");
   end Init;

   ------------
   --  Update --
   ------------

   procedure Update (Dt : Scalar) is
      Steering_Enabled : constant Boolean := not Console_View.Is_Open;
   begin
      --  Before we change the ship location, save previous location to interp it
      Prev_Ship := Ship;

      --  Reserve movement keys for typing while the console is open.
      if Steering_Enabled then
         if Is_Key_Down (Key_Left) or Is_Key_Down (Key_A) then
            Ship.X := Ship.X - Speed * Dt;
         end if;
         if Is_Key_Down (Key_Right) or Is_Key_Down (Key_D) then
            Ship.X := Ship.X + Speed * Dt;
         end if;
         if Ship.X < Prev_Ship.X then
            Facing_Left := True;
         elsif Ship.X > Prev_Ship.X then
            Facing_Left := False;
         end if;
      end if;
      Ship.X := Scalar'Max (0.0, Scalar'Min (Scalar (W) - Ship.Width, Ship.X));

      --  Resolve each axis separately, using the previous position to stop
      --  the ship even if a large movement would jump across the wall.
      if Ship.Y < Wall.Y + Wall.Height and then Ship.Y + Ship.Height > Wall.Y then
         if Prev_Ship.X + Ship.Width <= Wall.X
           and then Ship.X + Ship.Width > Wall.X
         then
            Ship.X := Wall.X - Ship.Width;
         elsif Prev_Ship.X >= Wall.X + Wall.Width
           and then Ship.X < Wall.X + Wall.Width
         then
            Ship.X := Wall.X + Wall.Width;
         end if;
      end if;

      if Steering_Enabled then
         if Is_Key_Down (Key_Up) or Is_Key_Down (Key_W) then
            Ship.Y := Ship.Y - Speed * Dt;
         end if;
         if Is_Key_Down (Key_Down) or Is_Key_Down (Key_S) then
            Ship.Y := Ship.Y + Speed * Dt;
         end if;
      end if;
      Ship.Y := Scalar'Max (0.0, Scalar'Min (Scalar (H) - Ship.Height, Ship.Y));
      if Ship.X < Wall.X + Wall.Width and then Ship.X + Ship.Width > Wall.X then
         if Prev_Ship.Y + Ship.Height <= Wall.Y
           and then Ship.Y + Ship.Height > Wall.Y
         then
            Ship.Y := Wall.Y - Ship.Height;
         elsif Prev_Ship.Y >= Wall.Y + Wall.Height
           and then Ship.Y < Wall.Y + Wall.Height
         then
            Ship.Y := Wall.Y + Wall.Height;
         end if;
      end if;

      for I in 1 .. N loop
         declare
            B : Block renames Blocks (I);
         begin
            --  store the previous position to use for interpolation.
            B.Prev_Pos := B.Pos;
            B.Pos := B.Pos + B.Vel * Dt;
            if B.Pos.X < 0.0 or else B.Pos.X + B.Size > Scalar (W) then
               B.Vel.X := -B.Vel.X;
            end if;
            if B.Pos.Y < 0.0 or else B.Pos.Y + B.Size > Scalar (H) then
               B.Vel.Y := -B.Vel.Y;
            end if;
         end;
      end loop;
      if Stress then
         Find_Block_Collisions;
      end if;
   end Update;

   ----------
   --  Draw --
   ----------

   procedure Draw_Sprite
     (Sprite : Texture; Dest : Rectangle; Tint : Color := White; Flip_X : Boolean := False)
   is
   begin
      Draw_Texture_Pro
        (Sprite,
         Source => ((if Flip_X then Scalar (Sprite.Width) else 0.0), 0.0,
                    (if Flip_X then -Scalar (Sprite.Width) else Scalar (Sprite.Width)),
                    Scalar (Sprite.Height)),
         Dest => Dest, Origin => (0.0, 0.0), Rotation => 0.0, Tint => Tint);
   end Draw_Sprite;

   procedure Draw (Alpha : Scalar) is
      --  Create a new ship to copy its hidth and height for interp.
      Draw_Ship : Rectangle := Ship;
      --  pragma Unreferenced (Alpha);   --  interpolate Pos with Vel * Alpha * Dt: milestone 4
   begin
      if Stress then
         --  Core records the previous complete frame, including the swap.
         Sample_Stress_Frame;
      end if;
      --  calculate X & Y interp for ship
      Draw_Ship.X := Prev_Ship.X + (Ship.X - Prev_Ship.X) * Alpha;
      Draw_Ship.Y := Prev_Ship.Y + (Ship.Y - Prev_Ship.Y) * Alpha;

      Clear_Background (Black);
      Draw_Sprite (Backdrop, (0.0, 0.0, Scalar (W), Scalar (H)));
      Draw_Rectangle_Lines (8, 8, W - 16, H - 16, Light_Gray);
      Draw_Rectangle_Rec (Wall, Gray);
      for I in 1 .. N loop
         declare
            B : Block renames Blocks (I);
            --  Compute interpolation for prev->new position.
            --  Alpha is a fractional measurement of how far the
            --  blend has traveled. Example 100->102:
            --  An alpha of 0.5 means we are at 101.
            Draw_Pos : constant Vector2 := B.Prev_Pos + (B.Pos - B.Prev_Pos) * Alpha;
            Draw_Block : constant Rectangle := (Draw_Pos.X, Draw_Pos.Y, B.Size, B.Size);
         begin
            Draw_Sprite
              (Asteroid, Draw_Block,
               (if (Stress and then Colliding (I))
                   or else (Collision.Valid_Rectangle (Draw_Block)
                            and then Collision.Valid_Rectangle (Draw_Ship)
                            and then Collision.Check_Collision_Recs (Draw_Block, Draw_Ship))
                then Magenta else White));
         end;
      end loop;
      declare
         Ship_Center : constant Vector2 := Center (Draw_Ship);
         Radius : constant Scalar := Scalar'Min (Draw_Ship.Width, Draw_Ship.Height) / 2.0;
      begin
         Draw_Line_Ex (Ship_Center, Get_Mouse_Position, 2.0, White);
         Draw_Ring (Ship_Center, Radius - 2.0, Radius, 0.0, 360.0, 0, White);
         Draw_Sprite (Ship_Sprite, Draw_Ship, Flip_X => Facing_Left);
      end;
      --  Print fps and block count
      Draw_Text ("FPS:" & Get_FPS'Image, 16, 16, 16, White);
      Draw_Text ("Blocks:" & Block_Count'Image, 16, 36, 16, White);
      if Stress then
         Draw_Text ("Overlapping pairs:" & Pair_Count'Image, 16, 56, 16, White);
         if Grid_Fallback then
            Draw_Text ("Grid overflow: exact fallback used", 16, 76, 16, Magenta);
         end if;
      end if;

      --  The console is drawn last so it sits on top. Its keys are read
      --  here, not in Update: Update runs 0 to 5 times a frame, Draw once.
      Console_View.Handle_Input;
      Console_View.Draw;
   end Draw;

   -------------
   --  Console --
   -------------

   --  Three numbers out of Args, or Ok = False.
   procedure Numbers (Args : String; A, B, C : out Scalar; Want : Positive; Ok : out Boolean) is
      P     : Natural := Args'First;
      Got   : Natural := 0;
      Vals  : array (1 .. 3) of Scalar := [others => 0.0];
   begin
      while Got < Want loop
         while P <= Args'Last and then Args (P) = ' ' loop
            P := P + 1;
         end loop;
         exit when P > Args'Last;
         declare
            S : constant Natural := P;
         begin
            while P <= Args'Last and then Args (P) /= ' ' loop
               P := P + 1;
            end loop;
            Got := Got + 1;
            Vals (Got) := Scalar'Value (Args (S .. P - 1));
         end;
      end loop;
      A := Vals (1);
      B := Vals (2);
      C := Vals (3);
      Ok := Got = Want;
   exception
      when Constraint_Error =>
         A := 0.0;
         B := 0.0;
         C := 0.0;
         Ok := False;
   end Numbers;

   procedure Cmd_Spawn (Args : String; R : out Console.Response) is
      X, Y, S : Scalar;
      Ok : Boolean;
   begin
      Numbers (Args, X, Y, S, 3, Ok);
      if not Ok or else S <= 0.0 then
         Console.Set (R, False, "err spawn X Y SIZE");
      elsif Stress or else N = Max_Regular_Blocks then
         Console.Set (R, False, "err arena full");
      else
         Add_Block (X, Y, S);
         Console.Set (R, True, "ok block" & N'Image);
      end if;
   end Cmd_Spawn;

   procedure Cmd_Clear (Args : String; R : out Console.Response) is
      pragma Unreferenced (Args);
   begin
      N := 0;
      Stress := False;
      Console.Set (R, True, "ok");
   end Cmd_Clear;

   procedure Cmd_Stress (Args : String; R : out Console.Response) is
      Arg : constant String := Ada.Strings.Fixed.Trim (Args, Ada.Strings.Both);
      type Milliseconds is delta 0.01 digits 12;
   begin
      if Arg = "2000" then
         N := 0;
         Stress := True;
         Grid_Fallback := False;
         Warmup_Left := Warmup_Frames;
         Samples := 0;
         Total_Ms := 0.0;
         Peak_Ms := 0.0;
         Missed_Target := 0;
         for I in 0 .. Stress_Blocks - 1 loop
            --  Fifty blocks per row, arranged in overlapping pairs.
            Add_Block (Scalar (30 * ((I mod 50) / 2) + 5 * (I mod 2)),
                       Scalar (11 * (I / 50)), 10.0);
         end loop;
         Find_Block_Collisions;
         Console.Set (R, True, "ok 2000 blocks; use stress stats after 150 frames");
      elsif Arg = "stats" then
         if not Stress then
            Console.Set (R, False, "err no stress scene; use stress 2000");
         elsif Grid_Fallback then
            Console.Set (R, False, "err grid overflow; exact fallback used");
         elsif Samples = 0 then
            Console.Set (R, True, "ok warming up; overlapping pairs" & Pair_Count'Image);
         else
            Console.Set
              (R, True,
               "ok" & Samples'Image & " frames;"
               & " mean" & Milliseconds'Image (Milliseconds (Total_Ms / Scalar (Samples)))
               & " ms peak" & Milliseconds'Image (Milliseconds (Peak_Ms))
               & " ms;" & Missed_Target'Image & " at >=16 ms; pairs" & Pair_Count'Image);
         end if;
      else
         Console.Set (R, False, "err stress 2000 | stats");
      end if;
   end Cmd_Stress;

   procedure Cmd_Ship (Args : String; R : out Console.Response) is
      X, Y, Z : Scalar;
      Ok : Boolean;
   begin
      Numbers (Args, X, Y, Z, 2, Ok);
      if not Ok then
         Console.Set (R, False, "err ship X Y");
      else
         Ship.X := X;
         Ship.Y := Y;

         --  update ship pos for interp on teleport
         Prev_Ship := Ship;
         Console.Set (R, True, "ok");
      end if;
   end Cmd_Ship;

   procedure Cmd_List (Args : String; R : out Console.Response) is
      pragma Unreferenced (Args);
   begin
      Console.Set (R, True, "ok ship" & Integer (Ship.X)'Image & Integer (Ship.Y)'Image
                   & " blocks" & N'Image);
      for I in 1 .. N loop
         Console.Append (R, " (" & Integer (Blocks (I).Pos.X)'Image
                         & Integer (Blocks (I).Pos.Y)'Image
                         & Integer (Blocks (I).Size)'Image & ")");
      end loop;
   end Cmd_List;

end Arena_Game;
