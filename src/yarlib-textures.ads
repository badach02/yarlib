--  Textures: images on the GPU and how to draw them. raylib's rtextures.
--  Loading from a file is milestone 3 (a QOI decoder into a Bedrock
--  Image); the seed loads from an Image and offers Checkerboard so the
--  showcase has something to draw. Textures belong to the GPU, not to a Context, and
--  die at Close_Window; there is no Unload to forget.

with Bedrock;     use Bedrock;
with Yarlib.Core; use Yarlib.Core;

package Yarlib.Textures is

   function Load_Texture (Img : Bitmap) return Texture;
   --  Raises Program_Error when the texture table is full.

   function Load_Texture (File_path : String) return Texture;
   --  Raises Program_Error when the texture table is full.
   --  File is a path to an image file (BMP, PNG, TGA, JPG, GIF, PSD, HDR, PIC or PNM).

   function Checkerboard
     (Width, Height, Cell : Positive; A, B : Color) return Texture;

   procedure Draw_Texture
     (Ctx  : in out Context; T : Texture; X, Y : Integer;
      Tint :        Color := White);

   procedure Draw_Texture_Pro
     (Ctx    : in out Context; T : Texture; Source, Dest : Rectangle;
      Origin :        Vector2; Rotation : Degrees; Tint : Color := White);
   --  Source in texels; Dest on screen (or world, inside Begin_Mode_2D);
   --  Rotation about Dest position + Origin. Sprite sheets are Source.

   procedure Draw_Texture (T : Texture; X, Y : Integer; Tint : Color := White);
   procedure Draw_Texture_Pro
     (T        : Texture; Source, Dest : Rectangle; Origin : Vector2;
      Rotation : Degrees; Tint : Color := White);

end Yarlib.Textures;
