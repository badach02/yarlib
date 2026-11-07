with Bedrock.Buffers;

package body Yarlib.QOI with
  SPARK_Mode
is
   use Interfaces;

   QOI_OP_RGB  : constant Unsigned_8 := 254;  --  binary 11111110
   QOI_OP_RGBA : constant Unsigned_8 := 255;  --  binary 11111111

   subtype Cache_Slot is Unsigned_8 range 0 .. 63; -- 6 bits for cache index, 2 bits for type
   type Color_Cache is array (Cache_Slot) of Color; -- 64 color cache for the last 64 colors seen



   -- HELPER FUNCTIONS----------------------------------------------------------------------------------
   function Byte_At(Data : Byte_Array; k : Natural) return Unsigned_8
     with Pre => k < Data'Length
   is
   begin
      return Data (Data'First + k);
   end Byte_At;
               -- gets the byte at the index K of the byte array

    function Read_Be32(Data : Byte_Array; k : Natural) return Unsigned_32
      with Pre => k <= Data'Length - 4
   is
      B0 : constant Unsigned_32 := Unsigned_32 (Byte_At (Data, k));  --msb
      B1 : constant Unsigned_32 := Unsigned_32 (Byte_At (Data, k + 1));
      B2 : constant Unsigned_32 := Unsigned_32 (Byte_At (Data, k + 2));
      B3 : constant Unsigned_32 := Unsigned_32 (Byte_At (Data, k + 3)); --lsb
   begin
      return B0 * 256 ** 3 + B1 * 256 ** 2 + B2 * 256 + B3;
   end Read_Be32;
                  -- returns the 32 bit unsigned integer at the index K of the byte array

   function Color_Hash (C : Color) return Cache_Slot is
      Sum : constant Channel := C.R * 3 + C.G * 5 + C.B * 7 + C.A * 11; --function from spec
   begin
      return Cache_Slot (Sum mod 64);
   end Color_Hash;
   -- takes in a color and returns the index of the cache slot it should be stored in



   procedure Read_Header
     (Data : Byte_Array; Width, Height : out Natural; Ok : out Boolean)
   is
      Image_Width        : constant Unsigned_32 := Read_Be32 (Data, 4);
      Image_Height       : constant Unsigned_32 := Read_Be32 (Data, 8);
      Channels           : constant Unsigned_8  := Byte_At (Data, 12); -- 3 = RGB, 4 = RGBA
      Colorspace         : constant Unsigned_8  := Byte_At (Data, 13); -- 0 = sRGB with linear alpha
                                                                  -- 1 = all channels linear
   begin
      Ok := Byte_At (Data, 0) = Character'pos('q')
            and then Byte_At (Data, 1) = Character'pos('o')
            and then Byte_At (Data, 2) = Character'pos('i')
            and then Byte_At (Data, 3) = Character'pos('f')
        --verifies the first 4 bytes of the header are "qoif"
        and then Image_Width in 1 .. Bedrock.Buffers.Max_Width
        and then Image_Height in 1 .. Bedrock.Buffers.Max_Height
        --verifies the width and height are within the max width and height of the buffer
        and then Channels in 3 .. 4
        and then Colorspace <= 1;
        --verifies the channels and colorspace are valid values

      if Ok then
         Width  := Natural (Image_Width);
         Height := Natural (Image_Height);
      else
         Width  := 0;
         Height := 0;
      end if;
   end Read_Header;

   --I need to finish the decode code. will do later...


   procedure Decode (Data : Byte_Array; Img : out Bitmap; Ok : out Boolean) is
      Width : constant Positive := Natural (Img.Width) + 1;
      Height : constant Positive := Natural (Img.Height) + 1;
      --  get the size of the bitmap we are writing into, adding 1 to account for the 0 index

      File_Width, File_Height : Natural;
      Header_Valid : Boolean;
      Cache : Color_Cache := [others => Transparent]; --  initialize the color cache to all transparent colors
      
      Pixel : Color := (R => 0, G => 0, B => 0, A => 255); --  current pixel color
      Byte_Ptr: Natural := Header_Size; --current position in the byte array, starting after the header
      X, Y : Natural := 0;  --  where the next pixel will be written 

      procedure Put_Pixel
         with Pre  => X < Width and then Y < Height
         and then Width = Natural (Img.Width) + 1
         and then Height = Natural (Img.Height) + 1,
            Post => X < Width and then Y <= Height
      is
      begin
         Bedrock.Buffers.Set (Img, X, Y, Pixel); --write the pixel

         --  check if we are at the end of the row
         if X = Width - 1 then
            X := 0;
            Y := Y + 1;
         else
            X := X + 1;
         end if;
      end Put_Pixel;

   begin
      Img.Data := [others => [others => Transparent]];
      Ok := False;

      --  The header must be valid and match the Bitmap's size.
      Read_Header (Data, File_Width, File_Height, Header_Valid);
      
      if (not Header_Valid)
         or else (File_Width /= Width)
         or else (File_Height /= Height) 
      then
         return;
      end if;

      while (Y < Height) loop
         pragma Loop_Invariant (X < Width and then Byte_Ptr<= Data'Length); 
         -- for SPARK, these things must always be true

         if Byte_Ptr= Data'Length then
            return;  --  The qoi file ended before the image was full. nothing left to read
         end if;

         declare
            Chunk_Tag   : constant Unsigned_8 := Byte_At (Data, Byte_Ptr);
            Run_Count : Positive := 1; --how many times to repeat the pixel, default is 1 for no run
         begin
            Byte_Ptr:= Byte_Ptr+ 1;

            if Chunk_Tag = QOI_OP_RGB then
               if Data'Length - Byte_Ptr< 3 then
                  return;
               end if;
               Pixel.R := Channel (Byte_At (Data, Byte_Ptr));
               Pixel.G := Channel (Byte_At (Data, Byte_Ptr+ 1));
               Pixel.B := Channel (Byte_At (Data, Byte_Ptr+ 2));
               Byte_Ptr:= Byte_Ptr+ 3;

            elsif Chunk_Tag = QOI_OP_RGBA then
               if Data'Length - Byte_Ptr< 4 then
                  return;
               end if;
               Pixel.R := Channel (Byte_At (Data, Byte_Ptr));
               Pixel.G := Channel (Byte_At (Data, Byte_Ptr+ 1));
               Pixel.B := Channel (Byte_At (Data, Byte_Ptr+ 2));
               Pixel.A := Channel (Byte_At (Data, Byte_Ptr+ 3));
               Byte_Ptr:= Byte_Ptr+ 4;
            -- above 2 cases check if the next pixel is rgb or rgba then reads the data

            else
               -- The top 2 bits of the tag say which chunk it is.
               case Chunk_Tag / 64 is
                  when 0 =>
                     -- QOI_OP_INDEX: use the color from the color cache.
                     Pixel := Cache (Chunk_Tag mod 64);

                  when 1 =>
                     --  QOI_OP_DIFF: use the previous pixel and add the difference to it (small change)
                     Pixel.R := Pixel.R + Channel ((Chunk_Tag / 16) mod 4) - 2;
                     Pixel.G := Pixel.G + Channel ((Chunk_Tag / 4) mod 4) - 2;
                     Pixel.B := Pixel.B + Channel (Chunk_Tag mod 4) - 2;

                  when 2 =>
                     --  QOI_OP_LUMA: use the previous pixel and add the difference to it (large change)
                     --  Luma is 2 bytes.
                     if Byte_Ptr = Data'Length then
                        return;
                     end if;
                     declare
                        Second_Byte  : constant Unsigned_8 := Byte_At (Data, Byte_Ptr);
                        Green_Difference : constant Channel := Channel (Chunk_Tag mod 64) - 32;
                        --  green difference is stored in the first byte
                        Red_Extra        : constant Channel := Channel (Second_Byte / 16) - 8;
                        Blue_Extra       : constant Channel := Channel (Second_Byte mod 16) - 8;
                        --  red and blue extra are stored in the second byte
                     begin
                        Byte_Ptr := Byte_Ptr + 1; -- move ptr because of second byte read
                        Pixel.G := Pixel.G + Green_Difference;
                        Pixel.R := Pixel.R + Green_Difference + Red_Extra;
                        Pixel.B := Pixel.B + Green_Difference + Blue_Extra;
                     end;

                  when others =>
                     --  QOI_OP_RUN: repeat the previous pixel 1 .. 62 times
                     Run_Count := Natural (Chunk_Tag mod 64) + 1;
               end case;
            end if;
         Cache (Color_Hash (Pixel)) := Pixel;
                     for I in 1 .. Run_Count loop
            pragma Loop_Invariant (X < Width and then Y < Height);
            Put_Pixel;
            exit when Y = Height;  --  Never write past the last pixel.
         end loop;
      end;
   end loop;
      --  final check to give OK
      Ok := Data'Length - Byte_Ptr >= 8
        and then (for all I in 0 .. 6 => Byte_At (Data, Byte_Ptr + I) = 0)
        and then Byte_At (Data, Byte_Ptr + 7) = 1;
   end Decode;

end Yarlib.QOI;