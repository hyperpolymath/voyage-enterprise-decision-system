-- VEDS C API for FFI
-- Exposes SPARK-verified functions to Rust via C ABI

pragma SPARK_Mode (Off);  -- FFI layer is not SPARK

with Interfaces.C; use Interfaces.C;
with Interfaces.C.Strings; use Interfaces.C.Strings;

package VEDS_C_API is

   -- =========================================================================
   -- Result Types for C
   -- =========================================================================

   type C_Constraint_Result is record
      Passed   : C.int;      -- 1 = true, 0 = false
      Is_Hard  : C.int;
      Severity : C.double;   -- 0.0 to 1.0
      Risk     : C.int;      -- 0=None, 1=Low, 2=Med, 3=High, 4=Critical
   end record
   with Convention => C;

   type C_Route_Validation is record
      Is_Valid           : C.int;
      Is_Connected       : C.int;
      All_Safe           : C.int;
      Within_Weight      : C.int;
      Within_Time_Budget : C.int;
      Within_Cost_Budget : C.int;
      Error_Segment      : C.int;
   end record
   with Convention => C;

   type C_Segment is record
      Origin_Lat   : C.double;
      Origin_Lon   : C.double;
      Dest_Lat     : C.double;
      Dest_Lon     : C.double;
      Mode         : C.int;     -- 0=Maritime, 1=Rail, 2=Road, 3=Air
      Distance_Km  : C.int;
      Weight_Kg    : C.int;
      Cost_Cents   : C.long;
      Time_Hours   : C.int;
      Carbon_Kg    : C.long;
      Wage_Cents   : C.int;
      Safety_Score : C.double;
   end record
   with Convention => C;

   type C_Segment_Array is array (Natural range <>) of aliased C_Segment
   with Convention => C;

   -- =========================================================================
   -- Constraint Check Functions
   -- =========================================================================

   function Veds_Check_Minimum_Wage
     (Actual_Wage_Cents : C.int;
      Country_Code      : chars_ptr) return C_Constraint_Result
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_check_minimum_wage";

   function Veds_Check_Working_Time
     (Weekly_Hours : C.int) return C_Constraint_Result
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_check_working_time";

   function Veds_Check_Carbon_Budget
     (Actual_Carbon_Kg : C.long;
      Budget_Kg        : C.long) return C_Constraint_Result
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_check_carbon_budget";

   function Veds_Check_Safety_Score
     (Score     : C.double;
      Threshold : C.double) return C_Constraint_Result
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_check_safety_score";

   function Veds_Check_Country_Sanctions
     (Country_Code : chars_ptr) return C_Constraint_Result
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_check_country_sanctions";

   -- =========================================================================
   -- Route Validation Functions
   -- =========================================================================

   function Veds_Validate_Route
     (Segments      : access C_Segment;
      Segment_Count : C.int;
      Max_Weight_Kg : C.int;
      Min_Safety    : C.double;
      Time_Budget_H : C.int;
      Cost_Budget   : C.long) return C_Route_Validation
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_validate_route";

   function Veds_Calculate_Segment_Carbon
     (Distance_Km : C.int;
      Weight_Kg   : C.int;
      Mode        : C.int) return C.long
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_calculate_segment_carbon";

   function Veds_Haversine_Distance
     (Lat1 : C.double;
      Lon1 : C.double;
      Lat2 : C.double;
      Lon2 : C.double) return C.int
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_haversine_distance";

   -- =========================================================================
   -- Combined Constraint Evaluation
   -- =========================================================================

   type C_All_Constraints is record
      Wage_OK         : C.int;
      Working_Time_OK : C.int;
      Carbon_OK       : C.int;
      Safety_OK       : C.int;
      Sanctions_OK    : C.int;
      All_Hard_Pass   : C.int;
      Overall_Pass    : C.int;
   end record
   with Convention => C;

   function Veds_Evaluate_All_Constraints
     (Wage_Cents       : C.int;
      Country_Code     : chars_ptr;
      Weekly_Hours     : C.int;
      Carbon_Kg        : C.long;
      Carbon_Budget_Kg : C.long;
      Safety_Score     : C.double;
      Entity_ID        : chars_ptr) return C_All_Constraints
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_evaluate_all_constraints";

   -- =========================================================================
   -- Version and Health
   -- =========================================================================

   function Veds_Version return chars_ptr
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_version";

   function Veds_Health_Check return C.int
   with
     Export        => True,
     Convention    => C,
     External_Name => "veds_health_check";

end VEDS_C_API;
