-- VEDS Core Types
-- SPARK-verified type definitions with range constraints

pragma SPARK_Mode (On);

package VEDS_Types is

   -- =========================================================================
   -- Currency and Cost Types (overflow-protected)
   -- =========================================================================

   -- Costs in cents to avoid floating point
   type Cost_Cents is range 0 .. 10_000_000_000_00;  -- Max $100 billion
   subtype Reasonable_Cost is Cost_Cents range 0 .. 1_000_000_000_00;  -- $10B

   -- Currency conversion rates (fixed point for precision)
   type Exchange_Rate is delta 0.0001 range 0.0 .. 1000.0;

   -- =========================================================================
   -- Time Types
   -- =========================================================================

   type Hours is range 0 .. 8760;  -- Max 1 year in hours
   subtype Transit_Hours is Hours range 0 .. 2160;  -- Max 90 days

   type Minutes is range 0 .. 525600;  -- Max 1 year in minutes

   -- Working time constraints (EU directive: max 48h/week)
   type Weekly_Hours is range 0 .. 168;  -- Hours in a week
   subtype Legal_Weekly_Hours is Weekly_Hours range 0 .. 48;

   -- =========================================================================
   -- Weight and Volume Types
   -- =========================================================================

   type Weight_Kg is range 0 .. 500_000_000;  -- 500k tonnes max
   subtype Container_Weight is Weight_Kg range 0 .. 30_000;  -- 30t per TEU

   type Volume_M3 is range 0 .. 100_000_000;
   subtype Container_Volume is Volume_M3 range 0 .. 76;  -- 40ft container

   type TEU_Count is range 0 .. 25_000;  -- Largest ships ~24,000 TEU

   -- =========================================================================
   -- Geographic Types
   -- =========================================================================

   type Latitude is delta 0.000001 range -90.0 .. 90.0;
   type Longitude is delta 0.000001 range -180.0 .. 180.0;

   type Distance_Km is range 0 .. 50_000;  -- Earth circumference ~40k km
   subtype Route_Distance is Distance_Km range 0 .. 25_000;

   -- =========================================================================
   -- Carbon Types
   -- =========================================================================

   type Carbon_Kg is range 0 .. 1_000_000_000;  -- 1 million tonnes max
   subtype Segment_Carbon is Carbon_Kg range 0 .. 100_000_000;  -- 100k tonnes

   -- Carbon intensity (grams CO2 per tonne-km)
   type Carbon_Intensity is delta 0.01 range 0.0 .. 1000.0;

   -- =========================================================================
   -- Wage Types (ILO compliance)
   -- =========================================================================

   type Wage_Cents_Per_Hour is range 0 .. 100_000;  -- Max $1000/hr
   subtype Reasonable_Wage is Wage_Cents_Per_Hour range 0 .. 50_000;

   -- ILO minimum wage thresholds by region (cents/hour)
   ILO_Minimum_DE : constant Wage_Cents_Per_Hour := 1260;  -- €12.41 ~$13.60
   ILO_Minimum_NL : constant Wage_Cents_Per_Hour := 1355;  -- €13.27
   ILO_Minimum_CN : constant Wage_Cents_Per_Hour := 350;   -- ¥25 ~$3.50
   ILO_Minimum_SG : constant Wage_Cents_Per_Hour := 0;     -- No statutory min

   -- =========================================================================
   -- Safety and Compliance Types
   -- =========================================================================

   type Safety_Score is delta 0.01 range 0.0 .. 1.0;
   subtype Acceptable_Safety is Safety_Score range 0.7 .. 1.0;

   type Compliance_Score is delta 0.01 range 0.0 .. 1.0;

   -- Risk levels
   type Risk_Level is (None, Low, Medium, High, Critical);

   -- =========================================================================
   -- Entity Identifiers
   -- =========================================================================

   subtype Entity_ID is String (1 .. 36);  -- UUID format
   subtype Country_Code is String (1 .. 2);  -- ISO 3166-1 alpha-2
   subtype Port_Code is String (1 .. 5);     -- UN/LOCODE

   -- =========================================================================
   -- Transport Mode
   -- =========================================================================

   type Transport_Mode is (Maritime, Rail, Road, Air);

   -- Carbon factors by mode (g CO2 per tonne-km)
   Carbon_Factor_Maritime : constant Carbon_Intensity := 15.0;
   Carbon_Factor_Rail     : constant Carbon_Intensity := 28.0;
   Carbon_Factor_Road     : constant Carbon_Intensity := 62.0;
   Carbon_Factor_Air      : constant Carbon_Intensity := 500.0;

   -- =========================================================================
   -- Constraint Result
   -- =========================================================================

   type Constraint_Result is record
      Passed      : Boolean;
      Is_Hard     : Boolean;  -- Hard constraints block route
      Severity    : Safety_Score;
      Risk        : Risk_Level;
   end record;

   Constraint_Pass : constant Constraint_Result :=
     (Passed => True, Is_Hard => False, Severity => 0.0, Risk => None);

   Constraint_Fail_Soft : constant Constraint_Result :=
     (Passed => False, Is_Hard => False, Severity => 0.5, Risk => Medium);

   Constraint_Fail_Hard : constant Constraint_Result :=
     (Passed => False, Is_Hard => True, Severity => 1.0, Risk => Critical);

end VEDS_Types;
