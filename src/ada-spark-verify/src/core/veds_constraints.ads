-- VEDS Constraint Evaluation
-- SPARK-verified constraint checking with formal proofs

pragma SPARK_Mode (On);

with VEDS_Types; use VEDS_Types;

package VEDS_Constraints is

   -- =========================================================================
   -- Wage Constraints (ILO Compliance)
   -- =========================================================================

   -- Check if wage meets ILO minimum for country
   function Check_Minimum_Wage
     (Actual_Wage : Wage_Cents_Per_Hour;
      Country     : Country_Code) return Constraint_Result
   with
     Global => null,
     Post   => (if Actual_Wage >= Get_ILO_Minimum (Country) then
                  Check_Minimum_Wage'Result.Passed = True);

   -- Get ILO minimum wage for country
   function Get_ILO_Minimum (Country : Country_Code) return Wage_Cents_Per_Hour
   with
     Global => null,
     Post   => Get_ILO_Minimum'Result <= 50_000;  -- Reasonable upper bound

   -- =========================================================================
   -- Working Time Constraints (EU Directive)
   -- =========================================================================

   -- Check EU Working Time Directive compliance (max 48h/week average)
   function Check_Working_Time
     (Weekly_Work : Weekly_Hours) return Constraint_Result
   with
     Global => null,
     Post   => (if Weekly_Work <= 48 then
                  Check_Working_Time'Result.Passed = True);

   -- Check maximum daily driving hours (EU: 9h, extended to 10h twice/week)
   function Check_Daily_Driving
     (Daily_Hours   : Hours;
      Extended_Days : Natural) return Constraint_Result
   with
     Global => null,
     Pre    => Extended_Days <= 2,
     Post   => (if Daily_Hours <= 9 then
                  Check_Daily_Driving'Result.Passed = True);

   -- =========================================================================
   -- Carbon Constraints
   -- =========================================================================

   -- Check if route carbon is within budget
   function Check_Carbon_Budget
     (Actual_Carbon : Carbon_Kg;
      Budget        : Carbon_Kg) return Constraint_Result
   with
     Global => null,
     Post   => (if Actual_Carbon <= Budget then
                  Check_Carbon_Budget'Result.Passed = True);

   -- Calculate carbon for segment (with overflow protection)
   function Calculate_Segment_Carbon
     (Distance_Km : Route_Distance;
      Weight_Kg   : Container_Weight;
      Mode        : Transport_Mode) return Segment_Carbon
   with
     Global => null,
     Post   => Calculate_Segment_Carbon'Result <=
               Segment_Carbon'Last;  -- No overflow

   -- Check carbon intensity limit
   function Check_Carbon_Intensity
     (Total_Carbon    : Carbon_Kg;
      Total_Tonne_Km  : Weight_Kg;
      Intensity_Limit : Carbon_Intensity) return Constraint_Result
   with
     Global => null,
     Pre    => Total_Tonne_Km > 0;

   -- =========================================================================
   -- Safety Constraints
   -- =========================================================================

   -- Check route safety score meets threshold
   function Check_Safety_Score
     (Score     : Safety_Score;
      Threshold : Safety_Score) return Constraint_Result
   with
     Global => null,
     Post   => (if Score >= Threshold then
                  Check_Safety_Score'Result.Passed = True);

   -- Check cargo weight within container limits
   function Check_Container_Weight
     (Actual_Weight : Weight_Kg;
      Max_Weight    : Container_Weight) return Constraint_Result
   with
     Global => null,
     Post   => (if Actual_Weight <= Weight_Kg (Max_Weight) then
                  Check_Container_Weight'Result.Passed = True);

   -- =========================================================================
   -- Cost Constraints (Overflow Protected)
   -- =========================================================================

   -- Add two costs with overflow protection
   function Safe_Add_Cost
     (A, B : Cost_Cents) return Cost_Cents
   with
     Global => null,
     Post   => (if Cost_Cents'Last - A >= B then
                  Safe_Add_Cost'Result = A + B
                else
                  Safe_Add_Cost'Result = Cost_Cents'Last);

   -- Multiply cost with overflow protection
   function Safe_Multiply_Cost
     (Base       : Cost_Cents;
      Multiplier : Positive) return Cost_Cents
   with
     Global => null,
     Pre    => Multiplier <= 1000,
     Post   => Safe_Multiply_Cost'Result <= Cost_Cents'Last;

   -- =========================================================================
   -- Sanction Constraints
   -- =========================================================================

   -- Sanction check result
   type Sanction_Status is (Clear, OFAC_Listed, EU_Listed, UN_Listed, Multiple);

   -- Check if entity is on any sanctions list
   -- Note: Actual lookup would interface with external database
   function Check_Sanctions
     (Entity : Entity_ID) return Constraint_Result
   with
     Global => null;

   -- Check if country is sanctioned for transport
   function Check_Country_Sanctions
     (Country : Country_Code) return Constraint_Result
   with
     Global => null;

   -- =========================================================================
   -- Combined Route Constraint Check
   -- =========================================================================

   type Route_Constraints is record
      Wage_OK       : Boolean;
      Working_Time_OK : Boolean;
      Carbon_OK     : Boolean;
      Safety_OK     : Boolean;
      Sanctions_OK  : Boolean;
      All_Hard_Pass : Boolean;  -- All hard constraints passed
      Overall_Pass  : Boolean;  -- All constraints passed
   end record;

   function Evaluate_All_Constraints
     (Wage          : Wage_Cents_Per_Hour;
      Country       : Country_Code;
      Weekly_Hours  : Weekly_Hours;
      Carbon        : Carbon_Kg;
      Carbon_Budget : Carbon_Kg;
      Safety        : Safety_Score;
      Entity        : Entity_ID) return Route_Constraints
   with
     Global => null,
     Post   => (Evaluate_All_Constraints'Result.All_Hard_Pass =
                  (Evaluate_All_Constraints'Result.Sanctions_OK and
                   Evaluate_All_Constraints'Result.Safety_OK));

end VEDS_Constraints;
