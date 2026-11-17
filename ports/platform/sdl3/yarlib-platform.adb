--  SDL3 platform port: one window with an OpenGL context.

with Ada.Text_IO;
with Interfaces;         use Interfaces;
with Interfaces.C;       use Interfaces.C;
with Interfaces.C.Strings;
with System;
with Bedrock.Screen;
with Yarlib.Platform.SDL; use Yarlib.Platform.SDL;

package body Yarlib.Platform is

   use type System.Address;

   Window  : System.Address := System.Null_Address;
   Context : System.Address := System.Null_Address;
   Epoch   : Unsigned_64 := 0;

   procedure Fail (What : String);
   function To_Key (Scancode : Unsigned_32) return Key;

   procedure Fail (What : String) is
   begin
      Ada.Text_IO.Put_Line
        ("yarlib/sdl3: " & What & ": " & C.Strings.Value (SDL_GetError));
   end Fail;

   ----------
   -- Open --
   ----------

   procedure Open (Width, Height : Positive; Title : String; Ok : out Boolean) is
   begin
      Ok := False;
      if not SDL_Init (Init_Video) then
         Fail ("SDL_Init");
         return;
      end if;
      --  The opengl GPU port is fixed-function GL 1.x. Ask for 2.1: a
      --  version below 3.2 has no profiles and is compatibility by
      --  definition, on GLX, EGL and WGL alike. SDL's default on some
      --  platforms is a core context, where glEnableClientState errors.
      if not SDL_GL_SetAttribute (GL_Context_Major_Version, 2)
        or else not SDL_GL_SetAttribute (GL_Context_Minor_Version, 1)
      then
         Fail ("SDL_GL_SetAttribute");
      end if;
      Window := SDL_CreateWindow
        (To_C (Title), int (Width), int (Height), Window_OpenGL or Window_Resizable);
      if Window = System.Null_Address then
         Fail ("SDL_CreateWindow");
         SDL_Quit;
         return;
      end if;
      Context := SDL_GL_CreateContext (Window);
      if Context = System.Null_Address then
         Fail ("SDL_GL_CreateContext");
         SDL_DestroyWindow (Window);
         SDL_Quit;
         return;
      end if;
      if not SDL_GL_SetSwapInterval (1) then
         null;   --  no vsync is not fatal
      end if;
      Epoch := SDL_GetTicksNS;
      Ok := True;
   end Open;

   -----------
   -- Close --
   -----------

   procedure Close is
   begin
      if Context /= System.Null_Address then
         if not SDL_GL_DestroyContext (Context) then
            null;
         end if;
         Context := System.Null_Address;
      end if;
      if Window /= System.Null_Address then
         SDL_DestroyWindow (Window);
         Window := System.Null_Address;
      end if;
      SDL_Quit;
   end Close;

   ----------
   -- Poll --
   ----------

   function To_Key (Scancode : Unsigned_32) return Key is
      S : constant Natural := Natural (Scancode);
   begin
      if S in Scan_A .. Scan_A + 25 then
         return Key'Val (Key'Pos (Key_A) + (S - Scan_A));
      elsif S in Scan_1 .. Scan_1 + 8 then
         return Key'Val (Key'Pos (Key_1) + (S - Scan_1));
      elsif S in Scan_F1 .. Scan_F1 + 11 then
         return Key'Val (Key'Pos (Key_F1) + (S - Scan_F1));
      end if;
      case S is
         when Scan_0         => return Key_0;
         when Scan_Return    => return Key_Return;
         when Scan_Escape    => return Key_Escape;
         when Scan_Backspace => return Key_Backspace;
         when Scan_Tab       => return Key_Tab;
         when Scan_Space     => return Key_Space;
         when Scan_Right     => return Key_Right;
         when Scan_Left      => return Key_Left;
         when Scan_Down      => return Key_Down;
         when Scan_Up        => return Key_Up;
         when Scan_LCtrl     => return Key_Left_Ctrl;
         when Scan_LShift    => return Key_Left_Shift;
         when Scan_RCtrl     => return Key_Right_Ctrl;
         when Scan_RShift    => return Key_Right_Shift;
         when others         => return Key_Unknown;
      end case;
   end To_Key;

   procedure Poll (E : out Event; Got : out Boolean) is
      Raw : aliased SDL_Event;
   begin
      loop
         if not SDL_PollEvent (Raw'Access) then
            E := Quit_Event;
            Got := False;
            return;
         end if;
         case Raw.Event_Type is
            when Event_Quit =>
               E := Quit_Event;
               Got := True;
               return;
            when Event_Key_Down | Event_Key_Up =>
               declare
                  KE : Keyboard_Event with Import, Address => Raw'Address;
                  K  : constant Key := To_Key (KE.Scancode);
               begin
                  if K /= Key_Unknown then
                     E := Key_Event (K, Down => Boolean (KE.Down),
                                     Repeat => Boolean (KE.Is_Repeat));
                     Got := True;
                     return;
                  end if;
               end;
            when Event_Mouse_Motion =>
               declare
                  ME : Mouse_Motion_Event with Import, Address => Raw'Address;
               begin
                  E := Move_Event (Bedrock.Screen.Pixels (ME.X), Bedrock.Screen.Pixels (ME.Y));
                  Got := True;
                  return;
               end;
            when Event_Mouse_Button_Down | Event_Mouse_Button_Up =>
               declare
                  BE : Mouse_Button_Event with Import, Address => Raw'Address;
                  B  : constant Mouse_Button :=
                    (case BE.Button is
                        when 1 => Left, when 3 => Right, when 2 => Middle,
                        when 4 => Back, when others => Forward);
               begin
                  E := Button_Event (B, Down => Boolean (BE.Down),
                                     X => Bedrock.Screen.Pixels (BE.X),
                                     Y => Bedrock.Screen.Pixels (BE.Y));
                  Got := True;
                  return;
               end;
            when Event_Window_Resized =>
               declare
                  WE : Window_Event with Import, Address => Raw'Address;
               begin
                  if WE.Data1 > 0 and then WE.Data2 > 0 then
                     E := Resize_Event (Bedrock.Screen.Extent (WE.Data1),
                                        Bedrock.Screen.Extent (WE.Data2));
                     Got := True;
                     return;
                  end if;
               end;
            when others =>
               null;   --  ignored; loop for the next one
         end case;
      end loop;
   end Poll;

   ----------
   -- Swap --
   ----------

   procedure Swap is
   begin
      if not SDL_GL_SwapWindow (Window) then
         null;
      end if;
   end Swap;

   ---------
   -- Now --
   ---------

   function Now return Duration is
     (Duration (Long_Long_Float (SDL_GetTicksNS - Epoch) / 1.0E9));

end Yarlib.Platform;
