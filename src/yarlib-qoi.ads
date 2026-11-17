with interfaces;
--
package Yarlib.QOI with 
  SPARK_Mode
is 
   type Byte_Array is array (Positive range <>) of Interfaces.Unsigned_8;
      Header_Size : constant := 14; --header is 14 bytes long. 


  --Read_Header will take in the byte array for the QOI file
  --returning OK if it was successful through comparison aswell as the width and height of the image.
   procedure Read_Header
     (Data : Byte_Array; Width, Height : out Natural; Ok : out Boolean)
     with Pre => Data'Length >= Header_Size; --initial header size for QOI file is 14 bytes, 
     --so if it is less than that, it is not a valid QOI file.

 --Decode will take in the byte array for the QOI file
 --returning OK if it was successful through comparison aswell as the decoded image as a Bitmap.
   procedure Decode (Data : Byte_Array; Img : out Bitmap; Ok : out Boolean)
     with Pre => Data'Length >= Header_Size;
   

end Yarlib.QOI;