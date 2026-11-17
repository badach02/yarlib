package body Yarlib.Collision.Grid with SPARK_Mode is

   Right : constant Long_Float :=
     Long_Float (Origin_X) + Long_Float (Columns) * Long_Float (Cell_Size);
   Bottom : constant Long_Float :=
     Long_Float (Origin_Y) + Long_Float (Rows) * Long_Float (Cell_Size);

   function In_Bounds (R : Rectangle) return Boolean is
     (Valid_Rectangle (R) and then R.X >= Origin_X and then R.Y >= Origin_Y
      and then Long_Float (R.X + R.Width) <= Right
      and then Long_Float (R.Y + R.Height) <= Bottom);

   function Cell_At (Point, Origin : Scalar; Last : Natural) return Natural is
     (Natural
        (Long_Float'Min
           (Long_Float (Last),
            Long_Float'Floor ((Long_Float (Point) - Long_Float (Origin)) /
                              Long_Float (Cell_Size)))))
   with Pre => Point >= Origin, Post => Cell_At'Result <= Last;

   function Column (X : Scalar) return Column_Index is (Cell_At (X, Origin_X, Columns - 1))
   with Pre => X >= Origin_X;

   function Row (Y : Scalar) return Row_Index is (Cell_At (Y, Origin_Y, Rows - 1))
   with Pre => Y >= Origin_Y;

   procedure Clear (G : in out Grid) is
   begin
      G.Used := [others => [others => 0]];
   end Clear;

   procedure Insert (G : in out Grid; Id : Positive; R : Rectangle; Ok : out Boolean) is
   begin
      Ok := False;
      if Id > Max_Id or else not In_Bounds (R) then
         return;
      end if;
      if R.Width > 0.0 and then R.Height > 0.0 then
         --  Check all cells before writing any: overflow is atomic.
         for X in Column (R.X) .. Column (R.X + R.Width) loop
            for Y in Row (R.Y) .. Row (R.Y + R.Height) loop
               if G.Used (X, Y) = Max_Per_Cell then
                  return;
               end if;
            end loop;
         end loop;
         for X in Column (R.X) .. Column (R.X + R.Width) loop
            for Y in Row (R.Y) .. Row (R.Y + R.Height) loop
               G.Used (X, Y) := G.Used (X, Y) + 1;
               G.Ids (X, Y, G.Used (X, Y)) := Id;
            end loop;
         end loop;
      end if;
      Ok := True;
   end Insert;

   procedure Query
     (G : Grid; R : Rectangle; Result : out Id_List; Count : out Natural; Ok : out Boolean)
   is
      Seen : array (Id_Index) of Boolean := [others => False];
   begin
      Result := [others => 1];
      Count := 0;
      Ok := False;
      if not In_Bounds (R) then
         return;
      end if;
      if R.Width > 0.0 and then R.Height > 0.0 then
         for X in Column (R.X) .. Column (R.X + R.Width) loop
            for Y in Row (R.Y) .. Row (R.Y + R.Height) loop
               for I in 1 .. G.Used (X, Y) loop
                  declare
                     Id : constant Id_Index := G.Ids (X, Y, I);
                  begin
                     if not Seen (Id) then
                        if Count = Result'Length then
                           return;
                        end if;
                        Result (Result'First + Count) := Id;
                        Count := Count + 1;
                        Seen (Id) := True;
                     end if;
                  end;
               end loop;
            end loop;
         end loop;
      end if;
      Ok := True;
   end Query;
end Yarlib.Collision.Grid;
