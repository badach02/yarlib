with Ada.Numerics.Elementary_Functions;
with Bedrock.Buffers;
with Yarlib.Batch;
with Yarlib.Renderer;
with Yarlib.QOI;
with Ada.Directories;
with Ada.Streams.Stream_IO;

package body Yarlib.Textures is

   function Load_Texture(Img : Bitmap) return Texture is
      T  : Texture;
      Ok : Boolean;
   begin
      Renderer.Create_Texture (Img, T, Ok);
      if not Ok then
         raise Program_Error with "yarlib: texture table full";
      end if;
      return T;
   end Load_Texture;

   function Load_Texture (File_Path : String) return Texture is
      use Yarlib.QOI;
      --  places the qoi file into a byte array. 
      function Read_File return Byte_Array is
         use Ada.Streams.Stream_IO;
         F : File_Type;
      begin
         Open (F, In_File, File_Path);
         declare
            Data : Byte_Array (1 .. Natural (Size (F)));
         begin
            Byte_Array'Read (Stream (F), Data);
            Close (F);
            return Data;
         end;
      exception
         when Name_Error =>
            raise Program_Error with "yarlib: no such file " & File_Path;
      end Read_File;
      --now declare the variables to hold the data and the width and height of the image
      Data          : constant Byte_Array := Read_File;
      Width, Height : Natural := 0;
      Ok            : Boolean := False;
   begin
      --read header and get the width and height of the image
      if Data'Length >= Header_Size then
         Read_Header (Data, Width, Height, Ok);
      end if;
      if not Ok then
         raise Program_Error with "yarlib: bad QOI header in " & File_Path;
      end if;

      -- make a bitmap for the image
      declare
         Img : Bitmap := Bedrock.Buffers.Make (Width, Height);
      begin
         Decode (Data, Img, Ok);
         if not Ok then
            raise Program_Error with "yarlib: bad QOI data in " & File_Path;
         end if;

         --  3. Upload it to the GPU.
         return Load_Texture (Img);
      end;
   end Load_Texture;

   function Checkerboard
     (Width, Height, Cell : Positive; A, B : Color) return Texture
   is
      Img : Bitmap := Bedrock.Buffers.Make (Width, Height);
   begin
      for Y in 0 .. Height - 1 loop
         for X in 0 .. Width - 1 loop
            Bedrock.Buffers.Set
              (Img, X, Y,
               (if ((X / Cell) + (Y / Cell)) mod 2 = 0 then A else B));
         end loop;
      end loop;
      return Load_Texture (Img);
   end Checkerboard;

   procedure Draw_Texture
     (Ctx : in out Context; T : Texture; X, Y : Integer; Tint : Color := White)
   is
   begin
      Draw_Texture_Pro
        (Ctx, T, Source => (0.0, 0.0, Scalar (T.Width), Scalar (T.Height)),
         Dest => (Scalar (X), Scalar (Y), Scalar (T.Width), Scalar (T.Height)),
         Origin         => (0.0, 0.0), Rotation => 0.0, Tint => Tint);
   end Draw_Texture;

   procedure Draw_Texture_Pro
     (Ctx    : in out Context; T : Texture; Source, Dest : Rectangle;
      Origin :        Vector2; Rotation : Degrees; Tint : Color := White)
   is
      use Ada.Numerics.Elementary_Functions;
      Rad : constant Float  := Float (Rotation) * Ada.Numerics.Pi / 180.0;
      Cs  : constant Scalar := Scalar (Cos (Rad));
      Sn  : constant Scalar := Scalar (Sin (Rad));
      function Rot (LX, LY : Scalar) return Vector2 is
        ((Dest.X + LX * Cs - LY * Sn, Dest.Y + LX * Sn + LY * Cs));
      P  : constant Batch.Quad_Corners :=
        [Rot (-Origin.X, -Origin.Y), Rot (Dest.Width - Origin.X, -Origin.Y),
        Rot (Dest.Width - Origin.X, Dest.Height - Origin.Y),
        Rot (-Origin.X, Dest.Height - Origin.Y)];
      TW : constant Scalar             := Scalar (T.Width);
      TH : constant Scalar             := Scalar (T.Height);
      U0 : constant Scalar             := Source.X / TW;
      V0 : constant Scalar             := Source.Y / TH;
      U1 : constant Scalar             := (Source.X + Source.Width) / TW;
      V1 : constant Scalar             := (Source.Y + Source.Height) / TH;
      UV : constant Batch.Quad_Corners :=
        [(U0, V0), (U1, V0), (U1, V1), (U0, V1)];
   begin
      Submit (Ctx, T.Id, P, UV, Tint);
   end Draw_Texture_Pro;

   procedure Draw_Texture (T : Texture; X, Y : Integer; Tint : Color := White)
   is
   begin
      Draw_Texture (Default.all, T, X, Y, Tint);
   end Draw_Texture;

   procedure Draw_Texture_Pro
     (T        : Texture; Source, Dest : Rectangle; Origin : Vector2;
      Rotation : Degrees; Tint : Color := White)
   is
   begin
      Draw_Texture_Pro (Default.all, T, Source, Dest, Origin, Rotation, Tint);
   end Draw_Texture_Pro;

end Yarlib.Textures;
