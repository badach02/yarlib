with Yarlib.Console;
with Yarlib.Shapes;
with Yarlib.Text;

package body Yarlib.Console_View is

   Lines : Ring;              --  what History returns
   Input : Line_Text;         --  the line being typed
   Open  : Boolean := False;  --  what Is_Open returns

   function Count (R : Ring) return Natural is
   begin
      return R.Lines_Used;
   end Count;

   procedure Push (R : in out Ring; S : String) is
      L    : constant Natural := Natural'Min (S'Length, Max_Width);
      --  When full this lands on Oldest_Slot, the line to overwrite
      Slot : constant Natural :=
        (R.Oldest_Slot + R.Lines_Used) mod Max_Lines;
   begin
      R.Lines (Slot).Text (1 .. L) := S (S'First .. S'First + L - 1);
      R.Lines (Slot).Length := L;
      if R.Lines_Used < Max_Lines then
         R.Lines_Used := R.Lines_Used + 1;
      else
         R.Oldest_Slot := (R.Oldest_Slot + 1) mod Max_Lines;
      end if;
   end Push;

   function Line (R : Ring; I : Positive) return String is
      Slot : constant Natural := (R.Oldest_Slot + I - 1) mod Max_Lines;
   begin
      return R.Lines (Slot).Text (1 .. R.Lines (Slot).Length);
   end Line;

   --  Pushes S in Max_Width pieces so a long response is not cut
   procedure Push_Wrapped (R : in out Ring; S : String) is
      First : Positive := S'First;
   begin
      loop
         Push (R, S (First .. Integer'Min (First + Max_Width - 1, S'Last)));
         First := First + Max_Width;
         exit when First > S'Last;
      end loop;
   end Push_Wrapped;

   --  The character a key types, or NUL when it types nothing
   function To_Char (K : Key) return Character is
   begin
      case K is
         when Key_A .. Key_Z =>
            return Character'Val
                (Character'Pos ('a') + Key'Pos (K) - Key'Pos (Key_A));
         when Key_0 .. Key_9 =>
            return Character'Val
                (Character'Pos ('0') + Key'Pos (K) - Key'Pos (Key_0));
         when Key_Space =>
            return ' ';
         when Key_Minus =>
            return '-';
         when Key_Period =>
            return '.';
         when others =>
            return ASCII.NUL;
      end case;
   end To_Char;

   --  Runs the typed line and clears it. An empty line does nothing.
   procedure Run_Input is
      Cmd  : constant String := Input.Text (1 .. Input.Length);
      Resp : Console.Response;
   begin
      if Cmd'Length = 0 then
         return;
      end if;
      Push_Wrapped (Lines, "> " & Cmd);
      Console.Execute (Cmd, Resp);
      Push_Wrapped (Lines, Console.Image (Resp));
      Input.Length := 0;
   end Run_Input;

   procedure Handle_Key (K : Key) is
      C : constant Character := To_Char (K);
   begin
      case K is
         when Key_Return =>
            Run_Input;
         when Key_Backspace =>
            if Input.Length > 0 then
               Input.Length := Input.Length - 1;
            end if;
         when others =>
            if C /= ASCII.NUL and then Input.Length < Max_Width then
               Input.Length              := Input.Length + 1;
               Input.Text (Input.Length) := C;
            end if;
      end case;
   end Handle_Key;

   function History return Ring is (Lines);

   function Input_Text return String is (Input.Text (1 .. Input.Length));

   procedure Toggle is
   begin
      Open := not Open;
   end Toggle;

   function Is_Open return Boolean is (Open);

   procedure Handle_Input (Ctx : Core.Context) is
      Q : constant Event_Queue := Core.Frame_Events (Ctx);
   begin
      for I in 1 .. Q.Count loop
         declare
            E : Event renames Q.Events (I);
         begin
            if E.Kind = Key_Down and then not E.Repeat then
               if E.Key = Toggle_Key then
                  Toggle;
               elsif Open then
                  Handle_Key (E.Key);
               end if;
            end if;
         end;
      end loop;
   end Handle_Input;

   procedure Handle_Input is
   begin
      Handle_Input (Core.Default.all);
   end Handle_Input;

   --  Panel layout, in pixels. Text_Size 8 is the font's own size, so
   --  glyphs land on whole pixels and stay sharp. 80 characters at 8 px
   --  is 640 px, which fits arena's 800 px window.
   Text_Size : constant := 8;
   Line_H    : constant := 12;   --  one text row plus a 4 px gap
   Pad       : constant := 6;
   Hist_End  : constant := Pad + Max_Lines * Line_H;   --  below the last row
   Input_Y   : constant := Hist_End + 4;
   Panel_H   : constant := Input_Y + Line_H + Pad;

   --  Echoed commands gray, errors red, everything else white
   function Line_Color (S : String) return Color is
     (if S'Length >= 2 and then S (S'First .. S'First + 1) = "> " then
         Light_Gray
      elsif S'Length >= 3 and then S (S'First .. S'First + 2) = "err" then
         Red
      else White);

   procedure Draw (Ctx : in out Core.Context) is
      W : constant Integer := Core.Screen_Width (Ctx);
      N : constant Natural := Count (Lines);
   begin
      if not Open then
         return;
      end if;
      Shapes.Draw_Rectangle (Ctx, 0, 0, W, Panel_H, Fade (Black, 0.8));
      Shapes.Draw_Line (Ctx, 0, Panel_H, W, Panel_H, Gray);
      Shapes.Draw_Line (Ctx, Pad, Hist_End + 1, W - Pad, Hist_End + 1, Dark_Gray);

      --  Newest line sits just above the input; older ones go up
      for I in 1 .. N loop
         declare
            L : constant String := Line (Lines, I);
         begin
            Text.Draw_Text
              (Ctx, L, Pad, Hist_End - (N - I + 1) * Line_H, Text_Size,
               Line_Color (L));
         end;
      end loop;

      Text.Draw_Text
        (Ctx, "> " & Input_Text & "_", Pad, Input_Y, Text_Size, Yellow);
   end Draw;

   procedure Draw is
   begin
      Draw (Core.Default.all);
   end Draw;

end Yarlib.Console_View;