--  Minimal SDL3 binding: the ten calls the sdl3 port needs, nothing
--  else. Layouts and values are from SDL 3.2 headers. Shapes follow
--  the binding in adi2 (Aldo Nicolas Bruno, Apache-2.0), in particular
--  the tag-plus-storage trick for the SDL_Event union; when an sdl3
--  crate exists in the Alire index this file goes away and the port
--  withs that instead.

with Interfaces;
with Interfaces.C;
with Interfaces.C.Strings;
with System;

private package Yarlib.Platform.SDL is

   use Interfaces;

   subtype Bool is C.C_bool;

   Init_Video : constant Unsigned_32 := 16#20#;

   function SDL_Init (Flags : Unsigned_32) return Bool
     with Import, Convention => C, External_Name => "SDL_Init";

   procedure SDL_Quit
     with Import, Convention => C, External_Name => "SDL_Quit";

   function SDL_GetError return C.Strings.chars_ptr
     with Import, Convention => C, External_Name => "SDL_GetError";

   Window_OpenGL    : constant Unsigned_64 := 16#02#;
   Window_Resizable : constant Unsigned_64 := 16#20#;

   function SDL_CreateWindow
     (Title : C.char_array; W, H : C.int; Flags : Unsigned_64) return System.Address
     with Import, Convention => C, External_Name => "SDL_CreateWindow";

   procedure SDL_DestroyWindow (W : System.Address)
     with Import, Convention => C, External_Name => "SDL_DestroyWindow";

   GL_Context_Major_Version : constant C.int := 17;
   GL_Context_Minor_Version : constant C.int := 18;

   function SDL_GL_SetAttribute (Attr : C.int; Value : C.int) return Bool
     with Import, Convention => C, External_Name => "SDL_GL_SetAttribute";

   function SDL_GL_CreateContext (W : System.Address) return System.Address
     with Import, Convention => C, External_Name => "SDL_GL_CreateContext";

   function SDL_GL_DestroyContext (Ctx : System.Address) return Bool
     with Import, Convention => C, External_Name => "SDL_GL_DestroyContext";

   function SDL_GL_SetSwapInterval (Interval : C.int) return Bool
     with Import, Convention => C, External_Name => "SDL_GL_SetSwapInterval";

   function SDL_GL_SwapWindow (W : System.Address) return Bool
     with Import, Convention => C, External_Name => "SDL_GL_SwapWindow";

   function SDL_GetTicksNS return Unsigned_64
     with Import, Convention => C, External_Name => "SDL_GetTicksNS";

   ---------------------------------------------------------------------
   --  Events. SDL_Event is a 128-byte union; we read the type, then
   --  overlay the specific struct on the same address.
   ---------------------------------------------------------------------

   Event_Quit               : constant Unsigned_32 := 16#100#;
   Event_Window_Resized     : constant Unsigned_32 := 16#206#;
   Event_Key_Down           : constant Unsigned_32 := 16#300#;
   Event_Key_Up             : constant Unsigned_32 := 16#301#;
   Event_Mouse_Motion       : constant Unsigned_32 := 16#400#;
   Event_Mouse_Button_Down  : constant Unsigned_32 := 16#401#;
   Event_Mouse_Button_Up    : constant Unsigned_32 := 16#402#;

   type Event_Storage is array (1 .. 124) of Unsigned_8;

   type SDL_Event is record
      Event_Type : Unsigned_32;
      Storage    : Event_Storage := [others => 0];
   end record with Convention => C, Size => 128 * 8;

   function SDL_PollEvent (E : access SDL_Event) return Bool
     with Import, Convention => C, External_Name => "SDL_PollEvent";

   type Keyboard_Event is record
      Event_Type : Unsigned_32;
      Reserved   : Unsigned_32;
      Timestamp  : Unsigned_64;
      Window_Id  : Unsigned_32;
      Which      : Unsigned_32;
      Scancode   : Unsigned_32;
      Keycode    : Unsigned_32;
      Modifiers  : Unsigned_16;
      Raw        : Unsigned_16;
      Down       : Bool;
      Is_Repeat  : Bool;
   end record with Convention => C;

   type Mouse_Motion_Event is record
      Event_Type : Unsigned_32;
      Reserved   : Unsigned_32;
      Timestamp  : Unsigned_64;
      Window_Id  : Unsigned_32;
      Which      : Unsigned_32;
      State      : Unsigned_32;
      X, Y       : C.C_float;
      XRel, YRel : C.C_float;
   end record with Convention => C;

   type Mouse_Button_Event is record
      Event_Type : Unsigned_32;
      Reserved   : Unsigned_32;
      Timestamp  : Unsigned_64;
      Window_Id  : Unsigned_32;
      Which      : Unsigned_32;
      Button     : Unsigned_8;
      Down       : Bool;
      Clicks     : Unsigned_8;
      Padding    : Unsigned_8;
      X, Y       : C.C_float;
   end record with Convention => C;

   type Window_Event is record
      Event_Type : Unsigned_32;
      Reserved   : Unsigned_32;
      Timestamp  : Unsigned_64;
      Window_Id  : Unsigned_32;
      Data1      : Integer_32;
      Data2      : Integer_32;
   end record with Convention => C;

   --  Scancodes (SDL_scancode.h): A..Z = 4..29, 1..9 = 30..38, 0 = 39.
   Scan_A         : constant := 4;
   Scan_1         : constant := 30;
   Scan_0         : constant := 39;
   Scan_Return    : constant := 40;
   Scan_Escape    : constant := 41;
   Scan_Backspace : constant := 42;
   Scan_Tab       : constant := 43;
   Scan_Space     : constant := 44;
   Scan_F1        : constant := 58;   --  .. F12 = 69
   Scan_Right     : constant := 79;
   Scan_Left      : constant := 80;
   Scan_Down      : constant := 81;
   Scan_Up        : constant := 82;
   Scan_LCtrl     : constant := 224;
   Scan_LShift    : constant := 225;
   Scan_RCtrl     : constant := 228;
   Scan_RShift    : constant := 229;

end Yarlib.Platform.SDL;
