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
     with Pre => k <= Header_Size - 4
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
      OK := Byte_At (Data, 0) = Character'Pos ('q')
            and then Byte_At (Data, 1) = Character'Pos ('o')
            and then Byte_At (Data, 2) = Character'Pos ('i')
            and then Byte_At (Data, 3) = Character'Pos ('f')
        --verifies the first 4 bytes of the header are "qoif"
        and then Image_Width in 1 .. Bedrock.Buffers.Max_Width
        and then Image_Height in 1 .. Bedrock.Buffers.Max_Height
        --verifies the width and height are within the max width and height of the buffer
        and then Channels in 3 .. 4
        and then Colorspace <= 1;
        --verifies the channels and colorspace are valid values

      if OK then
         Width  := Natural (Image_Width);
         Height := Natural (Image_Height);
      else
         Width  := 0;
         Height := 0;
      end if;
   end Read_Header;

   --I need to finish the decode code. will do later...

end Yarlib.QOI;