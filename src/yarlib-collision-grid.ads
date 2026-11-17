--  Broad-phase collision over a bounded uniform grid. Rectangles and IDs
--  belong to the caller; the grid stores only Positive array indices.
--  Clear before rebuilding a moving scene. Insert covers every overlapping
--  cell; Query returns unique candidates, which still need an exact check.
--
--  Coverage invariant: a successful insertion is present in every cell its
--  rectangle overlaps. Failure leaves the grid unchanged. Thus a successful
--  query cannot miss an inserted rectangle that truly overlaps its argument.
--  Touching cell edges may add false positives, which is safe for broad phase.
--
--  Bounds are inclusive, from Origin to Origin + cell count * Cell_Size.
--  Out-of-bounds/invalid rectangles and IDs above Max_Id report Ok = False.
--  Empty rectangles insert/query nothing. Full cells reject the whole insert;
--  a full result buffer returns its unique prefix with Ok = False. No heap,
--  access types, exceptions for overflow, or hidden loss of candidates.

with Bedrock; use Bedrock;

generic
   Origin_X, Origin_Y : Scalar;
   Columns, Rows     : Positive;
   Cell_Size         : Positive;
   Max_Per_Cell      : Positive;
   Max_Id            : Positive;
package Yarlib.Collision.Grid with SPARK_Mode is

   type Grid is limited private;
   type Id_List is array (Positive range <>) of Positive;

   procedure Clear (G : in out Grid);
   --  Remove every entry; the grid is ready for another frame.

   procedure Insert (G : in out Grid; Id : Positive; R : Rectangle; Ok : out Boolean);
   --  Insert into all covered cells, or leave G unchanged and return False.
   --  Repeated IDs are allowed; movement requires Clear and a fresh rebuild.

   procedure Query
     (G : Grid; R : Rectangle; Result : out Id_List; Count : out Natural; Ok : out Boolean)
   with Post => Count <= Result'Length;
   --  The first Count elements of Result contain unique IDs.
   --  Ok is True only when bounds are valid and the whole answer fits.

private
   subtype Cell_Count is Natural range 0 .. Max_Per_Cell;
   subtype Id_Index is Positive range 1 .. Max_Id;
   subtype Column_Index is Natural range 0 .. Columns - 1;
   subtype Row_Index is Natural range 0 .. Rows - 1;
   type Counts is array (Column_Index, Row_Index) of Cell_Count;
   type Entries is array (Column_Index, Row_Index, Positive range 1 .. Max_Per_Cell)
     of Id_Index;
   type Grid is limited record
      Used : Counts := [others => [others => 0]];
      Ids  : Entries := [others => [others => [others => 1]]];
   end record;
end Yarlib.Collision.Grid;
