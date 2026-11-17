--  The game itself: state, Init, Update, Draw, and its console
--  commands. Nothing about windows, files, or arguments; arena.adb
--  does that. This is the split the editor and the tests rely on.

with Bedrock;         use Bedrock;
with Bedrock.Colors;  use Bedrock.Colors;
with Yarlib;       use Yarlib;
with Yarlib.Console;

package Arena_Game is

   W : constant := 800;
   H : constant := 450;

   Ship       : Rectangle;
   Ship_Color : constant Color := Sky_Blue;

   function Block_Count return Natural;

   procedure Init;
   procedure Update (Dt : Scalar);
   procedure Draw (Alpha : Scalar);

   --  Console handlers, registered by Init:
   --    spawn X Y SIZE     add a block
   --    clear              remove all blocks
   --    ship X Y           move the ship
   --    list               blocks and ship
   procedure Cmd_Spawn (Args : String; R : out Console.Response);
   procedure Cmd_Clear (Args : String; R : out Console.Response);
   procedure Cmd_Ship (Args : String; R : out Console.Response);
   procedure Cmd_List (Args : String; R : out Console.Response);

end Arena_Game;
