--  Draws text using the 8x8 font defined in Yarlib.Font
--  A whole string is one draw call because every glyph is on one atlas
--  The atlas is uploaded on first use of Draw_Text

with Bedrock;     use Bedrock;
with Yarlib.Core; use Yarlib.Core;

package Yarlib.Text is

   --  X Y is from top left corner and Size is the texts height in pixels
   procedure Draw_Text (Ctx : in out Context; Text : String; X, Y, Size : Integer;  C : Color);
   procedure Draw_Text (Text: String; X, Y, Size : Integer; C : Color);

   --  Returns the width of given text in pixels
   function Measure_Text (Text : String; Size : Integer) return Integer;

end Yarlib.Text;