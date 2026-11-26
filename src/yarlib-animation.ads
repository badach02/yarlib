--  Sprite-sheet animation: which frame of a sheet to show, worked out
--  from a clock the game owns. Pure arithmetic, no state in the
--  package: the game keeps one Animation value per animated sprite.
--
--  Call Advance from Update (fixed Dt, so --replay shows the same
--  frames) and pass Source to Draw_Texture_Pro in Draw.

with Bedrock; use Bedrock;

package Yarlib.Animation with
   SPARK_Mode
is

   --  Holds everything needed to animate a sprite sheet
   type Animation is record
      --  The sheet: set once when the game creates it. Frames are
      --  numbered left to right, top to bottom, starting at 0.
      Frame_Width       : Positive;   --  one frame, in pixels
      Frame_Height      : Positive;
      Columns           : Positive;   --  frames per row of the sheet
      Frame_Count       : Positive;   --  frames in use, may leave cells empty
      Frames_Per_Second : Scalar;
      Looping           : Boolean;

      --  The clock: seconds played so far, changed only by Advance
      Time : Scalar := 0.0;
   end record;

   --  Limits that let the prover show no arithmetic can overflow. They
   --  are far outside anything a game needs. The longest cycle is
   --  Max_Frames / Min_Frames_Per_Second = 80_000 s, under Max_Time, so
   --  a clock kept inside one cycle stays inside Max_Time.
   Max_Frames            : constant := 10_000;
   Min_Frames_Per_Second : constant := 0.125;   --  1/8, exact as a float
   Max_Frames_Per_Second : constant := 1_000.0;
   Max_Time              : constant := 86_400.0;   --  seconds, one day
   Max_Dt                : constant := 1.0;

   --  The sheet's numbers are in range and the clock is inside
   --  0 .. Max_Time. Every operation requires it, and Advance keeps it
   --  true, so a game can call Advance forever.
   function Valid (A : Animation) return Boolean is
     (A.Frame_Count <= Max_Frames
      and then A.Frames_Per_Second in Min_Frames_Per_Second .. Max_Frames_Per_Second
      and then A.Time in 0.0 .. Max_Time);

   --  Moves the clock forward by Dt seconds. Call it from the game's
   --  Update, which runs at a fixed Dt, so --replay shows the same
   --  frames. After the last frame: Looping wraps back to frame 0,
   --  otherwise the animation stays on the last frame.
   procedure Advance (A : in out Animation; Dt : Scalar) with
     Pre  => Valid (A) and then Dt in 0.0 .. Max_Dt,
     Post => Valid (A);

   --  The current frame's rectangle on the sheet, in pixels: pass it as
   --  Source to Draw_Texture_Pro. Only reads A, so call it from Draw.
   function Source (A : Animation) return Rectangle with
     Pre => Valid (A);

   --  True once a non-looping animation has played its last frame, so
   --  the game can stop drawing it. A looping animation never finishes.
   function Is_Finished (A : Animation) return Boolean with
     Pre => Valid (A);

end Yarlib.Animation;
