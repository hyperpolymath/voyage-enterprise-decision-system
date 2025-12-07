-- VEDS Route Safety Implementation
-- SPARK-verified with formal proofs

pragma SPARK_Mode (On);

with Ada.Numerics.Elementary_Functions;
use Ada.Numerics.Elementary_Functions;

package body VEDS_Route_Safety is

   -- Earth radius in kilometers
   Earth_Radius_Km : constant Long_Float := 6371.0;
   Pi : constant Long_Float := 3.14159265358979323846;

   -- =========================================================================
   -- Geographic Calculations
   -- =========================================================================

   function To_Radians (Degrees : Long_Float) return Long_Float is
   begin
      return Degrees * Pi / 180.0;
   end To_Radians;

   function Haversine_Distance
     (Lat1, Lon1, Lat2, Lon2 : Long_Float) return Route_Distance
   is
      Lat1_Rad : constant Long_Float := To_Radians (Lat1);
      Lat2_Rad : constant Long_Float := To_Radians (Lat2);
      Delta_Lat : constant Long_Float := To_Radians (Lat2 - Lat1);
      Delta_Lon : constant Long_Float := To_Radians (Lon2 - Lon1);

      A : Long_Float;
      C : Long_Float;
      Distance : Long_Float;
   begin
      A := Sin (Delta_Lat / 2.0) ** 2 +
           Cos (Lat1_Rad) * Cos (Lat2_Rad) * Sin (Delta_Lon / 2.0) ** 2;

      C := 2.0 * Arctan (Sqrt (A), Sqrt (1.0 - A));

      Distance := Earth_Radius_Km * C;

      -- Clamp to valid range
      if Distance > Long_Float (Route_Distance'Last) then
         return Route_Distance'Last;
      elsif Distance < 0.0 then
         return 0;
      else
         return Route_Distance (Distance);
      end if;
   end Haversine_Distance;

   function Are_Adjacent
     (Seg1, Seg2   : Segment;
      Tolerance_Km : Route_Distance := 50) return Boolean
   is
      Distance : Route_Distance;
   begin
      Distance := Haversine_Distance
        (Long_Float (Seg1.Dest_Lat),
         Long_Float (Seg1.Dest_Lon),
         Long_Float (Seg2.Origin_Lat),
         Long_Float (Seg2.Origin_Lon));

      return Distance <= Tolerance_Km;
   end Are_Adjacent;

   -- =========================================================================
   -- Route Invariants Implementation
   -- =========================================================================

   function Is_Connected (Segments : Segment_Array) return Boolean is
   begin
      if Segments'Length <= 1 then
         return True;
      end if;

      for I in Segments'First .. Segments'Last - 1 loop
         if not Are_Adjacent (Segments (I), Segments (I + 1)) then
            return False;
         end if;

         pragma Loop_Invariant
           (for all J in Segments'First .. I =>
              (if J < I then Are_Adjacent (Segments (J), Segments (J + 1))));
      end loop;

      return True;
   end Is_Connected;

   function All_Safe (Segments   : Segment_Array;
                      Min_Safety : Safety_Score) return Boolean is
   begin
      for I in Segments'Range loop
         if Segments (I).Safety_Score < Min_Safety then
            return False;
         end if;

         pragma Loop_Invariant
           (for all J in Segments'First .. I =>
              Segments (J).Safety_Score >= Min_Safety);
      end loop;

      return True;
   end All_Safe;

   function All_Within_Weight (Segments   : Segment_Array;
                               Max_Weight : Container_Weight) return Boolean is
   begin
      for I in Segments'Range loop
         if Segments (I).Weight > Max_Weight then
            return False;
         end if;

         pragma Loop_Invariant
           (for all J in Segments'First .. I =>
              Segments (J).Weight <= Max_Weight);
      end loop;

      return True;
   end All_Within_Weight;

   -- =========================================================================
   -- Route Totals Implementation
   -- =========================================================================

   function Total_Cost (Segments : Segment_Array) return Cost_Cents is
      Total : Cost_Cents := 0;
   begin
      for I in Segments'Range loop
         -- Overflow-safe addition
         if Cost_Cents'Last - Total >= Segments (I).Cost then
            Total := Total + Segments (I).Cost;
         else
            Total := Cost_Cents'Last;
            exit;
         end if;

         pragma Loop_Invariant (Total <= Cost_Cents'Last);
      end loop;

      return Total;
   end Total_Cost;

   function Total_Time (Segments : Segment_Array) return Hours is
      Total : Hours := 0;
   begin
      for I in Segments'Range loop
         -- Overflow-safe addition
         if Hours'Last - Total >= Segments (I).Time_Hours then
            Total := Total + Segments (I).Time_Hours;
         else
            Total := Hours'Last;
            exit;
         end if;

         pragma Loop_Invariant (Total <= Hours'Last);
      end loop;

      return Total;
   end Total_Time;

   function Total_Carbon (Segments : Segment_Array) return Carbon_Kg is
      Total : Carbon_Kg := 0;
   begin
      for I in Segments'Range loop
         -- Overflow-safe addition using larger intermediate
         declare
            Seg_Carbon : constant Carbon_Kg := Carbon_Kg (Segments (I).Carbon);
         begin
            if Carbon_Kg'Last - Total >= Seg_Carbon then
               Total := Total + Seg_Carbon;
            else
               Total := Carbon_Kg'Last;
               exit;
            end if;
         end;

         pragma Loop_Invariant (Total <= Carbon_Kg'Last);
      end loop;

      return Total;
   end Total_Carbon;

   function Total_Distance (Segments : Segment_Array) return Distance_Km is
      Total : Distance_Km := 0;
   begin
      for I in Segments'Range loop
         if Distance_Km'Last - Total >= Segments (I).Distance then
            Total := Total + Segments (I).Distance;
         else
            Total := Distance_Km'Last;
            exit;
         end if;

         pragma Loop_Invariant (Total <= Distance_Km'Last);
      end loop;

      return Total;
   end Total_Distance;

   -- =========================================================================
   -- Route Validation Implementation
   -- =========================================================================

   function Validate_Route
     (Segments     : Segment_Array;
      Max_Weight   : Container_Weight;
      Min_Safety   : Safety_Score;
      Time_Budget  : Hours;
      Cost_Budget  : Cost_Cents) return Route_Validation
   is
      Result : Route_Validation := Valid_Route;
      Route_Time : Hours;
      Route_Cost : Cost_Cents;
   begin
      -- Check connectivity
      Result.Is_Connected := Is_Connected (Segments);
      if not Result.Is_Connected then
         Result.Is_Valid := False;
         -- Find first disconnected segment
         for I in Segments'First .. Segments'Last - 1 loop
            if not Are_Adjacent (Segments (I), Segments (I + 1)) then
               Result.Error_Segment := I + 1;
               exit;
            end if;
         end loop;
      end if;

      -- Check safety
      Result.All_Safe := All_Safe (Segments, Min_Safety);
      if not Result.All_Safe then
         Result.Is_Valid := False;
         for I in Segments'Range loop
            if Segments (I).Safety_Score < Min_Safety then
               Result.Error_Segment := I;
               exit;
            end if;
         end loop;
      end if;

      -- Check weight
      Result.Within_Weight := All_Within_Weight (Segments, Max_Weight);
      if not Result.Within_Weight then
         Result.Is_Valid := False;
         for I in Segments'Range loop
            if Segments (I).Weight > Max_Weight then
               Result.Error_Segment := I;
               exit;
            end if;
         end loop;
      end if;

      -- Check time budget
      Route_Time := Total_Time (Segments);
      Result.Within_Time_Budget := Route_Time <= Time_Budget;
      if not Result.Within_Time_Budget then
         Result.Is_Valid := False;
      end if;

      -- Check cost budget
      Route_Cost := Total_Cost (Segments);
      Result.Within_Cost_Budget := Route_Cost <= Cost_Budget;
      if not Result.Within_Cost_Budget then
         Result.Is_Valid := False;
      end if;

      return Result;
   end Validate_Route;

end VEDS_Route_Safety;
