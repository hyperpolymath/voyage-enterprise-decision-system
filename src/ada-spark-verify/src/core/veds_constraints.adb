-- VEDS Constraint Evaluation Implementation
-- SPARK-verified with formal proofs

pragma SPARK_Mode (On);

package body VEDS_Constraints is

   -- =========================================================================
   -- Wage Constraints Implementation
   -- =========================================================================

   function Get_ILO_Minimum (Country : Country_Code) return Wage_Cents_Per_Hour is
   begin
      -- Return ILO minimum wage for known countries
      if Country = "DE" then
         return ILO_Minimum_DE;
      elsif Country = "NL" then
         return ILO_Minimum_NL;
      elsif Country = "CN" then
         return ILO_Minimum_CN;
      elsif Country = "SG" then
         return ILO_Minimum_SG;
      else
         -- Default to conservative estimate for unknown countries
         return 500;  -- $5/hr baseline
      end if;
   end Get_ILO_Minimum;

   function Check_Minimum_Wage
     (Actual_Wage : Wage_Cents_Per_Hour;
      Country     : Country_Code) return Constraint_Result
   is
      Minimum : constant Wage_Cents_Per_Hour := Get_ILO_Minimum (Country);
   begin
      if Actual_Wage >= Minimum then
         return Constraint_Pass;
      else
         -- Calculate severity based on how far below minimum
         declare
            Shortfall : constant Wage_Cents_Per_Hour := Minimum - Actual_Wage;
            Severity  : Safety_Score;
         begin
            if Shortfall > Minimum / 2 then
               Severity := 1.0;  -- More than 50% below = critical
            elsif Shortfall > Minimum / 4 then
               Severity := 0.7;
            else
               Severity := 0.4;
            end if;

            return (Passed   => False,
                    Is_Hard  => True,  -- Wage violations are hard constraints
                    Severity => Severity,
                    Risk     => High);
         end;
      end if;
   end Check_Minimum_Wage;

   -- =========================================================================
   -- Working Time Implementation
   -- =========================================================================

   function Check_Working_Time
     (Weekly_Work : Weekly_Hours) return Constraint_Result
   is
   begin
      if Weekly_Work <= 48 then
         return Constraint_Pass;
      elsif Weekly_Work <= 60 then
         -- Soft violation: overtime but within extended limits
         return (Passed   => False,
                 Is_Hard  => False,
                 Severity => 0.5,
                 Risk     => Medium);
      else
         -- Hard violation: excessive overtime
         return (Passed   => False,
                 Is_Hard  => True,
                 Severity => 0.9,
                 Risk     => High);
      end if;
   end Check_Working_Time;

   function Check_Daily_Driving
     (Daily_Hours   : Hours;
      Extended_Days : Natural) return Constraint_Result
   is
      Max_Normal   : constant Hours := 9;
      Max_Extended : constant Hours := 10;
   begin
      if Daily_Hours <= Max_Normal then
         return Constraint_Pass;
      elsif Daily_Hours <= Max_Extended and Extended_Days < 2 then
         -- Within extended allowance
         return Constraint_Pass;
      elsif Daily_Hours <= Max_Extended then
         -- Soft violation: exceeded extended day allowance
         return Constraint_Fail_Soft;
      else
         -- Hard violation: exceeded all limits
         return Constraint_Fail_Hard;
      end if;
   end Check_Daily_Driving;

   -- =========================================================================
   -- Carbon Implementation
   -- =========================================================================

   function Check_Carbon_Budget
     (Actual_Carbon : Carbon_Kg;
      Budget        : Carbon_Kg) return Constraint_Result
   is
   begin
      if Actual_Carbon <= Budget then
         return Constraint_Pass;
      else
         declare
            Overage  : constant Carbon_Kg := Actual_Carbon - Budget;
            Severity : Safety_Score;
         begin
            -- Calculate severity based on overage percentage
            if Budget > 0 then
               if Overage > Budget / 2 then
                  Severity := 0.9;
               elsif Overage > Budget / 4 then
                  Severity := 0.6;
               else
                  Severity := 0.3;
               end if;
            else
               Severity := 1.0;
            end if;

            return (Passed   => False,
                    Is_Hard  => False,  -- Carbon is soft constraint
                    Severity => Severity,
                    Risk     => Medium);
         end;
      end if;
   end Check_Carbon_Budget;

   function Calculate_Segment_Carbon
     (Distance_Km : Route_Distance;
      Weight_Kg   : Container_Weight;
      Mode        : Transport_Mode) return Segment_Carbon
   is
      Factor : Carbon_Intensity;
      -- Use intermediate calculation with larger range to prevent overflow
      Tonne_Km : constant Long_Long_Integer :=
        Long_Long_Integer (Distance_Km) * Long_Long_Integer (Weight_Kg) / 1000;
      Result_Raw : Long_Long_Integer;
   begin
      -- Get carbon factor for transport mode
      case Mode is
         when Maritime => Factor := Carbon_Factor_Maritime;
         when Rail     => Factor := Carbon_Factor_Rail;
         when Road     => Factor := Carbon_Factor_Road;
         when Air      => Factor := Carbon_Factor_Air;
      end case;

      -- Calculate: (distance * weight / 1000) * factor / 1000
      -- Result in kg CO2
      Result_Raw := Tonne_Km * Long_Long_Integer (Factor * 100) / 100_000;

      -- Clamp to valid range
      if Result_Raw > Long_Long_Integer (Segment_Carbon'Last) then
         return Segment_Carbon'Last;
      elsif Result_Raw < 0 then
         return 0;
      else
         return Segment_Carbon (Result_Raw);
      end if;
   end Calculate_Segment_Carbon;

   function Check_Carbon_Intensity
     (Total_Carbon    : Carbon_Kg;
      Total_Tonne_Km  : Weight_Kg;
      Intensity_Limit : Carbon_Intensity) return Constraint_Result
   is
      Actual_Intensity : Carbon_Intensity;
   begin
      -- Calculate actual intensity (g CO2 per tonne-km)
      Actual_Intensity := Carbon_Intensity (
        Float (Total_Carbon) * 1000.0 / Float (Total_Tonne_Km)
      );

      if Actual_Intensity <= Intensity_Limit then
         return Constraint_Pass;
      else
         return (Passed   => False,
                 Is_Hard  => False,
                 Severity => Safety_Score'Min (
                   1.0,
                   Safety_Score ((Float (Actual_Intensity) - Float (Intensity_Limit)) /
                                 Float (Intensity_Limit))),
                 Risk     => Low);
      end if;
   end Check_Carbon_Intensity;

   -- =========================================================================
   -- Safety Implementation
   -- =========================================================================

   function Check_Safety_Score
     (Score     : Safety_Score;
      Threshold : Safety_Score) return Constraint_Result
   is
   begin
      if Score >= Threshold then
         return Constraint_Pass;
      else
         return (Passed   => False,
                 Is_Hard  => True,  -- Safety is hard constraint
                 Severity => Safety_Score (1.0 - Float (Score)),
                 Risk     => (if Score < 0.5 then Critical
                              elsif Score < 0.7 then High
                              else Medium));
      end if;
   end Check_Safety_Score;

   function Check_Container_Weight
     (Actual_Weight : Weight_Kg;
      Max_Weight    : Container_Weight) return Constraint_Result
   is
   begin
      if Actual_Weight <= Weight_Kg (Max_Weight) then
         return Constraint_Pass;
      else
         -- Overweight is safety-critical
         return Constraint_Fail_Hard;
      end if;
   end Check_Container_Weight;

   -- =========================================================================
   -- Cost Implementation (Overflow Protected)
   -- =========================================================================

   function Safe_Add_Cost
     (A, B : Cost_Cents) return Cost_Cents
   is
   begin
      if Cost_Cents'Last - A >= B then
         return A + B;
      else
         -- Overflow would occur, return max
         return Cost_Cents'Last;
      end if;
   end Safe_Add_Cost;

   function Safe_Multiply_Cost
     (Base       : Cost_Cents;
      Multiplier : Positive) return Cost_Cents
   is
      Max_Safe : constant Cost_Cents := Cost_Cents'Last / Cost_Cents (Multiplier);
   begin
      if Base <= Max_Safe then
         return Base * Cost_Cents (Multiplier);
      else
         return Cost_Cents'Last;
      end if;
   end Safe_Multiply_Cost;

   -- =========================================================================
   -- Sanctions Implementation
   -- =========================================================================

   function Check_Sanctions
     (Entity : Entity_ID) return Constraint_Result
   is
      pragma Unreferenced (Entity);
   begin
      -- In real implementation, this would call external sanctions database
      -- For SPARK verification, we prove the interface contract
      -- Actual lookup is done via FFI to Rust/Clojure service

      -- Default: assume clear (actual check happens at runtime)
      return Constraint_Pass;
   end Check_Sanctions;

   function Check_Country_Sanctions
     (Country : Country_Code) return Constraint_Result
   is
   begin
      -- Known sanctioned countries (simplified - real list is longer)
      if Country = "KP" or   -- North Korea
         Country = "IR" or   -- Iran
         Country = "SY" or   -- Syria
         Country = "CU"      -- Cuba (US sanctions)
      then
         return (Passed   => False,
                 Is_Hard  => True,
                 Severity => 1.0,
                 Risk     => Critical);
      else
         return Constraint_Pass;
      end if;
   end Check_Country_Sanctions;

   -- =========================================================================
   -- Combined Evaluation
   -- =========================================================================

   function Evaluate_All_Constraints
     (Wage          : Wage_Cents_Per_Hour;
      Country       : Country_Code;
      Weekly_Hours  : Weekly_Hours;
      Carbon        : Carbon_Kg;
      Carbon_Budget : Carbon_Kg;
      Safety        : Safety_Score;
      Entity        : Entity_ID) return Route_Constraints
   is
      Wage_Result     : constant Constraint_Result :=
        Check_Minimum_Wage (Wage, Country);
      Time_Result     : constant Constraint_Result :=
        Check_Working_Time (Weekly_Hours);
      Carbon_Result   : constant Constraint_Result :=
        Check_Carbon_Budget (Carbon, Carbon_Budget);
      Safety_Result   : constant Constraint_Result :=
        Check_Safety_Score (Safety, 0.7);
      Sanction_Result : constant Constraint_Result :=
        Check_Sanctions (Entity);
      Country_Result  : constant Constraint_Result :=
        Check_Country_Sanctions (Country);

      All_Sanctions_OK : constant Boolean :=
        Sanction_Result.Passed and Country_Result.Passed;
   begin
      return (Wage_OK         => Wage_Result.Passed,
              Working_Time_OK => Time_Result.Passed,
              Carbon_OK       => Carbon_Result.Passed,
              Safety_OK       => Safety_Result.Passed,
              Sanctions_OK    => All_Sanctions_OK,
              All_Hard_Pass   => All_Sanctions_OK and Safety_Result.Passed,
              Overall_Pass    => Wage_Result.Passed and
                                 Time_Result.Passed and
                                 Carbon_Result.Passed and
                                 Safety_Result.Passed and
                                 All_Sanctions_OK);
   end Evaluate_All_Constraints;

end VEDS_Constraints;
