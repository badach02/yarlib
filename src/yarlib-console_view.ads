--  The on-screen console: a panel over the game where you type
--  commands for Yarlib.Console and read its answers. It keeps the
--  last Max_Lines lines of history and the line being typed.
--
--  Typing comes from Key events, not SDL text input, so --record,
--  --replay and tests (through Core.Inject) can drive it.
--
--  Call Handle_Input once per frame and Draw last in the game's Draw.
--  Register commands with Console.Register, not here.
with Yarlib.Core;

package Yarlib.Console_View is

   Max_Lines : constant := 8;
   Max_Width : constant := 80;

   type Line_Text is record
      Text   : String (1 .. Max_Width) := [others => ' '];
      Length : Natural range 0 .. Max_Width := 0;
   end record;

   type Line_Array is array (0 .. Max_Lines - 1) of Line_Text;
   ----------------------
   -- Ring Data Structure
   ----------------------

   --  Holds all text lines we want to display above the console
   --  Overwrites old lines while keeping the newest ones
   type Ring is record
      Lines : Line_Array;
      Oldest_Slot : Natural range 0 .. Max_Lines := 0;
      Lines_Used : Natural range 0 .. Max_Lines := 0;
   end record;

   --  Returns total amount of lines being used
   function Count (R : Ring) return Natural;

   --  Adds new string to Ring
   procedure Push (R : in out Ring; S : String);

   --  Returns line I counting from the oldest: 1 is the oldest line,
   --  Count (R) is the newest. Asking past Count (R) is a caller bug.
   function Line (R : Ring; I : Positive) return String
     with Pre => I <= Count (R);

   ----------------------
   -- Console Input
   ----------------------

   --  One key press. Letters, digits, space, minus and period type;
   --  Backspace deletes the last character; Return runs the line through
   --  Console.Execute and pushes "> LINE" and the response into History.
   --  Every other key is ignored. Lowercase only: replays do not record
   --  Shift, so the console must not depend on it.
   procedure Handle_Key (K : Key);

   --  The command and response lines, oldest first
   function History return Ring;

   --  The line being typed
   function Input_Text return String;

   ----------------------
   -- Open, Close, Frame Input
   ----------------------

   --  The key that opens and closes the console
   Toggle_Key : constant Key := Key_Grave;

   --  Opens the console when closed, closes it when open
   procedure Toggle;

   --  True while the console is open. The game skips its own controls
   --  then, so typing "spawn" does not also move the ship with S.
   function Is_Open return Boolean;

   --  Walks this frame's key presses in the order they happened:
   --  Toggle_Key toggles, and while open every other key goes to
   --  Handle_Key. Key repeats are skipped because replays drop them;
   --  using them would make --record and --replay disagree.
   --
   --  Call it exactly once per frame. Game_Loop runs Update 0 to 5 times
   --  a frame, so calling it from Update loses keys (0) or handles them
   --  twice (2+). Draw runs once per frame, so call it there.
   procedure Handle_Input (Ctx : Core.Context);
   procedure Handle_Input;   --  on Core.Default

   ----------------------
   -- Drawing
   ----------------------

   --  Draws the panel across the top of the screen when open: History
   --  above, newest line just over the input line. Nothing when closed.
   --  Call it last in the game's Draw so it sits on top of everything.
   procedure Draw (Ctx : in out Core.Context);
   procedure Draw;   --  on Core.Default

end Yarlib.Console_View;