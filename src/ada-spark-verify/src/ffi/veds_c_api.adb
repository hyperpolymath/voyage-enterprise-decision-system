-- VEDS C API Implementation
-- Bridges C ABI to SPARK-verified Ada packages

pragma SPARK_Mode (Off);

with VEDS_Types;
with VEDS_Constraints;
with VEDS_Route_Safety;

package body VEDS_C_API is

   Version_String : aliased constant String := "VEDS-SPARK-1.0.0" & ASCII.NUL;

   -- =========================================================================
   -- Helper Functions
   -- =========================================================================

   function To_Country_Code (S : chars_ptr) return VEDS_Types.Country_Code is
      Str : constant String := Value (S);
   begin
      if Str'Length >= 2 then
         return Str (Str'First .. Str'First + 1);
      else
         return "XX";  -- Unknown
      end if;
   end To_Country_Code;

   function To_Entity_ID (S : chars_ptr) return VEDS_Types.Entity_ID is
      Str : constant String := Value (S);
      Result : VEDS_Types.Entity_ID := (others => ' ');
   begin
      for I in 1 .. Integer'Min (36, Str'Length) loop
         Result (I) := Str (Str'First + I - 1);
      end loop;
      return Result;
   end To_Entity_ID;

   function From_Constraint_Result
     (R : VEDS_Types.Constraint_Result) return C_Constraint_Result
   is
      Risk_Val : C.int;
   begin
      case R.Risk is
         when VEDS_Types.None     => Risk_Val := 0;
         when VEDS_Types.Low      => Risk_Val := 1;
         when VEDS_Types.Medium   => Risk_Val := 2;
         when VEDS_Types.High     => Risk_Val := 3;
         when VEDS_Types.Critical => Risk_Val := 4;
      end case;

      return (Passed   => (if R.Passed then 1 else 0),
              Is_Hard  => (if R.Is_Hard then 1 else 0),
              Severity => C.double (R.Severity),
              Risk     => Risk_Val);
   end From_Constraint_Result;

   function To_Transport_Mode (Mode : C.int) return VEDS_Types.Transport_Mode is
   begin
      case Mode is
         when 0 => return VEDS_Types.Maritime;
         when 1 => return VEDS_Types.Rail;
         when 2 => return VEDS_Types.Road;
         when 3 => return VEDS_Types.Air;
         when others => return VEDS_Types.Maritime;  -- Default
      end case;
   end To_Transport_Mode;

   -- =========================================================================
   -- Constraint Check Implementations
   -- =========================================================================

   function Veds_Check_Minimum_Wage
     (Actual_Wage_Cents : C.int;
      Country_Code      : chars_ptr) return C_Constraint_Result
   is
      Ada_Result : VEDS_Types.Constraint_Result;
   begin
      Ada_Result := VEDS_Constraints.Check_Minimum_Wage
        (Actual_Wage => VEDS_Types.Wage_Cents_Per_Hour (Actual_Wage_Cents),
         Country     => To_Country_Code (Country_Code));
      return From_Constraint_Result (Ada_Result);
   end Veds_Check_Minimum_Wage;

   function Veds_Check_Working_Time
     (Weekly_Hours : C.int) return C_Constraint_Result
   is
      Ada_Result : VEDS_Types.Constraint_Result;
   begin
      Ada_Result := VEDS_Constraints.Check_Working_Time
        (Weekly_Work => VEDS_Types.Weekly_Hours (Weekly_Hours));
      return From_Constraint_Result (Ada_Result);
   end Veds_Check_Working_Time;

   function Veds_Check_Carbon_Budget
     (Actual_Carbon_Kg : C.long;
      Budget_Kg        : C.long) return C_Constraint_Result
   is
      Ada_Result : VEDS_Types.Constraint_Result;
   begin
      Ada_Result := VEDS_Constraints.Check_Carbon_Budget
        (Actual_Carbon => VEDS_Types.Carbon_Kg (Actual_Carbon_Kg),
         Budget        => VEDS_Types.Carbon_Kg (Budget_Kg));
      return From_Constraint_Result (Ada_Result);
   end Veds_Check_Carbon_Budget;

   function Veds_Check_Safety_Score
     (Score     : C.double;
      Threshold : C.double) return C_Constraint_Result
   is
      Ada_Result : VEDS_Types.Constraint_Result;
   begin
      Ada_Result := VEDS_Constraints.Check_Safety_Score
        (Score     => VEDS_Types.Safety_Score (Score),
         Threshold => VEDS_Types.Safety_Score (Threshold));
      return From_Constraint_Result (Ada_Result);
   end Veds_Check_Safety_Score;

   function Veds_Check_Country_Sanctions
     (Country_Code : chars_ptr) return C_Constraint_Result
   is
      Ada_Result : VEDS_Types.Constraint_Result;
   begin
      Ada_Result := VEDS_Constraints.Check_Country_Sanctions
        (Country => To_Country_Code (Country_Code));
      return From_Constraint_Result (Ada_Result);
   end Veds_Check_Country_Sanctions;

   -- =========================================================================
   -- Route Validation Implementations
   -- =========================================================================

   function Veds_Validate_Route
     (Segments      : access C_Segment;
      Segment_Count : C.int;
      Max_Weight_Kg : C.int;
      Min_Safety    : C.double;
      Time_Budget_H : C.int;
      Cost_Budget   : C.long) return C_Route_Validation
   is
      pragma Unreferenced (Segments, Segment_Count);
      -- Full implementation would convert C_Segment array to Ada array
      -- and call VEDS_Route_Safety.Validate_Route
   begin
      -- Placeholder - real implementation would do conversion
      return (Is_Valid           => 1,
              Is_Connected       => 1,
              All_Safe           => (if Min_Safety <= 1.0 then 1 else 0),
              Within_Weight      => (if Max_Weight_Kg > 0 then 1 else 0),
              Within_Time_Budget => (if Time_Budget_H > 0 then 1 else 0),
              Within_Cost_Budget => (if Cost_Budget > 0 then 1 else 0),
              Error_Segment      => 0);
   end Veds_Validate_Route;

   function Veds_Calculate_Segment_Carbon
     (Distance_Km : C.int;
      Weight_Kg   : C.int;
      Mode        : C.int) return C.long
   is
      Result : VEDS_Types.Segment_Carbon;
   begin
      Result := VEDS_Constraints.Calculate_Segment_Carbon
        (Distance_Km => VEDS_Types.Route_Distance (Distance_Km),
         Weight_Kg   => VEDS_Types.Container_Weight (Weight_Kg),
         Mode        => To_Transport_Mode (Mode));
      return C.long (Result);
   end Veds_Calculate_Segment_Carbon;

   function Veds_Haversine_Distance
     (Lat1 : C.double;
      Lon1 : C.double;
      Lat2 : C.double;
      Lon2 : C.double) return C.int
   is
      Result : VEDS_Types.Route_Distance;
   begin
      Result := VEDS_Route_Safety.Haversine_Distance
        (Long_Float (Lat1), Long_Float (Lon1),
         Long_Float (Lat2), Long_Float (Lon2));
      return C.int (Result);
   end Veds_Haversine_Distance;

   -- =========================================================================
   -- Combined Constraint Evaluation
   -- =========================================================================

   function Veds_Evaluate_All_Constraints
     (Wage_Cents       : C.int;
      Country_Code     : chars_ptr;
      Weekly_Hours     : C.int;
      Carbon_Kg        : C.long;
      Carbon_Budget_Kg : C.long;
      Safety_Score     : C.double;
      Entity_ID        : chars_ptr) return C_All_Constraints
   is
      Ada_Result : VEDS_Constraints.Route_Constraints;
   begin
      Ada_Result := VEDS_Constraints.Evaluate_All_Constraints
        (Wage          => VEDS_Types.Wage_Cents_Per_Hour (Wage_Cents),
         Country       => To_Country_Code (Country_Code),
         Weekly_Hours  => VEDS_Types.Weekly_Hours (Weekly_Hours),
         Carbon        => VEDS_Types.Carbon_Kg (Carbon_Kg),
         Carbon_Budget => VEDS_Types.Carbon_Kg (Carbon_Budget_Kg),
         Safety        => VEDS_Types.Safety_Score (Safety_Score),
         Entity        => To_Entity_ID (Entity_ID));

      return (Wage_OK         => (if Ada_Result.Wage_OK then 1 else 0),
              Working_Time_OK => (if Ada_Result.Working_Time_OK then 1 else 0),
              Carbon_OK       => (if Ada_Result.Carbon_OK then 1 else 0),
              Safety_OK       => (if Ada_Result.Safety_OK then 1 else 0),
              Sanctions_OK    => (if Ada_Result.Sanctions_OK then 1 else 0),
              All_Hard_Pass   => (if Ada_Result.All_Hard_Pass then 1 else 0),
              Overall_Pass    => (if Ada_Result.Overall_Pass then 1 else 0));
   end Veds_Evaluate_All_Constraints;

   -- =========================================================================
   -- Version and Health
   -- =========================================================================

   function Veds_Version return chars_ptr is
   begin
      return New_String (Version_String);
   end Veds_Version;

   function Veds_Health_Check return C.int is
   begin
      -- Run basic sanity checks
      declare
         Test_Result : VEDS_Types.Constraint_Result;
      begin
         Test_Result := VEDS_Constraints.Check_Minimum_Wage (1500, "DE");
         if not Test_Result.Passed then
            return 0;  -- Sanity check failed
         end if;
      end;
      return 1;  -- All OK
   end Veds_Health_Check;

end VEDS_C_API;
