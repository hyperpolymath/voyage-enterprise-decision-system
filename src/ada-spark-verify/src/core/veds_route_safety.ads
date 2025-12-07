-- VEDS Route Safety Proofs
-- SPARK-verified route invariants and safety properties

pragma SPARK_Mode (On);

with VEDS_Types; use VEDS_Types;

package VEDS_Route_Safety is

   -- =========================================================================
   -- Route Segment Type
   -- =========================================================================

   type Segment is record
      Origin_Lat    : Latitude;
      Origin_Lon    : Longitude;
      Dest_Lat      : Latitude;
      Dest_Lon      : Longitude;
      Mode          : Transport_Mode;
      Distance      : Route_Distance;
      Weight        : Container_Weight;
      Cost          : Reasonable_Cost;
      Time_Hours    : Transit_Hours;
      Carbon        : Segment_Carbon;
      Wage          : Reasonable_Wage;
      Safety_Score  : Safety_Score;
   end record;

   type Segment_Array is array (Positive range <>) of Segment;

   -- =========================================================================
   -- Route Invariants
   -- =========================================================================

   -- Verify route segments are geographically connected
   function Is_Connected (Segments : Segment_Array) return Boolean
   with
     Global => null,
     Pre    => Segments'Length >= 1,
     Post   => (if Segments'Length = 1 then Is_Connected'Result = True);

   -- Verify all segments have valid safety scores
   function All_Safe (Segments : Segment_Array;
                      Min_Safety : Safety_Score) return Boolean
   with
     Global => null,
     Post   => (for all I in Segments'Range =>
                  (if All_Safe'Result then
                     Segments (I).Safety_Score >= Min_Safety));

   -- Verify no segment exceeds weight limit
   function All_Within_Weight (Segments   : Segment_Array;
                               Max_Weight : Container_Weight) return Boolean
   with
     Global => null,
     Post   => (for all I in Segments'Range =>
                  (if All_Within_Weight'Result then
                     Segments (I).Weight <= Max_Weight));

   -- =========================================================================
   -- Route Totals (Overflow Protected)
   -- =========================================================================

   -- Calculate total route cost with overflow protection
   function Total_Cost (Segments : Segment_Array) return Cost_Cents
   with
     Global => null,
     Pre    => Segments'Length <= 100,  -- Reasonable route length
     Post   => Total_Cost'Result <= Cost_Cents'Last;

   -- Calculate total route time
   function Total_Time (Segments : Segment_Array) return Hours
   with
     Global => null,
     Pre    => Segments'Length <= 100,
     Post   => (if Segments'Length = 0 then Total_Time'Result = 0);

   -- Calculate total route carbon
   function Total_Carbon (Segments : Segment_Array) return Carbon_Kg
   with
     Global => null,
     Pre    => Segments'Length <= 100,
     Post   => Total_Carbon'Result <= Carbon_Kg'Last;

   -- Calculate total route distance
   function Total_Distance (Segments : Segment_Array) return Distance_Km
   with
     Global => null,
     Pre    => Segments'Length <= 100;

   -- =========================================================================
   -- Route Validation
   -- =========================================================================

   type Route_Validation is record
      Is_Valid           : Boolean;
      Is_Connected       : Boolean;
      All_Safe           : Boolean;
      Within_Weight      : Boolean;
      Within_Time_Budget : Boolean;
      Within_Cost_Budget : Boolean;
      Error_Segment      : Natural;  -- 0 if no error, else segment index
   end record;

   Valid_Route : constant Route_Validation :=
     (Is_Valid           => True,
      Is_Connected       => True,
      All_Safe           => True,
      Within_Weight      => True,
      Within_Time_Budget => True,
      Within_Cost_Budget => True,
      Error_Segment      => 0);

   -- Full route validation
   function Validate_Route
     (Segments     : Segment_Array;
      Max_Weight   : Container_Weight;
      Min_Safety   : Safety_Score;
      Time_Budget  : Hours;
      Cost_Budget  : Cost_Cents) return Route_Validation
   with
     Global => null,
     Pre    => Segments'Length >= 1 and Segments'Length <= 100,
     Post   => (if Validate_Route'Result.Is_Valid then
                  Validate_Route'Result.Is_Connected and
                  Validate_Route'Result.All_Safe and
                  Validate_Route'Result.Within_Weight);

   -- =========================================================================
   -- Geographic Calculations
   -- =========================================================================

   -- Haversine distance between two points (in km)
   function Haversine_Distance
     (Lat1, Lon1, Lat2, Lon2 : Long_Float) return Route_Distance
   with
     Global => null,
     Pre    => Lat1 >= -90.0 and Lat1 <= 90.0 and
               Lat2 >= -90.0 and Lat2 <= 90.0 and
               Lon1 >= -180.0 and Lon1 <= 180.0 and
               Lon2 >= -180.0 and Lon2 <= 180.0;

   -- Check if two segments are geographically adjacent (within tolerance)
   function Are_Adjacent
     (Seg1, Seg2  : Segment;
      Tolerance_Km : Route_Distance := 50) return Boolean
   with
     Global => null;

end VEDS_Route_Safety;
