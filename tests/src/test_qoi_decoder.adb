with Ada.Directories;
with Ada.Streams.Stream_IO; use Ada.Streams.Stream_IO;
with Ada.Text_IO;
with Bedrock.Buffers;       use Bedrock.Buffers;
with Bedrock.Colors;        use Bedrock.Colors;
with Yarlib;                use Yarlib;
with Yarlib.PNG;
with Yarlib.QOI;            use Yarlib.QOI;

package body Test_QOI_Decoder is

   Image_File : constant String := "my_image.qoi";
   --  Your image, in the tests folder. Saved as decoded.png next to it.

   --  The fall plan's two fixtures, made by the reference encoder.
   Checker_4x4 : constant Byte_Array :=   --  white at (0, 0), then black
     [16#71#, 16#6F#, 16#69#, 16#66#, 0, 0, 0, 4, 0, 0, 0, 4, 4, 0,
      16#55#, 16#7F#, 16#26#, 16#35#, 16#35#, 16#26#, 16#35#, 16#26#,
      16#26#, 16#35#, 16#26#, 16#35#, 16#35#, 16#26#, 16#35#, 16#26#,
      0, 0, 0, 0, 0, 0, 0, 1];
   Solid_8x8 : constant Byte_Array :=     --  Red everywhere
     [16#71#, 16#6F#, 16#69#, 16#66#, 0, 0, 0, 8, 0, 0, 0, 8, 4, 0,
      16#FE#, 16#E6#, 16#29#, 16#37#, 16#FD#, 16#C0#,
      0, 0, 0, 0, 0, 0, 0, 1];

   Failed : Natural := 0;

   procedure Check (Name : String; Cond : Boolean);
   procedure Check (Name : String; Cond : Boolean) is
   begin
      Ada.Text_IO.Put_Line ((if Cond then "PASS  " else "FAIL  ") & Name);
      if not Cond then
         Failed := Failed + 1;
      end if;
   end Check;

   procedure Run (Failures : in out Natural) is
      Ok : Boolean;
   begin
      Failed := 0;
      declare
         Img : Bitmap := Make (4, 4);
      begin
         Decode (Checker_4x4, Img, Ok);
         Check ("qoi: checkerboard", Ok and then
           (for all Y in 0 .. 3 =>
              (for all X in 0 .. 3 =>
                 Same_RGB (Get (Img, X, Y),
                           (if (X + Y) mod 2 = 0 then White else Black)))));
      end;

      declare
         Img : Bitmap := Make (8, 8);
      begin
         Decode (Solid_8x8, Img, Ok);
         Check ("qoi: solid 8x8", Ok and then
           (for all Y in 0 .. 7 =>
              (for all X in 0 .. 7 => Same_RGB (Get (Img, X, Y), Red))));
      end;

      declare
         File : File_Type;
         Data : Byte_Array (1 .. Natural (Ada.Directories.Size (Image_File)));
         W, H : Natural;
      begin
         Open (File, In_File, Image_File);
         Byte_Array'Read (Stream (File), Data);
         Close (File);

         Read_Header (Data, W, H, Ok);
         declare
            Img : Bitmap := Make (Natural'Max (W, 1), Natural'Max (H, 1));
         begin
            Decode (Data, Img, Ok);
            Check ("qoi: " & Image_File & " decodes", Ok);
            Yarlib.PNG.Save (Img, "decoded.png", Ok);
            Check ("qoi: saved as tests/decoded.png", Ok);
         end;
      end;

      Failures := Failures + Failed;
   end Run;

end Test_QOI_Decoder;