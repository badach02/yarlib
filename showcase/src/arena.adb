--  arena: the yarlib showcase, and the shape every yarlib game has.
--
--     Init, then Update (Dt) at a fixed rate, then Draw (Alpha) once a
--     frame. Yarlib.Game_Loop runs it. Yarlib.Replay records it.
--     Yarlib.Console drives it.
--
--     arena                        play: WASD or arrows, Escape quits,
--                                  ` (grave) opens the console
--     arena --record session.rec   play and record every input
--     arena --replay session.rec   replay it, same result, no hands
--     arena --frames 120           120 frames, then write shot.png and
--                                  exit 0 if the ship's pixel is right
--     arena -c "spawn 100 100 20"  run a console line first (repeatable)
--
--  Until milestone 1 (the batcher) the window shows the clear colour
--  and nothing else, --frames exits 1, and the library reports the
--  dropped quads on stdout. That is the seed's expected state.
--
--  This program knows Yarlib.Core, Shapes, Textures, Game_Loop, Replay
--  and Console. It does not know SDL, OpenGL, the batch, or the
--  rasterizer. What it needs and cannot get from those is a missing
--  yarlib feature, not a reason to reach past them.

with Bedrock.Buffers;
with Bedrock.Colors;  use Bedrock.Colors;
with Ada.Command_Line;  use Ada.Command_Line;
with Ada.Text_IO;       use Ada.Text_IO;
with Yarlib;            use Yarlib;
with Yarlib.Console;
with Yarlib.Core;       use Yarlib.Core;
with Yarlib.Game_Loop;
with Yarlib.Replay;
with Yarlib.PNG;
with Arena_Game;        use Arena_Game;

procedure Arena is

   package Game is new Yarlib.Game_Loop (Update, Draw);

   Session     : Replay.Session;
   Frames      : Natural := 0;
   Ok          : Boolean;
   I           : Positive := 1;

begin
   Init_Window (W, H, "yarlib arena");
   Init;

   while I <= Argument_Count loop
      if Argument (I) = "--frames" and then I < Argument_Count then
         Frames := Natural'Value (Argument (I + 1));
         I := I + 2;
      elsif Argument (I) = "--record" and then I < Argument_Count then
         Replay.Start_Recording (Session, Argument (I + 1), Ok);
         if not Ok then
            Put_Line ("arena: cannot record to " & Argument (I + 1));
         end if;
         I := I + 2;
      elsif Argument (I) = "--replay" and then I < Argument_Count then
         Replay.Start_Replay (Session, Default.all, Argument (I + 1), Ok);
         if not Ok then
            Put_Line ("arena: cannot replay " & Argument (I + 1));
         end if;
         I := I + 2;
      elsif Argument (I) = "-c" and then I < Argument_Count then
         declare
            R : Console.Response;
         begin
            Console.Execute (Argument (I + 1), R);
            Put_Line (Console.Image (R));
         end;
         I := I + 2;
      else
         Put_Line ("arena: unknown argument " & Argument (I));
         I := I + 1;
      end if;
   end loop;

   Game.Run (Default.all, Session, Max_Frames => Frames);
   Replay.Stop (Session, Default.all);

   if Frames > 0 then
      --  Acceptance: the ship's centre pixel is the ship's colour. One
      --  readback of the frame, then a PNG anybody can open.
      declare
         Shot : constant Bitmap := Screenshot;
         C    : constant Color :=
           Bedrock.Buffers.Get (Shot, Integer (Ship.X) + 16, Integer (Ship.Y) + 16);
      begin
         Yarlib.PNG.Save (Shot, "shot.png", Ok);
         if not Ok then
            Put_Line ("arena: cannot write shot.png");
         end if;
         if C.R = Ship_Color.R and C.G = Ship_Color.G and C.B = Ship_Color.B then
            Put_Line ("arena: ship pixel ok");
         else
            Put_Line ("arena: ship pixel is" & C.R'Image & C.G'Image & C.B'Image
                      & " (milestone 1 not done?)");
            Set_Exit_Status (Failure);
         end if;
      end;
   end if;
   Put_Line ("arena: blocks" & Block_Count'Image & " ship at"
             & Integer (Ship.X)'Image & Integer (Ship.Y)'Image);
   Close_Window;
end Arena;
