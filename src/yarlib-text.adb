with Yarlib.Font;
with Yarlib.Textures; use Yarlib.Textures;

package body Yarlib.Text is

   Atlas  : Texture;
   Loaded : Boolean := False;
   --  The font atlas, uploaded on the first Draw_Text.

   procedure Draw_Text (Ctx : in out Context; Text : String; X, Y, Size : Integer;  C : Color) is
      Scale   : constant Scalar :=
        Scalar (Size) / Scalar (Font.Glyph_Height);
      Advance : constant Scalar := Scalar (Font.Glyph_Width) * Scale;
      Pen_X   : Scalar          := Scalar (X);
   begin
      if not Loaded then
         Atlas  := Load_Texture (Font.Build_Atlas);
         Loaded := True;
      end if;
      for Ch of Text loop
         Draw_Texture_Pro
           (Ctx, Atlas, Source => Font.Source (Ch),
            Dest     => (Pen_X, Scalar (Y), Advance, Scalar (Size)),
            Origin   => (0.0, 0.0), Rotation => 0.0, Tint => C);
         Pen_X := Pen_X + Advance;
      end loop;
   end Draw_Text;

   procedure Draw_Text (Text : String; X, Y, Size : Integer; C : Color) is
   begin
      Draw_Text (Default.all, Text, X, Y, Size, C);
   end Draw_Text;

   function Measure_Text (Text : String; Size : Integer) return Integer is
   begin
      return Text'Length * Font.Glyph_Width * Size / Font.Glyph_Height;
   end Measure_Text;

end Yarlib.Text;