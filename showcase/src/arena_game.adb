with Bedrock.Input;    use Bedrock.Input;
with Yarlib.Core;      use Yarlib.Core;
with Yarlib.Shapes;    use Yarlib.Shapes;
with Yarlib.Textures;  use Yarlib.Textures;

package body Arena_Game is

   type Block is record
      Pos, Prev_Pos, Vel : Vector2;
      Size     : Scalar;
      Tint     : Color;
   end record;

   Max_Blocks : constant := 256;
   Blocks : array (1 .. Max_Blocks) of Block;
   N      : Natural := 0;

   Prev_Ship : Rectangle; -- to store previous ship location for interp
   Speed  : constant Scalar := 260.0;
   Sprite : Texture;
   Angle  : Degrees := 0.0;

   function Block_Count return Natural is (N);

   procedure Add_Block (X, Y, Size : Scalar; Tint : Color);
   procedure Numbers (Args : String; A, B, C : out Scalar; Want : Positive; Ok : out Boolean);

   procedure Add_Block (X, Y, Size : Scalar; Tint : Color) is
   begin
      if N < Max_Blocks then
         N := N + 1;
         Blocks (N) :=
           (Pos  => (X, Y),
            Vel  => (Scalar (40 + 15 * (N mod 7)) * (if N mod 2 = 0 then 1.0 else -1.0),
                     Scalar (30 + 11 * (N mod 5)) * (if N mod 3 = 0 then 1.0 else -1.0)),
            --  Initialize both positions in case drawing happens before the first update.
            Prev_Pos => (X, Y),
            Size => Size, Tint => Tint);
      end if;
   end Add_Block;

   ----------
   --  Init --
   ----------

   procedure Init is
   begin
      Ship := (Scalar (W) / 2.0 - 16.0, Scalar (H) / 2.0 - 16.0, 32.0, 32.0);
      --  Set previous location of ship on creation
      Prev_Ship := Ship;
      Sprite := Checkerboard (32, 32, 8, Orange, Purple);
      N := 0;
      for I in 1 .. 12 loop
         Add_Block (Scalar (60 * I mod W), Scalar (37 * I mod H), Scalar (12 + I * 2),
                    (if I mod 3 = 0 then Red elsif I mod 3 = 1 then Green else Yellow));
      end loop;
      Console.Register ("spawn", Cmd_Spawn'Access, "X Y SIZE");
      Console.Register ("clear", Cmd_Clear'Access, "remove all blocks");
      Console.Register ("ship", Cmd_Ship'Access, "X Y");
      Console.Register ("list", Cmd_List'Access);
   end Init;

   ------------
   --  Update --
   ------------

   procedure Update (Dt : Scalar) is
   begin
      --  Before we change the ship location, save previous location to interp it
      Prev_Ship := Ship;

      if Is_Key_Down (Key_Left) or Is_Key_Down (Key_A) then
         Ship.X := Ship.X - Speed * Dt;
      end if;
      if Is_Key_Down (Key_Right) or Is_Key_Down (Key_D) then
         Ship.X := Ship.X + Speed * Dt;
      end if;
      if Is_Key_Down (Key_Up) or Is_Key_Down (Key_W) then
         Ship.Y := Ship.Y - Speed * Dt;
      end if;
      if Is_Key_Down (Key_Down) or Is_Key_Down (Key_S) then
         Ship.Y := Ship.Y + Speed * Dt;
      end if;
      Ship.X := Scalar'Max (0.0, Scalar'Min (Scalar (W) - Ship.Width, Ship.X));
      Ship.Y := Scalar'Max (0.0, Scalar'Min (Scalar (H) - Ship.Height, Ship.Y));

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
      Angle := Angle + Degrees (90.0 * Dt);
   end Update;

   ----------
   --  Draw --
   ----------

   procedure Draw (Alpha : Scalar) is
      --  Create a new ship to copy its hidth and height for interp.
      Draw_Ship : Rectangle := Ship;
      --  pragma Unreferenced (Alpha);   --  interpolate Pos with Vel * Alpha * Dt: milestone 4
   begin
      --  calculate X & Y interp for ship
      Draw_Ship.X := Prev_Ship.X + (Ship.X - Prev_Ship.X) * Alpha;
      Draw_Ship.Y := Prev_Ship.Y + (Ship.Y - Prev_Ship.Y) * Alpha;

      Clear_Background (Dark_Gray);
      Draw_Rectangle_Lines (8, 8, W - 16, H - 16, Light_Gray);
      for I in 1 .. N loop
         declare
            B : Block renames Blocks (I);
            --  Compute interpolation for prev->new position.
            --  Alpha is a fractional measurement of how far the
            --  blend has traveled. Example 100->102:
            --  An alpha of 0.5 means we are at 101.
            Draw_Pos : constant Vector2 := B.Prev_Pos + (B.Pos - B.Prev_Pos) * Alpha;
         begin
            Draw_Rectangle_Rec ((Draw_Pos.X, Draw_Pos.Y, B.Size, B.Size), B.Tint);
         end;
      end loop;
      Draw_Texture_Pro
        (Sprite, (0.0, 0.0, 32.0, 32.0), (100.0, 100.0, 64.0, 64.0), (32.0, 32.0), Angle);
      Draw_Rectangle_Rec (Draw_Ship, Ship_Color);
      Draw_Line_Ex ((Draw_Ship.X + 16.0, Draw_Ship.Y + 16.0), Get_Mouse_Position, 2.0, White);
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
      elsif N = Max_Blocks then
         Console.Set (R, False, "err arena full");
      else
         Add_Block (X, Y, S, White);
         Console.Set (R, True, "ok block" & N'Image);
      end if;
   end Cmd_Spawn;

   procedure Cmd_Clear (Args : String; R : out Console.Response) is
      pragma Unreferenced (Args);
   begin
      N := 0;
      Console.Set (R, True, "ok");
   end Cmd_Clear;

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
