--  The game itself: state, Init, Update, Draw, and its console
--  commands. Window setup and command-line handling live in arena.adb.

with Bedrock;         use Bedrock;
with Yarlib;       use Yarlib;
with Yarlib.Console;

package Arena_Game is

   W : constant := 800;
   H : constant := 450;

   Ship : Rectangle;

   function Block_Count return Natural;
   function Stress_Active return Boolean;

   procedure Init (Asset_Directory : String := "assets/space");
   procedure Update (Dt : Scalar);
   procedure Draw (Alpha : Scalar);

   --  Console handlers, registered by Init:
   --    spawn X Y SIZE     add a block
   --    clear              remove all blocks
   --    ship X Y           move the ship
   --    list               blocks and ship
   --    stress 2000        replace the blocks with a grid collision workload
   --    stress stats       report measured frame times
   procedure Cmd_Spawn (Args : String; R : out Console.Response);
   procedure Cmd_Clear (Args : String; R : out Console.Response);
   procedure Cmd_Ship (Args : String; R : out Console.Response);
   procedure Cmd_List (Args : String; R : out Console.Response);

end Arena_Game;
