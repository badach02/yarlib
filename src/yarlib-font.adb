with Bedrock.Buffers;

package body Yarlib.Font with
   SPARK_Mode
is
   function Build_Atlas return Bitmap is
      Img : Bitmap :=
        Bedrock.Buffers.Make (16 * Glyph_Width, 8 * Glyph_Height);
   begin
      for C in Bits'Range loop
         declare
            --  ' ' is character 32, so to start at 0 we subtract 32
            Index  : constant Natural := Character'Pos (C) - 32;
            Cell_X : constant Natural := (Index mod 16) * Glyph_Width;
            Cell_Y : constant Natural := (Index / 16) * Glyph_Height;
         begin
            for Y in Glyph_Rows'Range loop
               for X in 0 .. Glyph_Width - 1 loop
                  --  Bit X of a row is column X of the glyph
                  --  We use a mask to check if that pixel should be drawn here
                  if (Bits (C) (Y) and 2 ** X) /= 0 then
                     Bedrock.Buffers.Set (Img, Cell_X + X, Cell_Y + Y, White);
                  end if;
               end loop;
            end loop;
         end;
      end loop;
      return Img;
   end Build_Atlas;

   function Source (C : Character) return Rectangle is
      --  / gives us the row and mod gives us the column
      Index : constant Natural := Character'Pos (C) - 32;
   begin
      return
        (Scalar ((Index mod 16) * Glyph_Width),
         Scalar ((Index / 16) * Glyph_Height),
         Scalar (Glyph_Width), Scalar (Glyph_Height));
   end Source;
end Yarlib.Font;
